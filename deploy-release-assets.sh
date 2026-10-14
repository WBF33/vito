#!/usr/bin/env bash
# Complete the support assets of the already deployed 4.1.1 release; no DB changes.
set -Eeuo pipefail
[[ ${1:-} == --apply ]]; EXPECTED=${2:?Reviewed release commit required}
cd "$(dirname "$0")"
[[ $(git branch --show-current) == release/4.1.1 ]]
git diff --quiet && git diff --cached --quiet
git fetch origin release/4.1.1; git merge --ff-only origin/release/4.1.1
unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0
[[ $(git rev-parse HEAD) == "$EXPECTED" && -n ${SNAPSHOT_ID:-} ]]
BASE=/home/vito/releases/vito/support-assets-$EXPECTED
mkdir -m700 "$BASE"
git archive "$EXPECTED" scripts public/api-docs public/email public/vendor | tar -x -C "$BASE"
LIVE=/home/vito/vito
sudo -n tar -czf "$BASE/previous.tar.gz" -C "$LIVE" scripts public/api-docs public/email public/vendor
for dir in scripts public/api-docs public/email public/vendor; do
 sudo -n rsync -a --delete --chown=vito:vito "$BASE/$dir/" "$LIVE/$dir/"
done
echo "Release support assets synchronized; private rollback $BASE/previous.tar.gz"
