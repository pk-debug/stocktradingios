# A repeatable server image. Build from the mobile repository root after checking
# out the pinned paper backend into .backend; see README.md in this directory.
FROM python:3.12-slim
WORKDIR /srv
COPY backend-auth/requirements.lock /srv/requirements.lock
# Ordinary builds use public CA roots. Managed cloud builds may mount their proxy
# CA as a BuildKit secret; TLS verification stays enabled in both cases.
RUN --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then \
      PIP_CERT=/run/secrets/proxy_ca pip install --no-cache-dir -r requirements.lock; \
    else pip install --no-cache-dir -r requirements.lock; fi
COPY .backend/paper-trading-api/app /srv/paper-trading-api/app
COPY backend-auth/identity_gateway.py /srv/identity_gateway.py
RUN chmod -R a+rX /srv && mkdir /data && chown 10001:10001 /data
ENV PYTHONPATH=/srv/paper-trading-api NORTHSTAR_DB=/data/northstar.sqlite3 PYTHONDONTWRITEBYTECODE=1
USER 10001:10001
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3)"
CMD ["uvicorn", "identity_gateway:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]
