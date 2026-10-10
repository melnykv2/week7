# Healthchecks + Postgres with Docker Compose

This guide runs the Dockerized Healthchecks (Django) app together with a
Postgres database using one command: `docker compose up`.

## Why Docker Compose?

Docker Compose describes a multi-container application in one YAML file. One
command creates the whole environment: images, containers, the network
between them and the volumes for data.

Benefits for local development:

| Without Compose | With Compose |
|---|---|
| Install Python, Postgres and system libraries (libpq, libcurl…) on every laptop | Only Docker is needed |
| "Works on my machine": different Postgres/Python versions | Everyone runs the same pinned images |
| Manual steps: create DB, set env vars, run migrations, start the server | `docker compose up --build` |
| Long `docker network create` / `docker run -e … -p … --network …` commands | Services, network, volumes, ports and env vars are declared once and kept in git |
| You have to start the DB first and then the app | `depends_on` + a healthcheck start the app only when Postgres is ready |
| Hard to reset to a clean state | `docker compose down -v` wipes everything |

## The setup

`task_2/docker-compose.yaml` defines two services:

| Service | Image | Purpose |
|---|---|---|
| `db` | `postgres:17` | Postgres database. Data is stored in the named volume `db-data`, so it survives restarts. A `pg_isready` healthcheck reports when it can accept connections. |
| `web` | `healthchecks:latest`, built from `task_1/Dockerfile` | The application. On start it runs `manage.py migrate`, then serves the app with gunicorn on port 8000. |

- **Build**: `build.context: ..` points to the repo root (the source code and
  `.dockerignore`), and `dockerfile: task_1/Dockerfile` reuses the optimized
  multi-stage Dockerfile from task 1. `docker compose up --build` packs the
  app into an image, so nobody needs to run `docker build` by hand.
- **Start-up order**: `web` has `depends_on: db: condition: service_healthy`,
  so it waits until Postgres passes its healthcheck.
- **Static files**: they are collected and compressed when the image is built,
  and WhiteNoise serves them at runtime (`DEBUG=False`).

### How Django connects to Postgres

`hc/settings.py` reads the database configuration from environment variables:

```yaml
DB: postgres          # switch from the default SQLite to Postgres
DB_HOST: db           # the service name; Compose's internal DNS resolves it to the db container
DB_NAME / DB_USER / DB_PASSWORD   # same values that initialise the Postgres container
```

Both services join the project's default network, so `web` reaches the
database at `db:5432`. The database port is not published to the host. Only
the app is exposed, on `localhost:8000`.

## Steps I followed

1. Studied Docker Compose: services, `build`, environment variables and
   `.env` interpolation, named volumes, networks, `depends_on` with
   healthchecks.
2. Read `hc/settings.py` to find the variables the app needs (`DB`,
   `DB_HOST`, `DB_*`, `SECRET_KEY`, `ALLOWED_HOSTS`, `SITE_ROOT`).
3. Updated `task_2/docker-compose.yaml`:
   - `web` now builds from `task_1/Dockerfile` instead of using a
     pre-built `healthchecks:v1.4` image;
   - `web` runs `migrate` and then gunicorn (the production server from the
     image) instead of the Django dev server;
   - `DEBUG=False`, and `SECRET_KEY`, `SITE_ROOT` and `ALLOWED_HOSTS` are set;
   - passwords and ports come from `.env`, with defaults
     (`${VAR:-default}`);
   - added `restart: unless-stopped` and a stricter healthcheck (timeout,
     retries).
4. Added `task_2/.env.example`. `.env` is in `.gitignore`.
5. Verified the setup:
   - `docker compose config` → valid;
   - `docker compose up -d --build` → `db` is healthy, migrations are applied,
     gunicorn is listening on 8000;
   - <http://localhost:8000/accounts/login/> → 200, and compressed CSS is
     served → 200;
   - created a superuser and a check, sent `GET /ping/<uuid>` → `OK`, and in
     Postgres the check had `n_pings = 1, status = up`;
   - ran `docker compose down` then `up` again, and the data was still there.

## How to use it (for teammates)

Prerequisites: Docker Desktop (or Docker Engine + the Compose v2 plugin).

```bash
git clone <repo-url>
cd <repo>/task_2

cp .env.example .env          # optional: change passwords, ports, SECRET_KEY
docker compose up -d --build  # build the image and start db + web
```

Open <http://localhost:8000>.

Create an admin account (Healthchecks' `createsuperuser` takes email and
password):

```bash
docker compose exec web python manage.py createsuperuser --email admin@example.org --password admin123
```

Admin panel: <http://localhost:8000/admin/>

### Everyday commands

Run these from `task_2/`:

```bash
docker compose ps                     # status
docker compose logs -f web            # app logs
docker compose exec web python manage.py shell     # Django shell
docker compose exec db psql -U postgres -d hc      # Postgres shell
docker compose up -d --build          # rebuild after code changes
docker compose down                   # stop and remove containers (DB data is kept)
docker compose down -v                # also delete the database volume (fresh start)
```

### Configuration (`.env`)

| Variable | Default |
|---|---|
| `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | `hc` / `postgres` / `postgres` |
| `SECRET_KEY` | `change-me` |
| `SITE_ROOT` | `http://localhost:8000` |
| `ALLOWED_HOSTS` | `localhost,127.0.0.1` |
| `WEB_PORT` | `8000` |

### Troubleshooting

- **`port is already allocated`**: set `WEB_PORT=8001` in `.env`.
- **The app can't log in to the DB after you change `POSTGRES_PASSWORD`**:
  Postgres reads `POSTGRES_*` only when the volume is first created. Run
  `docker compose down -v` to recreate it.
- **Warning `No SMTP configuration, cannot send email`**: expected. Email is
  not configured in this setup, so features that send email (sign-up links,
  alerts) won't deliver.
