#!/bin/sh
# Nexlayer entrypoint for Invoice Ninja (single pod: nginx + php-fpm).
#
# Derived from the upstream debian init.sh, with two changes:
#   1. cache:clear / ninja:design-update / optimize are made NON-FATAL. Upstream
#      runs `#!/bin/sh -eu`, so a single failing cache:clear (e.g. a transient
#      permissions/driver hiccup) aborts boot -> supervisord never starts ->
#      CrashLoopBackOff -> edge 502. Serving requests does not require those
#      steps to succeed, so we log-and-continue instead of dying.
#   2. We config:clear first so the runtime env (CACHE_DRIVER=file, etc.) wins
#      over any stale baked config cache.
set -u

if [ "$(dpkg --print-architecture)" = "amd64" ]; then
    export SNAPPDF_CHROMIUM_PATH=/usr/bin/google-chrome-stable
elif [ "$(dpkg --print-architecture)" = "arm64" ]; then
    export SNAPPDF_CHROMIUM_PATH=/usr/bin/chromium
fi

if [ "$*" = 'supervisord -c /etc/supervisor/supervisord.conf' ]; then

    [ -d /var/www/html/public ] || mkdir -p /var/www/html/public
    [ -d /var/www/html/storage/app/public ] || mkdir -p /var/www/html/storage/app/public
    [ -d /var/www/html/storage/framework/sessions ] || mkdir -p /var/www/html/storage/framework/sessions
    [ -d /var/www/html/storage/framework/views ] || mkdir -p /var/www/html/storage/framework/views
    [ -d /var/www/html/storage/framework/cache ] || mkdir -p /var/www/html/storage/framework/cache

    if [ -d /tmp/public ] && [ "$(ls -A /tmp/public 2>/dev/null)" ]; then
        echo "Updating public folder..."
        rm -rf /var/www/html/public/.htaccess /var/www/html/public/.well-known /var/www/html/public/* 2>/dev/null || true
        cp -r /tmp/public/* /tmp/public/.htaccess /tmp/public/.well-known /var/www/html/public/ 2>/dev/null || true
        rm -rf /tmp/public/.htaccess /tmp/public/.well-known /tmp/public/* 2>/dev/null || true
    fi
    echo "Public Folder is up to date"

    chown -R www-data:www-data /var/www/html/public /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true
    find /var/www/html/public /var/www/html/storage -type f -exec chmod 644 {} \; 2>/dev/null || true
    find /var/www/html/public /var/www/html/storage -type d -exec chmod 755 {} \; 2>/dev/null || true

    if [ "${APP_ENV:-production}" = "production" ]; then
        # config:clear so runtime env (file cache, no redis) overrides any cache.
        runuser -u www-data -- php artisan config:clear || echo "WARN: config:clear failed (non-fatal)"
        runuser -u www-data -- php artisan migrate --force || echo "WARN: migrate failed (non-fatal)"
        runuser -u www-data -- php artisan cache:clear || echo "WARN: cache:clear failed (non-fatal)"
        runuser -u www-data -- php artisan ninja:design-update || echo "WARN: design-update failed (non-fatal)"
        runuser -u www-data -- php artisan optimize || echo "WARN: optimize failed (non-fatal)"

        if [ "$(runuser -u www-data -- php artisan tinker --execute='echo Schema::hasTable("accounts") && !App\Models\Account::all()->first();' 2>/dev/null)" = "1" ]; then
            echo "Running initialization..."
            runuser -u www-data -- php artisan db:seed --force || echo "WARN: db:seed failed (non-fatal)"
            if [ -n "${IN_USER_EMAIL:-}" ] && [ -n "${IN_PASSWORD:-}" ]; then
                runuser -u www-data -- php artisan ninja:create-account --email "${IN_USER_EMAIL}" --password "${IN_PASSWORD}" || echo "WARN: create-account failed (non-fatal)"
            fi
        fi
        echo "Production setup completed"
    fi

    echo "Starting supervisord..."
fi

exec "$@"
