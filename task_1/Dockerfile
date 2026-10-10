FROM python:3.13-trixie@sha256:71d866ed79158f6ff25b096687f90ca706684937ea2032b86e479a060d9eaa7d AS builder

RUN python -m venv --without-pip /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /build

COPY requirements.txt .

RUN pip --python /opt/venv/bin/python install --no-cache-dir -r requirements.txt

COPY . .

RUN DEBUG=False python manage.py collectstatic --noinput \
    && DEBUG=False python manage.py compress

FROM python:3.13-slim-trixie@sha256:bf44cdfcb76cd3b41e879bc058fc37ec5872002ccfde7fcb765e218cde0cd79c

ENV DB=postgres \
    DEBUG=False \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 1000 -s /usr/sbin/nologin --no-create-home app

COPY --from=builder /opt/venv /opt/venv

WORKDIR /app

COPY manage.py search.db CHANGELOG.md ./
COPY templates ./templates
COPY hc ./hc
COPY --from=builder /build/static-collected ./static-collected

USER 1000

EXPOSE 8000

CMD [ "gunicorn", "hc.wsgi:application", "--bind", "0.0.0.0:8000" ]
