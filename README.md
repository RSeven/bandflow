# BandFlow

BandFlow is a Rails app for managing bands, repertoire, setlists, and live presentation mode.

## Local setup

```bash
bundle install
bin/rails db:prepare
bin/dev
```

API keys for the external metadata services (Spotify, Genius, YouTube) and the Docker Hub registry token used by Kamal live in a local `.env` file at the repo root. It is gitignored — never commit it.

```
SPOTIFY_CLIENT_ID=...
SPOTIFY_CLIENT_SECRET=...
GENIUS_ACCESS_TOKEN=...
YOUTUBE_API_KEY=...
KAMAL_REGISTRY_PASSWORD=...
```

### Developing behind an ngrok tunnel

Some integrations (OAuth callbacks, shared links) need a public hostname. `config/environments/development.rb` reads `APP_HOST` and `APP_PROTOCOL` from the environment and falls back to a default ngrok hostname, so you can either start ngrok with the baked-in host or override it:

```bash
ngrok http --url=horribly-suited-garfish.ngrok-free.app 3000
# or, with a different tunnel
APP_HOST=my-tunnel.ngrok-free.app bin/dev
```

## Test suite

```bash
bundle exec rspec
```

## Deployment (Oracle Cloud via Kamal)

This app deploys to a single Oracle Cloud VM using [Kamal](https://kamal-deploy.org). The production setup:

- Ubuntu VM on Oracle Cloud (Always Free tier eligible)
- Docker image built locally and pushed to Docker Hub (`ruanlps/bandflow`)
- `kamal-proxy` on the VM terminates TLS via Let's Encrypt
- SQLite databases and local Active Storage files live in a Docker volume (`bandflow_storage`) mounted at `/rails/storage`
- Solid Queue runs inside Puma via `SOLID_QUEUE_IN_PUMA=true`
- Cloudflare proxies `bandflow.ruanlps.com` in front (SSL/TLS mode: **Full (strict)**)

### One-time setup on a fresh VM

1. Provision an Ubuntu instance on Oracle Cloud and assign it a reserved public IP.
2. Open ports **80** and **443** in the VCN security list and in the instance's iptables (`sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT` + same for 443, then `sudo netfilter-persistent save`).
3. Point DNS at the instance IP.
4. Ensure `.env` has `KAMAL_REGISTRY_PASSWORD` set to a Docker Hub access token with push rights on the `bandflow` repository.
5. From the repo:

```bash
bin/kamal setup
```

This installs Docker on the VM, builds the image locally, pushes it to Docker Hub, and starts the app and `kamal-proxy`.

### Subsequent deploys

```bash
bin/kamal deploy
```

### Common commands

```bash
bin/kamal app logs -f           # tail production logs
bin/kamal console               # Rails console on the running container
bin/kamal shell                 # bash on the running container
bin/kamal rollback <version>    # roll back to a previous image
```

### Notes

- Everything lives on a single machine: SQLite (primary, cache, queue), local Active Storage, and in-process jobs. Do not horizontally scale without first moving state off local disk.
- The Docker volume `bandflow_storage` is the only durable state. Back up `/rails/storage/production.sqlite3` regularly.
- If you change the deployment host or registry username, update `config/deploy.yml`.
