#!/usr/bin/env bash
# WBF deployment of the reviewed 4.1.1 maintenance branch.
set -Eeuo pipefail
MODE=${1:---prepare}; EXPECTED=${2:?Reviewed release commit required}
[[ "$MODE" == --prepare || "$MODE" == --apply ]] || exit 2
REPO=$(cd "$(dirname "$0")" && pwd); cd "$REPO"
[[ $(git branch --show-current) == release/4.1.1 ]]
git diff --quiet && git diff --cached --quiet
git fetch origin release/4.1.1; git merge --ff-only origin/release/4.1.1
unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0
REF=$(git rev-parse HEAD); [[ "$REF" == "$EXPECTED" ]]
BASE=/home/vito/releases/vito; mkdir -p "$BASE"; chmod 700 "$BASE"
exec 9>"$BASE/deploy.lock"; flock -n 9
STAGE="$BASE/$REF"; LIVE=/home/vito/vito
if [[ ! -f "$STAGE/.prepared" ]]; then
  [[ ! -e "$STAGE" ]]; mkdir -m700 "$STAGE"
  git archive "$REF" | tar -x -C "$STAGE"
  cd "$STAGE"; mkdir -p storage/plugins storage/framework/{cache,sessions,views} bootstrap/cache
  composer install --no-dev --no-scripts --no-interaction --prefer-dist
  composer audit --locked --no-dev
  npm ci --no-audit --no-fund
  npm audit --audit-level=high
  npm run types
  npm run build
  test -s public/build/manifest.json
  touch .prepared
fi
[[ "$MODE" == --apply ]] || exit 0
[[ "${APPROVED_MIGRATIONS:-}" == 34 && -n "${SNAPSHOT_ID:-}" ]]
BACKUP=/root/backups/task-206f9bf7-20261014
sudo -n test -s "$BACKUP/vito.complete.json"
sudo -n test -s "$BACKUP/vito.sqlite"
[[ ! -e /etc/supervisor/conf.d/websocket.conf ]]
RESTORE="$BASE/pre-apply-$REF"; mkdir -m700 "$RESTORE"
cd "$LIVE"
recover_before_changes() {
  trap - ERR
  php artisan up || true
  sudo -n supervisorctl start 'worker:*' || true
  echo 'Preparation failed; previous application resumed without code or schema changes'
  exit 1
}
trap recover_before_changes ERR
php artisan down --retry=30 --secret="$(openssl rand -hex 24)" >/dev/null
sudo -n supervisorctl stop 'worker:*'
# Fresh maintenance-window backup preserves all writes since the earlier snapshot.
sudo -n tar -czf "$RESTORE/app.tar.gz" -C "$LIVE" .
sudo -n cp /etc/nginx/sites-available/vito "$RESTORE/nginx"
python3 - "$LIVE/storage/database.sqlite" "$RESTORE/database.sqlite" <<'PY'
import sqlite3,sys
with sqlite3.connect('file:'+sys.argv[1]+'?mode=ro',uri=True) as src,sqlite3.connect(sys.argv[2]) as dst:
 src.backup(dst)
 assert dst.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
PY
rollback() {
  trap - ERR
  sudo -n supervisorctl stop websocket >/dev/null 2>&1 || true
  sudo -n supervisorctl stop 'worker:*' >/dev/null 2>&1 || true
  sudo -n mv "$LIVE" "$BASE/failed-$REF"
  sudo -n mkdir "$LIVE"
  sudo -n tar -xzf "$RESTORE/app.tar.gz" -C "$LIVE"
  sudo -n rm -f "$LIVE/storage/database.sqlite-wal" "$LIVE/storage/database.sqlite-shm" "$LIVE/storage/database.sqlite-journal"
  sudo -n cp "$RESTORE/database.sqlite" "$LIVE/storage/database.sqlite"
  sudo -n chown vito:vito "$LIVE/storage/database.sqlite"
  sudo -n cp "$RESTORE/nginx" /etc/nginx/sites-available/vito
  sudo -n rm -f /etc/supervisor/conf.d/websocket.conf
  sudo -n supervisorctl reread; sudo -n supervisorctl update websocket || true
  sudo -n nginx -t && sudo -n systemctl reload nginx
  cd "$LIVE"; php artisan up
  sudo -n supervisorctl start 'worker:*'
  echo "Deployment failed; previous application and pre-migration database restored"
  exit 1
}
trap rollback ERR
# Runtime files, keys, uploads and branding assets survive; generated build is replaced.
for dir in app bootstrap config database resources routes vendor public/build; do
  rsync -a --delete "$STAGE/$dir/" "$LIVE/$dir/"
done
for file in artisan composer.json composer.lock package.json package-lock.json; do cp "$STAGE/$file" "$LIVE/$file"; done
# Public entry point belongs to the release, other existing public assets are preserved.
cp "$STAGE/public/index.php" "$LIVE/public/index.php"
php artisan optimize:clear
php artisan package:discover
php artisan migrate --force
php artisan optimize
sudo -n python3 - <<'PY'
from pathlib import Path
p=Path('/etc/nginx/sites-available/vito');s=p.read_text()
assert 'include /etc/nginx/snippets/block-exposed.conf;' in s
assert 'location /ws/' not in s
needle='    location /build/ {'
assert s.count(needle)==1
block='''    location /ws/ {
        proxy_pass http://127.0.0.1:8085;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
    }

'''
p.write_text(s.replace(needle,block+needle))
Path('/etc/supervisor/conf.d/websocket.conf').write_text('''[program:websocket]
command=/usr/bin/php /home/vito/vito/artisan ws:serve --host=127.0.0.1 --port=8085
directory=/home/vito/vito
user=vito
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/home/vito/.logs/workers/websocket.log
''')
PY
sudo -n nginx -t
sudo -n systemctl reload nginx
sudo -n supervisorctl reread
sudo -n supervisorctl update websocket
# Check the real PHP/login response while public requests and jobs remain paused.
python3 - <<'PYHEALTH'
import base64,hashlib,hmac,json,time,subprocess
from pathlib import Path
d=json.loads(Path('storage/framework/down').read_text());expires=int(time.time())+60
cookie=base64.b64encode(json.dumps({'expires_at':expires,'mac':hmac.new(d['secret'].encode(),str(expires).encode(),hashlib.sha256).hexdigest()}).encode()).decode()
args=['curl','--fail','--silent','--show-error','--resolve','sys.wbf.tools:443:127.0.0.1','--config','-','https://sys.wbf.tools/login','-o','/dev/null']
subprocess.run(args,input='cookie = "laravel_maintenance='+cookie+'"\n',text=True,check=True)
PYHEALTH
sudo -n supervisorctl status websocket | grep RUNNING
# Once jobs or requests can write, never automatically restore an older database.
trap - ERR
sudo -n supervisorctl start 'worker:*'
php artisan up
echo "Deployed Vito 4.1.1 $REF; rollback $RESTORE; snapshot $SNAPSHOT_ID"
