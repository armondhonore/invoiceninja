# Nexlayer fix (pinned — authoritative, use verbatim)

Root cause of the 502: the stock `invoiceninja/invoiceninja-debian` image is
php-fpm ONLY (listens on :9000, no web server). The platform edge maps :80 to
the pod, so there is nothing serving HTTP → 502. Secondary: the upstream
entrypoint runs `#!/bin/sh -eu`, so a failing `cache:clear` aborts boot →
CrashLoopBackOff.

Fix: a thin wrapper image that bakes nginx in to serve :80 (proxying *.php to
local php-fpm:9000) plus an entrypoint that makes cache:clear/optimize
non-fatal. The Dockerfile COPYs three files committed under `nexlayer-docker/`
on this branch — do not regenerate the Dockerfile.

## Fixed Dockerfile

```
FROM invoiceninja/invoiceninja-debian:latest

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY nexlayer-docker/nginx-default.conf /etc/nginx/conf.d/default.conf
RUN rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

COPY nexlayer-docker/nginx-supervisor.conf /etc/supervisor/conf.d/nginx.conf

COPY --chmod=0755 nexlayer-docker/init-nexlayer.sh /usr/local/bin/init-nexlayer.sh

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/init-nexlayer.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
```

## Fixed nexlayer.yaml

```
application:
  name: invoiceninja
  pods:
  - name: app
    image: invoiceninja/invoiceninja-debian:latest
    path: /
    servicePorts:
    - 80
    vars:
      APP_ENV: production
      APP_KEY: "base64:WM83G829MpixFnAxuqx7QkdFPr/9/kkHB1QVNaYn1u0="
      APP_URL: "https://relaxed-weasel-invoiceninja.cloud.nexlayer.ai"
      DB_HOST: mysql.pod
      DB_PORT: "3306"
      DB_DATABASE: invoiceninja
      DB_USERNAME: invoiceninja
      DB_PASSWORD: "${MYSQL_PASSWORD}"
      REQUIRE_HTTPS: "true"
      IS_DOCKER: "true"
      TRUSTED_PROXIES: "*"
      CACHE_DRIVER: file
      SESSION_DRIVER: file
      QUEUE_CONNECTION: sync
      LOG_CHANNEL: stderr
      IN_USER_EMAIL: "admin@example.com"
      IN_PASSWORD: "nexlayer2024"
    volumes:
    - name: invoiceninja-storage
      mountPath: /var/www/html/storage
      size: 5Gi
  - name: mysql
    image: mirror.gcr.io/library/mysql:8
    servicePorts:
    - 3306
    vars:
      MYSQL_DATABASE: invoiceninja
      MYSQL_USER: invoiceninja
      MYSQL_PASSWORD: "${MYSQL_PASSWORD}"
      MYSQL_ROOT_PASSWORD: "${MYSQL_ROOT_PASSWORD}"
    volumes:
    - name: invoiceninja-db
      mountPath: /var/lib/mysql
      size: 5Gi
```
