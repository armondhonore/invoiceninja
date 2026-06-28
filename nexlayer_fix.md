# Nexlayer fix (pinned — authoritative, use verbatim)

Root cause of the 502: stock `invoiceninja/invoiceninja-debian` is php-fpm ONLY
(:9000, no web server). The :80 edge returns 502. The app pod image MUST be the
pipeline placeholder so the runner injects the freshly BUILT wrapper image
(nginx on :80 -> local php-fpm:9000, non-fatal entrypoint). No storage PVC
(ephemeral, avoids RWO rollout block). Do NOT regenerate the Dockerfile.

## Fixed Dockerfile

```
# Single-pod Invoice Ninja for Nexlayer (fully self-contained — no COPY context).
#
# Upstream invoiceninja/invoiceninja-debian is php-fpm ONLY (:9000, no web
# server). The platform edge maps :80 to the pod, so the stock image yields a
# 502. We bake nginx in to serve :80 and proxy *.php to local php-fpm:9000, and
# we install our own entrypoint that NEVER aborts boot on a failed artisan
# cache:clear/optimize (upstream's `sh -eu` entrypoint dies there -> backoff).
FROM invoiceninja/invoiceninja-debian:latest
USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /etc/nginx/sites-enabled/default

# nginx vhost: :80 -> /var/www/html/public, FastCGI *.php to local php-fpm:9000.
RUN printf '%s\n' \
    'server {' \
    '  listen 80 default_server;' \
    '  server_name _;' \
    '  root /var/www/html/public;' \
    '  index index.php;' \
    '  client_max_body_size 64M;' \
    '  location / { try_files $uri $uri/ /index.php?$query_string; }' \
    '  location = /favicon.ico { access_log off; log_not_found off; }' \
    '  location = /robots.txt  { access_log off; log_not_found off; }' \
    '  error_page 404 /index.php;' \
    '  location ~ \.php$ {' \
    '    fastcgi_pass 127.0.0.1:9000;' \
    '    fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;' \
    '    include fastcgi_params;' \
    '    fastcgi_read_timeout 120s;' \
    '  }' \
    '  location ~ /\.(?!well-known).* { deny all; }' \
    '}' \
    > /etc/nginx/conf.d/default.conf

# Run nginx under supervisor alongside php-fpm/queue/scheduler.
RUN printf '%s\n' \
    '[program:nginx]' \
    'command=/usr/sbin/nginx -g "daemon off;"' \
    'autostart=true' \
    'autorestart=true' \
    'priority=10' \
    'stdout_logfile=/dev/fd/1' \
    'stdout_logfile_maxbytes=0' \
    'redirect_stderr=true' \
    > /etc/supervisor/conf.d/nginx.conf

# Self-contained entrypoint: prep dirs, fix ownership, run artisan steps but
# treat ALL of them as non-fatal, then exec the original CMD (supervisord).
RUN printf '%s\n' \
    '#!/bin/sh' \
    'set -u' \
    'mkdir -p /var/www/html/storage/app/public /var/www/html/storage/framework/sessions /var/www/html/storage/framework/views /var/www/html/storage/framework/cache /var/www/html/bootstrap/cache' \
    'if [ -d /tmp/public ] && [ "$(ls -A /tmp/public 2>/dev/null)" ]; then cp -r /tmp/public/. /var/www/html/public/ 2>/dev/null || true; fi' \
    'chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache /var/www/html/public 2>/dev/null || true' \
    'runuser -u www-data -- php artisan config:clear || echo "WARN config:clear"' \
    'runuser -u www-data -- php artisan migrate --force || echo "WARN migrate"' \
    'runuser -u www-data -- php artisan cache:clear || echo "WARN cache:clear"' \
    'runuser -u www-data -- php artisan optimize || echo "WARN optimize"' \
    'runuser -u www-data -- php artisan db:seed --force || echo "WARN seed (likely already seeded)"' \
    'if [ -n "${IN_USER_EMAIL:-}" ] && [ -n "${IN_PASSWORD:-}" ]; then runuser -u www-data -- php artisan ninja:create-account --email "$IN_USER_EMAIL" --password "$IN_PASSWORD" || echo "WARN create-account (likely exists)"; fi' \
    'echo "nx-init done — starting supervisord"' \
    'exec "$@"' \
    > /usr/local/bin/nx-init.sh \
    && chmod +x /usr/local/bin/nx-init.sh

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/nx-init.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
```

## Fixed nexlayer.yaml

```
application:
  name: invoiceninja
  pods:
  - name: app
    # IMPORTANT: this MUST be the literal pipeline placeholder so the runner
    # patches in the freshly BUILT wrapper image (FROM invoiceninja-debian +
    # baked-in nginx on :80 -> local php-fpm:9000). If a real image ref is put
    # here, the runner deploys THAT stock image instead of the built wrapper —
    # which is php-fpm-only on :9000 (no :80 listener) -> edge 502.
    image: "# filled by pipeline"
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
      # No Redis pod in this deployment — keep cache/session/queue off Redis so
      # the entrypoint's cache-clear step does not fail trying to reach redis.
      CACHE_DRIVER: file
      SESSION_DRIVER: file
      QUEUE_CONNECTION: sync
      LOG_CHANNEL: stderr
      # First-run init (init.sh) seeds the DB and REQUIRES these to create the
      # initial admin account, else it exits 1.
      IN_USER_EMAIL: "admin@example.com"
      IN_PASSWORD: "nexlayer2024"
    # NO storage PVC. A ReadWriteOnce PVC mounted by the old (crashlooping) pod
    # blocks the new pod from attaching it -> the rollout never completes and the
    # old broken image keeps serving (502/503). Storage is ephemeral (fine for
    # test data); the entrypoint recreates the framework dirs on each boot.
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
