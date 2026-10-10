Initial build time: ~50s
Initial size: 87.2MB

```
[+] Building 50.8s (16/16) FINISHED                                                     docker:desktop-linux
 => [builder 2/6] RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev libcurl4-openssl-dev libssl-dev && rm -rf /var/lib/apt/lists/*   27.8s
 => [stage-1 2/6] RUN apt-get update && apt-get install -y --no-install-recommends libpq5 && rm -rf /var/lib/apt/lists/* && useradd …                            10.1s
 => [builder 3/6] RUN python -m venv /opt/venv                                                                                                                     2.1s
 => [builder 6/6] RUN pip install --no-cache-dir -r requirements.txt                                                                                              16.7s
 => [stage-1 3/6] COPY --from=builder /opt/venv /opt/venv                                                                                                          0.5s
 => [stage-1 5/6] COPY . .                                                                                                                                         0.1s
 => [stage-1 6/6] RUN python manage.py collectstatic --noinput && python manage.py compress                                                                        1.6s
 => exporting to image                                                                                                                                             1.7s
 => => naming to docker.io/library/healthchecks:v1.1
 ```

 ```
 healthchecks:v1.1                                                                                     18a251ad245d       87.2MB         87.2MB
 ```

 Optimization steps:

 1. Replaced the build image with python:3.13-trixie. It has all the necessary packages pre-installed, so the RUN layer can be removed.
 Build time after step 1: ~21s
 Size: the same
 
 ```
 [+] Building 21.2s (17/17) FINISHED                                                     docker:desktop-linux
  => [stage-1 2/6] RUN apt-get update && apt-get install -y --no-install-recommends libpq5 && rm -rf /var/lib/apt/lists/* && useradd …                              5.6s
  => [builder 2/5] RUN python -m venv /opt/venv                                                                                                                     2.4s
  => [builder 5/5] RUN pip install --no-cache-dir -r requirements.txt                                                                                              14.6s
  => [stage-1 3/6] COPY --from=builder /opt/venv /opt/venv                                                                                                          0.5s
  => [stage-1 5/6] COPY . .                                                                                                                                         0.1s
  => [stage-1 6/6] RUN python manage.py collectstatic --noinput && python manage.py compress                                                                        1.6s
  => exporting to image                                                                                                                                             1.8s
  => => naming to docker.io/library/healthchecks:v1.2
  ```

2. Virtual environment without its own pip. Added '--without-pip' to creates the venv without pip. The base image's pip installs the packages into the venv, using --python /opt/venv/bin/python
Build time: the same
Size: reduced by ~4MB

```
healthchecks:v1.2                                                                                    8b3d0ee28e99        83.5MB         83.5MB
```

3. Build static files in the builder, copy only what the runtime needs.
Buld time: the same
Size: reduced by ~4.5MB

```
healthchecks:v1.3                                                                                     aeefa7e7e22b       78.9MB         78.9MB
```

**Builder stage:**

```dockerfile
COPY . .

RUN DEBUG=False python manage.py collectstatic --noinput \
    && DEBUG=False python manage.py compress
```

**Runtime stage:** instead of `COPY . .` followed by `collectstatic` / `compress`:

```dockerfile
COPY manage.py search.db CHANGELOG.md ./
COPY templates ./templates
COPY hc ./hc
COPY --from=builder /build/static-collected ./static-collected
```

**Before:** the whole project was copied into the final image, and `collectstatic` / `compress` ran there. The final image contained:
- the source assets in `static/` (3.6 MB). They're only an input to `collectstatic` and are never served. WhiteNoise serves `static-collected/`.
- other files the application doesn't use at runtime: the Markdown files in the repository root (except `CHANGELOG.md`) and `requirements.txt`
- the `.pyc` files created by running Django during the build

**Why it helps:**
- The final image receives only what the running application needs. `/app` shrank from 22 MB to 18 MB.
- The final stage no longer runs any Python during the build. It only contains `COPY` steps.
