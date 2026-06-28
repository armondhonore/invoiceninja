# Nexlayer — invoiceninja

<!-- nexlayer:meta version=1 analyzed=2026-06-28T04:37:20Z repo=https://github.com/armondhonore/invoiceninja branch=v5-stable -->

> **For AI agents (Claude Code, Cursor, Gemini CLI, Copilot):**
> This file is the **project context** for this Nexlayer deployment — tech stack, env vars, secrets, live URL.
> For full platform detail (nexlayer.yaml schema, Dockerfile rules, CI/CD, task recipes) read **`nexlayer.skills`** in this repo.
>
> **Critical rules (full detail in `nexlayer.skills`):**
> - Inter-pod refs: `${podName:port}` only — never `localhost` or bare hostnames
> - Docker Hub images: prefix with `mirror.gcr.io/library/` — bare tags fail on the cluster
> - Secrets: set in the Nexlayer dashboard — never commit to `nexlayer.yaml` or Dockerfile
>
> **This file:** `agent-managed` sections update automatically. `user-editable` sections (Local Development Setup, Nexlayer Deployment Plan, Build Notes) are yours — preserved across re-analysis.

## Project Summary
<!-- nexlayer:section agent-managed=project_summary -->
Invoice Ninja is a professional invoicing platform that allows users to manage clients, create invoices, and track payments. It utilizes a Laravel backend and a Vue.js frontend to provide comprehensive billing and business management tools.
<!-- nexlayer:end -->

## Technology Stack
<!-- nexlayer:section agent-managed=tech_stack -->
| Name | Kind | Version | Detected From |
|------|------|---------|---------------|
| PHP | language | 8.x | composer.json, artisan |
| Laravel | framework | unknown | artisan, composer.json |
| Vue.js | framework | 2.7.16 | package.json |
| Vite | build | 4.5.14 | package.json, vite.config.ts |
| MySQL | database | unknown | .env.example |
| Redis | database | unknown | .env.example |
<!-- nexlayer:end -->

## Repository Structure
<!-- nexlayer:section agent-managed=structure_map -->
- app/ — Laravel core application logic
- bootstrap/ — Framework bootstrapper
- config/ — Application configuration files
- database/ — Migrations and seeds
- public/ — Web server entry point and static assets
- resources/ — Vue.js frontend source and Laravel blade templates
- routes/ — API and Web route definitions
- storage/ — File uploads and application logs
<!-- nexlayer:end -->

## External Services Required
<!-- nexlayer:section agent-managed=external_deps -->
Services that must be configured separately (not deployed by Nexlayer):

- Postmark API (POSTMARK_API_TOKEN)
- Google Maps API (GOOGLE_MAPS_API_KEY)
- GoCardless (GOCARDLESS_CLIENT_ID)
- Microsoft OAuth (MICROSOFT_CLIENT_ID)
<!-- nexlayer:end -->

## Local Development Setup
<!-- nexlayer:section user-editable=local_setup -->
### Prerequisites

- PHP >= 8.1
- Composer
- Node.js >= 16
- npm
- MySQL

### Environment variables

Copy `.env.example` to `.env.local` and fill in:

```
DB_HOST=127.0.0.1
DB_DATABASE=ninja
DB_USERNAME=ninja
DB_PASSWORD=ninja
APP_KEY=base64:RR++yx2rJ9kdxbdh3+AmbHLDQu+Q76i++co9Y8ybbno=
```

### Steps

1. `composer install` — Install PHP dependencies
2. `npm install && npm run build` — Install JS dependencies and build assets
3. `php artisan migrate` — Run database migrations
4. `php artisan serve` — Start local PHP development server

<!-- nexlayer:end -->

## Nexlayer Setup
<!-- nexlayer:section agent-managed=nexlayer_setup -->
### Pod Environment Variables

| Pod | Variable | Value | Kind |
|-----|----------|-------|------|
| `app` | `APP_ENV` | `production` | plain |
| `app` | `APP_KEY` | `"base64:WM83G829MpixFnAxuqx7QkdFPr/9/kkHB1QVNaYn1u0="` | plain |
| `app` | `APP_URL` | `"https://relaxed-weasel-invoiceninja.cloud.nexlayer.ai"` | plain |
| `app` | `DB_HOST` | `mysql.pod` | plain |
| `app` | `DB_PORT` | `"3306"` | plain |
| `app` | `DB_DATABASE` | `invoiceninja` | plain |
| `app` | `DB_USERNAME` | `invoiceninja` | plain |
| `app` | `DB_PASSWORD` | `"${MYSQL_PASSWORD}"` | inter-pod |
| `app` | `REQUIRE_HTTPS` | `"true"` | plain |
| `app` | `IS_DOCKER` | `"true"` | plain |
| `app` | `TRUSTED_PROXIES` | `"*"` | plain |
| `app` | `CACHE_DRIVER` | `file` | plain |
| `app` | `SESSION_DRIVER` | `file` | plain |
| `app` | `QUEUE_CONNECTION` | `sync` | plain |
| `app` | `LOG_CHANNEL` | `stderr` | plain |
| `app` | `IN_USER_EMAIL` | `"admin@example.com"` | plain |
| `app` | `IN_PASSWORD` | _(set via Nexlayer dashboard)_ | secret |
| `invoiceninja-storage` | `mountPath` | `/var/www/html/storage` | plain |
| `invoiceninja-storage` | `size` | `5Gi` | plain |
| `mysql` | `MYSQL_DATABASE` | `invoiceninja` | plain |
| `mysql` | `MYSQL_USER` | `invoiceninja` | plain |
| `mysql` | `MYSQL_PASSWORD` | `"${MYSQL_PASSWORD}"` | inter-pod |
| `mysql` | `MYSQL_ROOT_PASSWORD` | `"${MYSQL_ROOT_PASSWORD}"` | inter-pod |
| `invoiceninja-db` | `mountPath` | `/var/lib/mysql` | plain |
| `invoiceninja-db` | `size` | `5Gi` | plain |

