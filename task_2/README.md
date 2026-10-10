# Local development with Docker Compose

This guide covers running the Healthchecks Django app and a Postgres database
locally with one command: `docker compose up`.

## Why Docker Compose?

Docker Compose describes a multi-container application in one YAML file
(`task_2/docker-compose.yaml`). One command then creates and starts every service, along
with the network that connects them and the volumes that store their data.

Benefits for local development:

| Without Compose | With Compose |
|---|---|
| Install Python, Postgres and system libraries (libpq, libcurl…) on every laptop | Only Docker is needed |
| "Works on my machine": different Postgres/Python versions | Everyone runs the same pinned images |
| Long README of manual steps (create DB, set env vars, migrate…) | `docker compose up --build` |
| Containers started by hand with `docker run`, `docker network create`, long flag lists | Services, networks, volumes, ports and env vars are declared once and kept in git |
| Start-up order is manual (DB first, then migrate, then app) | `depends_on` + healthchecks start things in the right order |
| Hard to reset to a clean state | `docker compose down -v` wipes everything |
| Projects conflict over ports, DB names and versions | Each project is isolated in its own Compose network and volumes |

The same Dockerfile that builds the production image (`task_1/Dockerfile`) also
builds the dev environment. Dev and prod run the same code and dependencies.

## What's in the stack

`task_2/docker-compose.yaml` defines five services:

| Service | Image | Purpose |
|---|---|---|
| `db` | `postgres:17` | Postgres database. Data is kept in the named volume `db-data`. A `pg_isready` healthcheck tells the other services when it can accept connections. |
| `migrate` | `healthchecks:dev` (built from `task_1/Dockerfile`) | One-off job that runs `manage.py migrate` and then exits. |
| `web` | `healthchecks:dev` | Django dev server (`runserver`) with auto-reload, at <http://localhost:8000>. |
| `sendalerts` | `healthchecks:dev` | Background worker that sends notifications when a check goes down. |
| `mailpit` | `axllent/mailpit` | Fake SMTP server that catches all outgoing email (sign-up links, alerts). UI at <http://localhost:8025>. |

Start-up order is enforced with `depends_on` conditions:

```
db (healthy) ──► migrate (completed successfully) ──► web, sendalerts
mailpit (started) ─────────────────────────────────► web, sendalerts
```

### How Django connects to Postgres

`hc/settings.py` reads the database configuration from environment variables.
Compose sets them for every app container:

```yaml
DB: postgres          # switch from the default SQLite to Postgres
DB_HOST: db           # the service name; Compose's internal DNS resolves it to the db container
DB_PORT: "5432"
DB_NAME / DB_USER / DB_PASSWORD   # same values that initialise the Postgres container
```

The services share a private network (`healthchecks_default`), so `web` reaches
the database at `db:5432`. Port 5432 is also published to the host so you can
connect with `psql`, DBeaver or another GUI tool.

### Live code reload

`../hc`, `../templates` and `../static` (relative to `task_2/`) are bind-mounted into the containers, and
`web` runs `runserver` with `DEBUG=True`. When you edit Python code or a
template on your machine, the change shows up right away without rebuilding the
image. Rebuild only after you change `requirements.txt` or the Dockerfile.

## Steps I followed

1. Studied Docker Compose: services, networks, volumes, `depends_on` with
   healthchecks, env files, YAML anchors (`x-app` / `<<: *app`) to avoid
   repeating config.
2. Reused the optimized Dockerfile from `task_1/Dockerfile`. The compose
   file sets the build context to `..` (repo root), so the source code and the
   existing `.dockerignore` apply. Bind-mount paths are also relative to
   `task_2/`.
3. Read `hc/settings.py` to find the environment variables the app needs
   (`DB`, `DB_HOST`, `DB_*`, `SECRET_KEY`, `ALLOWED_HOSTS`, `SITE_ROOT`,
   `EMAIL_*`).
