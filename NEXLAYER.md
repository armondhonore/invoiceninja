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
Invoice Ninja is a comprehensive self-hosted invoicing application providing billing, expense tracking, and client management, built with a Laravel backend and a Vue/React frontend.
<!-- nexlayer:end -->

## Technology Stack
<!-- nexlayer:section agent-managed=tech_stack -->
| Name | Kind | Version | Detected From |
|------|------|---------|---------------|
| PHP | language | 8.x | composer.json |
| Laravel | framework | v5 | README.md, artisan |
| Vue.js/React | framework | latest | package.json |
| MySQL | database | latest | .env.example |
| Redis | database | latest | .env.example |
| Vite | build | 4.5.14 | package.json |
| Composer | tool | latest | composer.json |
<!-- nexlayer:end -->

## Repository Structure
<!-- nexlayer:section agent-managed=structure_map -->
- app/ — Laravel core application logic
- bootstrap/ — Framework bootstrapping files
- config/ — Application configuration files
- database/ — Migrations and seeders
- public/ — Web root and static assets
- resources/ — Frontend Vue/React components and assets
- routes/ — API and Web route definitions
- storage/ — Application logs and cached files
<!-- nexlayer:end -->

## External Services Required
<!-- nexlayer:section agent-managed=external_deps -->
Services that must be configured separately (not deployed by Nexlayer):

- Postmark API (POSTMARK_API_TOKEN)
- Google Maps API (GOOGLE_MAPS_API_KEY)
- GoCardless API (GOCARDLESS_CLIENT_ID)
- Microsoft OAuth (MICROSOFT_CLIENT_ID)
- Apple OAuth (APPLE_CLIENT_ID)
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
| `app` | `APP_URL` | `"<% URL %>"` | plain |
| `app` | `DB_CONNECTION` | `"mysql"` | plain |
| `app` | `DB_HOST` | `"${mysql:3306}"` | inter-pod |
| `app` | `DB_PORT` | `"3306"` | plain |
| `app` | `DB_DATABASE` | `"ninja"` | plain |
| `app` | `DB_USERNAME` | `"ninja"` | plain |
| `app` | `DB_PASSWORD` | `"${MYSQL_PASSWORD}"` | inter-pod |
| `app` | `APP_KEY` | `"${APP_KEY}"` | inter-pod |
| `app` | `REDIS_HOST` | `"${redis:6379}"` | inter-pod |
| `app` | `REDIS_PORT` | `"6379"` | plain |
| `app` | `CACHE_DRIVER` | `"redis"` | plain |
| `app` | `SESSION_DRIVER` | `"redis"` | plain |
| `app` | `QUEUE_CONNECTION` | `"sync"` | plain |
| `mysql` | `MYSQL_DATABASE` | `"ninja"` | plain |
| `mysql` | `MYSQL_USER` | `"ninja"` | plain |
| `mysql` | `MYSQL_PASSWORD` | `"${MYSQL_PASSWORD}"` | inter-pod |
| `mysql` | `MYSQL_ROOT_PASSWORD` | `"${MYSQL_ROOT_PASSWORD}"` | inter-pod |
| `mysql-data` | `size` | `10Gi` | plain |
| `mysql-data` | `mountPath` | `/var/lib/mysql` | plain |

### nexlayer.yaml

```yaml
application:
  name: invoiceninja
  pods:
    - name: app
      image: "registry.nexlayer.io/user_01kece1xyh817dwff7wnarhkxd/invoiceninja:9f0d2ca-fix5"
      path: /
      servicePorts:
        - 80
      vars:
        APP_URL: "<% URL %>"
        DB_CONNECTION: "mysql"
        DB_HOST: "${mysql:3306}"
        DB_PORT: "3306"
        DB_DATABASE: "ninja"
        DB_USERNAME: "ninja"
        DB_PASSWORD: "${MYSQL_PASSWORD}"
        APP_KEY: "${APP_KEY}"
        REDIS_HOST: "${redis:6379}"
        REDIS_PORT: "6379"
        CACHE_DRIVER: "redis"
        SESSION_DRIVER: "redis"
        QUEUE_CONNECTION: "sync"
    - name: mysql
      image: mirror.gcr.io/library/mysql:8
      path: /mysql
      servicePorts:
        - 3306
      vars:
        MYSQL_DATABASE: "ninja"
        MYSQL_USER: "ninja"
        MYSQL_PASSWORD: "${MYSQL_PASSWORD}"
        MYSQL_ROOT_PASSWORD: "${MYSQL_ROOT_PASSWORD}"
      volumes:
        - name: mysql-data
          size: 10Gi
          mountPath: /var/lib/mysql
    - name: redis
      image: mirror.gcr.io/library/redis:7-alpine
      path: /redis
      servicePorts:
        - 6379
      vars: {}
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
**Last deployed:** 2026-06-28T07:55:31Z  
**Live URL:** https://relaxed-weasel-invoiceninja.cloud.nexlayer.ai  
**Runtime:**  · **Port:** auto-detected  
**Deploy branch:** nexlayer  

```yaml
application:
  name: invoiceninja
  pods:
    - name: app
      image: "registry.nexlayer.io/user_01kece1xyh817dwff7wnarhkxd/invoiceninja:9f0d2ca-fix5"
      path: /
      servicePorts:
        - 80
      vars:
        APP_URL: "<% URL %>"
        DB_CONNECTION: "mysql"
        DB_HOST: "${mysql:3306}"
        DB_PORT: "3306"
        DB_DATABASE: "ninja"
        DB_USERNAME: "ninja"
        DB_PASSWORD: "${MYSQL_PASSWORD}"
        APP_KEY: "${APP_KEY}"
        REDIS_HOST: "${redis:6379}"
        REDIS_PORT: "6379"
        CACHE_DRIVER: "redis"
        SESSION_DRIVER: "redis"
        QUEUE_CONNECTION: "sync"
    - name: mysql
      image: mirror.gcr.io/library/mysql:8
      path: /mysql
      servicePorts:
        - 3306
      vars:
        MYSQL_DATABASE: "ninja"
        MYSQL_USER: "ninja"
        MYSQL_PASSWORD: "${MYSQL_PASSWORD}"
        MYSQL_ROOT_PASSWORD: "${MYSQL_ROOT_PASSWORD}"
      volumes:
        - name: mysql-data
          size: 10Gi
          mountPath: /var/lib/mysql
    - name: redis
      image: mirror.gcr.io/library/redis:7-alpine
      path: /redis
      servicePorts:
        - 6379
      vars: {}
```
<!-- nexlayer:end -->

## Build History
<!-- nexlayer:section agent-managed=build_history -->
| Date | Status | Notes |
|------|--------|-------|
| 2026-06-28T07:41:35Z | analyzed | initial repo analysis |
| 2026-06-28T07:55:31Z | success | deployed https://relaxed-weasel-invoiceninja.cloud.nexlayer.ai |
<!-- nexlayer:end -->

