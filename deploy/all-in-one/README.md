# All-in-one deployment

The compose files in this folder are documented on the documentation website:

* [All-in-one deployment](../../docs-website/docs/deployment/all-in-one.md) —
  local testing, HTTPS with certbot, and what to do afterwards
* [Deployment overview](../../docs-website/docs/deployment/overview.md) — how
  this variant compares to the others

Short version, from the repository root:

```bash
cp deploy/all-in-one/.env.example deploy/all-in-one/.env
./deploy/ctl aio deploy
```

Set `RESOLVE_IP` and `HTTP_PORT` in `.env` before deploying. The admin panel is
then available at `http://localhost:<HTTP_PORT>/` with the user `admin` and the
password `openmu` — [change that](../../docs-website/docs/admin-panel/users.md)
before the server is reachable from the internet.
