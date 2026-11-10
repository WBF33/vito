# WBF Vito 4.1.1 upgrade

Upgrade from 3.20.3 to stable 4.1.1, retaining the WBF logo and existing login/footer customization. Composer and npm locks are patched within upstream constraints; both audits report zero vulnerabilities. The 34 upstream migrations passed against a private consistent copy of production SQLite. The owner explicitly approved production migrations on 2026-10-14. Relevant auth, application, API key and migration tests: 100 passed, 287 assertions.

Use a reviewed commit on release/4.1.1. deploy.sh --prepare builds outside the webroot. --apply also requires APPROVED_MIGRATIONS=34 and SNAPSHOT_ID. It puts the panel in maintenance mode, stops only its worker, takes a fresh full application and SQLite backup, preserves live .env/storage/custom public assets, applies official migrations, adds a loopback-only WebSocket worker and a narrowly scoped /ws/ nginx proxy. nginx -t must pass before reload. The error trap restores application, DB and nginx; verify the login and worker after rollback. Existing exposure-blocking includes remain untouched.

Do not execute upstream destructive reset/clean upgrade scripts. No OAuth or Hetzner Pro application code/config is changed. External exposure and authenticated live verification are recorded in the workspace task.
