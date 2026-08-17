# Multi-stage build so the final image only ships wheels + app code —
# no gcc, no build tooling, no cache. Runs as an unprivileged user.

# ─── Stage 1: build wheels for all Python deps ─────────────────────────
FROM python:3.12-slim AS wheels
WORKDIR /wheels

# System deps needed to compile psycopg2 + Pillow from source. Alpine
# is smaller but the Pillow build takes forever; slim + wheels is faster.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt


# ─── Stage 2: runtime ──────────────────────────────────────────────────
FROM python:3.12-slim AS runtime

# Runtime libs only — libpq for psycopg2, jpeg/zlib for Pillow.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq5 \
        libjpeg62-turbo \
        zlib1g \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 1001 broker \
    && useradd  --system --uid 1001 --gid broker --create-home broker

WORKDIR /app

# Install wheels from stage 1 — no compilation at runtime, tiny layer.
COPY --from=wheels /wheels /wheels
COPY requirements.txt .
RUN pip install --no-cache-dir --no-index --find-links /wheels -r requirements.txt \
    && rm -rf /wheels

# App code + persistent upload dir.
COPY --chown=broker:broker . /app
RUN mkdir -p /var/broker/uploads && chown -R broker:broker /var/broker

USER broker

# Gunicorn will listen here; compose forwards it to the host.
EXPOSE 5000

# Container-native health check — matches the compose depends_on setup.
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health', timeout=2)" || exit 1

# Default command overridden by compose to run migrations first; kept
# here so `docker run` alone also works.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "wsgi:app"]