4. Extended the initial `task_2/docker-compose.yaml` (which had only `db` and
   a pre-built `web` image that ran migrations and the server in one command):
   - `web` now builds the image from `task_1/Dockerfile`, so no manual
     `docker build` is needed;
   - migrations moved into a separate one-off `migrate` service;
   - added the `sendalerts` worker and `mailpit` for email;
   - all settings can be overridden through `.env`, with defaults built in;
   - source code is bind-mounted for live reload;
   - published the Postgres port for local DB tools.
5. Added `task_2/.env.example` with all the settings you can override. `.env` is
   already in `.gitignore`.
6. Verified the setup:
   - `docker compose config` validates the file;
   - `docker compose up -d --build` → `migrate` exits with code 0 and `web`,
     `sendalerts`, `db` and `mailpit` are running;
   - <http://localhost:8000/accounts/login/> returns 200 and static files load;
   - created a superuser and a check, sent a ping to `/ping/<uuid>`, and
     confirmed in Postgres that `n_pings = 1, status = up`;
   - sent a test email and it appeared in Mailpit;
   - ran `docker compose down` then `up` again, and the data was still there
     (named volume).

## Quick start for teammates

Prerequisites: Docker Desktop (or Docker Engine + the Compose v2 plugin).

```bash
git clone <repo-url> && cd <repo>/task_2

# Optional: override defaults (ports, passwords, …)
cp .env.example .env

# Build the image and start everything (run from task_2/)
docker compose up --build        # add -d to run in the background
```

Then:

- App: <http://localhost:8000>
- Emails (sign-up / login links, alerts): <http://localhost:8025>
- Postgres: `localhost:5432`, user `postgres`, password `postgres`, db `hc`

Create an admin account:

```bash
docker compose exec web python manage.py createsuperuser --email admin@example.org --password admin123
```

Admin panel: <http://localhost:8000/admin/>

## Everyday commands

Run these from `task_2/` (or add `-f task_2/docker-compose.yaml` from the repo root).

```bash
docker compose ps                         # status of services
docker compose logs -f web                # follow logs of one service
docker compose exec web python manage.py shell        # Django shell
docker compose exec web python manage.py makemigrations
docker compose run --rm migrate           # re-apply migrations
docker compose exec db psql -U postgres -d hc         # Postgres shell
docker compose restart web                # restart one service
docker compose up -d --build              # rebuild after changing requirements.txt / Dockerfile
docker compose stop                       # stop, keep containers & data
docker compose down                       # remove containers, keep DB data
docker compose down -v                    # remove containers AND the database volume (fresh start)
```

## Configuration

All settings have defaults in `docker-compose.yaml`. To override them, create
`task_2/.env` (see `task_2/.env.example`):

| Variable | Default | Notes |
|---|---|---|
| `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | `hc` / `postgres` / `postgres` | Used by both Postgres and Django |
| `POSTGRES_PORT` | `5432` | Host port for Postgres; change it if 5432 is already in use |
| `WEB_PORT` | `8000` | Host port for the app |
| `MAILPIT_UI_PORT` | `8025` | Host port for the Mailpit UI |
| `DEBUG` | `True` | |
| `SECRET_KEY` | dev-only value | Never reuse it in production |
| `SITE_ROOT` / `ALLOWED_HOSTS` | `http://localhost:8000` / `localhost,127.0.0.1` | |

## Troubleshooting

- **`port is already allocated`**: another process (often a local Postgres) is
  using the port. Set `POSTGRES_PORT=5433` or `WEB_PORT=8001` in `.env`.
- **`web` doesn't start**: run `docker compose logs migrate`. A failed
  migration blocks `web` and `sendalerts`.
- **DB password changed but login fails**: Postgres reads `POSTGRES_*` only
  when the volume is first created. Run `docker compose down -v` to recreate it.
- **New Python package isn't found**: run `docker compose up -d --build`.

> This setup is for local development only (dev server, `DEBUG=True`, default
> passwords). Production uses the gunicorn `CMD` from the Dockerfile with
> proper secrets.
