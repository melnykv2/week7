`task_2/docker-compose.yaml` defines two services:

| Service | Image | Purpose |
|---|---|---|
| `db` | `postgres:17` | Postgres database. Data is stored in the named volume `db-data`, so it survives restarts. A `pg_isready` healthcheck reports when it can accept connections. |
| `web` | `healthchecks:dev`, built from `task_1/Dockerfile` | The application. On start it runs `manage.py migrate`, then serves the app with gunicorn on port 8000. |

## How to use it:

Prerequisites: Docker Desktop (or Docker Engine + the Compose v2 plugin).

```bash
git clone <repo-url>
cd <repo>/task_2

docker compose up -d --build  # build the image and start db + web
```

Open <http://localhost:8000>.

Create an admin account (Healthchecks' `createsuperuser` takes email and
password):

```bash
docker compose exec web python manage.py createsuperuser --email admin@example.org --password admin123
```

Admin panel: <http://localhost:8000/admin/>