### Secrets Required

Set these in the Nexlayer dashboard before deploying:

- `IN_PASSWORD` (`app` pod)

### nexlayer.yaml

```yaml
application:
  name: invoiceninja
  pods:
  - name: app
    # Built from the repo-root Dockerfile (FROM invoiceninja/invoiceninja-debian
    # + baked-in nginx serving :80, proxying *.php to local php-fpm:9000). The
    # stock invoiceninja-debian image is php-fpm ONLY on :9000 with NO web
    # server, so mapping :80 to it yields an edge 502. The wrapper image adds the
    # HTTP listener the platform's single-port edge needs. The pipeline replaces
    # this image ref with the freshly built image.
    image: mirror.gcr.io/invoiceninja/invoiceninja-debian:latest
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
    volumes:
    # Persist Laravel storage. Safe to mount now: the wrapper entrypoint runs
    # `chown -R www-data:www-data` on storage (as root, before dropping to
    # www-data) on every boot, so an empty/root-owned PVC is made writable and
    # the cache:clear step no longer dies. (cache:clear is also non-fatal now.)
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
<!-- nexlayer:end -->

## Nexlayer Deployment Plan
<!-- nexlayer:section user-editable=deployment_plan -->
### Pod Topology

| Pod | Image | Port | Role |
|-----|-------|------|------|
| app | mirror.gcr.io/library/php:8.2-fpm-alpine | 9000 | web |
| web | mirror.gcr.io/library/nginx:alpine | 80 | web |
| mysql | mirror.gcr.io/library/mysql:8.0 | 3306 | database |
| redis | mirror.gcr.io/library/redis:alpine | 6379 | cache |
| worker | mirror.gcr.io/library/php:8.2-cli-alpine | 0 | worker |

### Deployment notes

- Application connects to MySQL via mysql.pod:3306
- Application connects to Redis via redis.pod:6379
- The Nginx 'web' pod acts as the ingress and proxies requests to the 'app' PHP-FPM pod via app.pod:9000
- A separate 'worker' pod is required to handle Laravel queue jobs (QUEUE_CONNECTION)

<!-- nexlayer:end -->

## Build Notes
<!-- nexlayer:section user-editable=build_notes -->
<!-- Add notes for future builds here — preserved across re-analysis -->
<!-- nexlayer:end -->

## Nexlayer Configuration
<!-- nexlayer:section agent-managed=nexlayer_config -->
**Last deployed:** 2026-06-28T08:30:07Z  
**Live URL:** https://relaxed-weasel-invoiceninja.cloud.nexlayer.ai  
**Runtime:**  · **Port:** auto-detected  
**Deploy branch:** nexlayer  

```yaml
application:
  name: invoiceninja
  pods:
  - name: app
    # Built from the repo-root Dockerfile (FROM invoiceninja/invoiceninja-debian
    # + baked-in nginx serving :80, proxying *.php to local php-fpm:9000). The
    # stock invoiceninja-debian image is php-fpm ONLY on :9000 with NO web
    # server, so mapping :80 to it yields an edge 502. The wrapper image adds the
    # HTTP listener the platform's single-port edge needs. The pipeline replaces
    # this image ref with the freshly built image.
    image: mirror.gcr.io/invoiceninja/invoiceninja-debian:latest
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
    volumes:
    # Persist Laravel storage. Safe to mount now: the wrapper entrypoint runs
    # `chown -R www-data:www-data` on storage (as root, before dropping to
    # www-data) on every boot, so an empty/root-owned PVC is made writable and
    # the cache:clear step no longer dies. (cache:clear is also non-fatal now.)
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
<!-- nexlayer:end -->

## Build History
<!-- nexlayer:section agent-managed=build_history -->
| Date | Status | Notes |
|------|--------|-------|
| 2026-06-28T08:22:31Z | analyzed | initial repo analysis |
| 2026-06-28T08:30:07Z | success | deployed https://relaxed-weasel-invoiceninja.cloud.nexlayer.ai |
<!-- nexlayer:end -->


