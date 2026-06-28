# Nexlayer fix guidance (pinned — do not regenerate)

The repo-root `Dockerfile` is hand-authored and MUST NOT be regenerated. It is a
thin wrapper over `invoiceninja/invoiceninja-debian:latest` that bakes in nginx
to serve HTTP on :80 (proxying *.php to local php-fpm:9000). The stock image is
php-fpm-only on :9000 with no web server, so a regenerated/guessed Dockerfile
will break the :80 edge and produce a 502.

Keep the `Dockerfile`, `nexlayer-docker/nginx-default.conf`,
`nexlayer-docker/nginx-supervisor.conf`, and `nexlayer-docker/init-nexlayer.sh`
exactly as committed. Do not regenerate the Dockerfile. Pinned.
