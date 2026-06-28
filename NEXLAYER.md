# Nexlayer — invoiceninja

<!-- nexlayer:meta version=1 analyzed=2026-06-28T08:59:01Z repo=https://github.com/armondhonore/invoiceninja.git branch=nexlayer -->

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
Invoice Ninja is a professional self-hosted invoicing platform that allows users to manage clients, create invoices, and track payments. It is built on a Laravel backend with a Vue/React frontend.
<!-- nexlayer:end -->

## Technology Stack
<!-- nexlayer:section agent-managed=tech_stack -->
| Name | Kind | Version | Detected From |
|------|------|---------|---------------|
| PHP | language | latest | Dockerfile |
| Laravel | framework | 5.x/10.x | artisan, composer.json |
| MySQL | database | latest | .env.example |
| Nginx | infra | latest | Dockerfile |
| Vite | build | 4.5.14 | package.json |
| Redis | cache | latest | .env.example |
<!-- nexlayer:end -->

## Repository Structure
<!-- nexlayer:section agent-managed=structure_map -->
- app/ — Laravel core application logic
- bootstrap/ — Framework bootstrap files
- config/ — Application configuration files
- database/ — Migrations and seeders
- public/ — Web server root directory
- resources/ — Frontend assets and templates
- routes/ — HTTP route definitions
- storage/ — File uploads and logs
<!-- nexlayer:end -->

## External Services Required
<!-- nexlayer:section agent-managed=external_deps -->
Services that must be configured separately (not deployed by Nexlayer):

- Postmark API (POSTMARK_API_TOKEN)
- Google Maps API (GOOGLE_MAPS_API_KEY)
- PhantomJS/Hosted Ninja PDF (PHANTOMJS_KEY)
<!-- nexlayer:end -->

## Local Development Setup
<!-- nexlayer:section user-editable=local_setup -->
### Prerequisites

- PHP >= 8.1
- Composer
- Node.js >= 16
- MySQL
- Redis

### Environment variables

Copy `.env.example` to `.env.local` and fill in:

```
DB_HOST=127.0.0.1
DB_DATABASE=ninja
DB_USERNAME=ninja
DB_PASSWORD=ninja
REDIS_HOST=127.0.0.1
APP_KEY=base64:RR++yx2rJ9kdxbdh3+AmbHLDQu+Q76i++co9Y8ybbno=
```

### Steps

1. `composer install` — Install PHP dependencies
2. `npm install` — Install frontend dependencies
3. `npm run dev` — Start Vite development server
4. `php artisan migrate` — Run database migrations

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
    # IMPORTANT: this MUST be the literal pipeline placeholder so the runner
    # patches in the freshly BUILT wrapper image (FROM invoiceninja-debian +
    # baked-in nginx on :80 -> local php-fpm:9000). If a real image ref is put
    # here, the runner deploys THAT stock image instead of the built wrapper —
    # which is php-fpm-only on :9000 (no :80 listener) -> edge 502.
    image: "registry.nexlayer.io/user_01kece1xyh817dwff7wnarhkxd/invoiceninja:19f0d936b12"
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
<!-- nexlayer:end -->

## Nexlayer Deployment Plan
<!-- nexlayer:section user-editable=deployment_plan -->
### Pod Topology

| Pod | Image | Port | Role |
|-----|-------|------|------|
| app | mirror.gcr.io/invoiceninja/invoiceninja-debian:latest | 80 | web |
| mysql | mirror.gcr.io/library/mysql:8.0 | 3306 | database |
| redis | mirror.gcr.io/library/redis:alpine | 6379 | cache |

### Deployment notes

- The app pod communicates with the database via mysql.pod:3306
- The app pod communicates with the cache via redis.pod:6379
- Base image is sourced from mirror.gcr.io to comply with Nexlayer namespace rules
- PDF generation is handled externally via hosted_ninja to maintain pod lightness

<!-- nexlayer:end -->

## Build Notes
<!-- nexlayer:section user-editable=build_notes -->
<!-- Add notes for future builds here — preserved across re-analysis -->
<!-- nexlayer:end -->

## Nexlayer Configuration
<!-- nexlayer:section agent-managed=nexlayer_config -->
**Last deployed:** 2026-06-28T09:34:55Z  
**Live URL:** https://relaxed-weasel-invoiceninja.cloud.nexlayer.ai  
**Runtime:**  · **Port:** auto-detected  
**Deploy branch:** nexlayer  

```yaml
application:
  name: invoiceninja
  pods:
  - name: app
    # IMPORTANT: this MUST be the literal pipeline placeholder so the runner
    # patches in the freshly BUILT wrapper image (FROM invoiceninja-debian +
    # baked-in nginx on :80 -> local php-fpm:9000). If a real image ref is put
    # here, the runner deploys THAT stock image instead of the built wrapper —
    # which is php-fpm-only on :9000 (no :80 listener) -> edge 502.
    image: "registry.nexlayer.io/user_01kece1xyh817dwff7wnarhkxd/invoiceninja:19f0d936b12"
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
<!-- nexlayer:end -->

## Build History
<!-- nexlayer:section agent-managed=build_history -->
| Date | Status | Notes |
|------|--------|-------|
| 2026-06-28T09:33:45Z | analyzed | initial repo analysis |
| 2026-06-28T09:34:55Z | success | deployed https://relaxed-weasel-invoiceninja.cloud.nexlayer.ai |
<!-- nexlayer:end -->


