# Single-pod Invoice Ninja for Nexlayer.
#
# The upstream invoiceninja/invoiceninja-debian image is php-fpm ONLY (listens
# on :9000, no web server). The official deployment pairs it with a separate
# nginx container that serves :80 and proxies *.php to php-fpm:9000 (see the
# project's docker-compose). Nexlayer maps the public edge to a single
# containerPort, so we bake nginx INTO the image here and serve :80 in-pod,
# proxying PHP to 127.0.0.1:9000. This is the only way to get a real HTTP
# listener on the mapped port within Nexlayer's one-service-per-pod model.
FROM invoiceninja/invoiceninja-debian:latest

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
