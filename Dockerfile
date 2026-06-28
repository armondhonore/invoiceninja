# Single-pod Invoice Ninja for Nexlayer.
#
# The upstream invoiceninja/invoiceninja-debian image is php-fpm ONLY (listens
# on :9000, no web server). The official deployment pairs it with a separate
# nginx container that serves :80 and proxies *.php to php-fpm:9000 (see the
# project's docker-compose). Nexlayer maps the public edge to a single
# containerPort, so we bake nginx INTO the image here and serve :80 in-pod,
# proxying PHP to 127.0.0.1:9000. This is the only way to get a real HTTP
# listener on the mapped port within Nexlayer's one-service-per-pod model.
FROM mirror.gcr.io/invoiceninja/invoiceninja-debian:latest
# build-time env seeded from .env.example
ENV APPLE_CLIENT_ID=nexlayer-placeholder
ENV APPLE_CLIENT_SECRET=nexlayer-placeholder
ENV APPLE_REDIRECT_URI=nexlayer-placeholder
ENV APPSTORE_PASSWORD=nexlayer-placeholder
ENV APP_DEBUG=false
ENV APP_ENV=production
ENV APP_KEY=base64:RR++yx2rJ9kdxbdh3+AmbHLDQu+Q76i++co9Y8ybbno=
ENV APP_NAME="Invoice Ninja"
ENV APP_URL=http://localhost
ENV BROADCAST_DRIVER=log
ENV CACHE_DRIVER=file
ENV DB_CONNECTION=mysql
ENV DB_DATABASE=ninja
ENV DB_HOST=localhost
ENV DB_PASSWORD=ninja
ENV DB_PORT=3306
ENV DB_USERNAME=ninja
ENV DELETE_BACKUP_DAYS=60
ENV DELETE_PDF_DAYS=60
ENV DEMO_MODE=false
ENV ERROR_EMAIL=nexlayer-placeholder
ENV GOCARDLESS_CLIENT_ID=nexlayer-placeholder
ENV GOCARDLESS_CLIENT_SECRET=nexlayer-placeholder
ENV GOOGLE_MAPS_API_KEY=nexlayer-placeholder
ENV GOOGLE_PLAY_PACKAGE_NAME=nexlayer-placeholder
ENV LOG_CHANNEL=stack
ENV MAIL_MAILER=smtp
ENV MICROSOFT_CLIENT_ID=nexlayer-placeholder
ENV MICROSOFT_CLIENT_SECRET=nexlayer-placeholder
ENV MICROSOFT_REDIRECT_URI=nexlayer-placeholder
ENV MULTI_DB_ENABLED=false
ENV NINJA_ENVIRONMENT=selfhost
ENV NORDIGEN_SECRET_ID=nexlayer-placeholder
ENV NORDIGEN_SECRET_KEY=nexlayer-placeholder
ENV OPENEXCHANGE_APP_ID=nexlayer-placeholder
ENV PDF_GENERATOR=hosted_ninja
ENV PHANTOMJS_KEY=a-demo-key-with-low-quota-per-ip-address
ENV PHANTOMJS_SECRET=secret
ENV POSTMARK_API_TOKEN=nexlayer-placeholder
ENV QUEUE_CONNECTION=sync
ENV REACT_URL=http://localhost:3001
ENV REDIS_HOST=127.0.0.1
ENV REDIS_PASSWORD=null
ENV REDIS_PORT=6379
ENV REQUIRE_HTTPS=false
ENV SCOUT_DRIVER=null
ENV SESSION_DRIVER=file
ENV SESSION_LIFETIME=120
ENV TRUSTED_PROXIES=nexlayer-placeholder
ENV UPDATE_SECRET=secret

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# nginx vhost: serve /var/www/html/public on :80, FastCGI *.php to local fpm.
COPY nexlayer-docker/nginx-default.conf /etc/nginx/conf.d/default.conf
RUN rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# Add nginx as a supervised program alongside php-fpm/queue/scheduler.
COPY nexlayer-docker/nginx-supervisor.conf /etc/supervisor/conf.d/nginx.conf

# Replace the entrypoint with one that does NOT die (set -e) if the optional
# cache:clear/optimize steps fail — those are non-fatal for serving requests.
COPY --chmod=0755 nexlayer-docker/init-nexlayer.sh /usr/local/bin/init-nexlayer.sh

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/init-nexlayer.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]