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
