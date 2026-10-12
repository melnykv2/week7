## Differences from task 2 (bridge)

| | Task 2: bridge | Task 3: host |
|---|---|---|
| `network_mode` | default (Compose network `task_2_default`) | `host` |
| Container IP | own IP (e.g. `172.18.0.x`) | none, uses the host's |
| How web finds the DB | `DB_HOST: db` (Docker DNS) | `DB_HOST: 127.0.0.1` (same network stack) |
| Access to the app | `ports: "8000:8000"` | no `ports:`, gunicorn binds to the host's `:8000` directly |
| Postgres port 5432 | visible only inside the Compose network | open on the host |

## How to run

```bash
cd task_3
docker compose up -d --build
```

## Cleanup

```bash
docker compose down        # add -v to also delete the database volume
```
