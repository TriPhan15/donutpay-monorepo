# LedgerMind - Personal Finance Management System

## 1. Project Overview
**LedgerMind** is a personal finance management system built to automate 
expense tracking. It combines a Java Spring Boot backend, a Flutter 
mobile app, and a Python-based OCR service to extract and categorize 
expense data from receipts automatically.

## 2. Tech Stack & Infrastructure
This project uses a **Monorepo** structure, with the backend, mobile 
app, and AI service developed and deployed as separate components.

### Core Backend
- **Framework:** Spring Boot 3.x (Spring Web, Spring Security, Spring Data JPA)
- **Language:** Java 21 (JDK 21)
- **Authentication:** OAuth2 login via Google (Facebook OAuth in progress), JWT-based session handling
- **Database:** PostgreSQL 15, self-hosted in Docker on the same VPS as the backend and the AI service (see [Database](#6-database-postgresql-on-the-vps)), accessed via Hibernate ORM
- **Optimization:** JVM memory tuning (`-XX:MaxRAMPercentage=75.0`), dedicated `prod` Spring profile

### AI Service
- **Purpose:** Automated Vietnamese receipt OCR and data extraction
- **Model:** Fine-tuned Donut (Document Understanding Transformer) model, 
  trained on 1,500 labeled receipts (1,300 from OCR2021 + 200 self-collected)
- **Pipeline:** Python/FastAPI service exposing the model via API; 
  extracted text is cleaned and normalized with regex-based post-processing 
  before being sent to the backend

### Mobile App (Frontend)
- **Framework:** Flutter (Dart)
- **Features:** Secure token storage, real-time API communication over HTTPS
- **Distribution:** APK released via GitHub Releases

### DevOps & Deployment
- **Containerization:** Docker & Docker Compose, multi-stage builds using `eclipse-temurin:21-jre-jammy` and `alpine` base images
- **Process Management:** `tini` as PID 1 for proper signal handling in containers
- **Security & Ops:** Non-root user execution (`spring:spring`), Spring Boot Actuator healthcheck endpoint, timezone synchronization (`Asia/Ho_Chi_Minh`)
- **Infrastructure:** Deployed on a Linux VPS (AWS EC2 in [the deploy guide](docs/deploy/DEPLOY_GUIDE.md)) behind a Caddy reverse proxy (`deploy/caddy/Caddyfile`) that obtains and renews the HTTPS certificate for the domain set in `SITE_ADDRESS`, adds security headers and limits request bodies (16 MB for `/ai/*`, 50 MB otherwise)
- **CI/CD:** GitHub Actions (`.github/workflows/ci.yml`) runs the backend, mobile and AI tests on every push and pull request to `main`, deploys `main` to the VPS over SSH, and builds the signed APK for `v*` tags

## 3. Key Features
- **OAuth2 + JWT Authentication:** Google login integrated at the backend, with JWT used for session/API security
- **Automated Receipt Processing:** Fine-tuned OCR model extracts and structures expense data from receipt images, reducing manual entry
- **Containerized Deployment:** Backend, AI service, PostgreSQL, Redis and MongoDB run as separate Dockerized services; only the Caddy proxy is reachable from the Internet (ports 80/443)
- **Resource-Aware Backend:** JVM memory limits and healthcheck endpoints configured to run reliably on a constrained VPS

## 4. System Architecture
**Data Flow:**
1. **Client Layer:** Flutter app sends authentication and financial data requests.
2. **Proxy Layer:** Caddy receives HTTPS traffic: `/ai/*` goes to the AI service (`/ai/donut/*` and `/ai/spade/*` only with a valid access token, checked by the backend), everything else to the backend. The backend (8080) and the AI service (8000) have no host port.
3. **Core Layer:** Java Spring Boot backend handles business logic, validates OAuth2/JWT, and manages the PostgreSQL database.
4. **AI Layer:** Receipt images are forwarded to the Python OCR service; results are post-processed and returned to the backend for storage.

## 5. Getting Started

### Prerequisites
- [Docker](https://www.docker.com/get-started) & Docker Compose
- Java JDK 21 and Maven (for local backend development)
- Flutter SDK (for local mobile development)
- Python 3.10 (for local AI service development, same version as the Docker image and CI)

### Quick Start
1. **Clone the repository:**
```bash
   git clone https://github.com/TriPhan15/donutpay-monorepo.git
   cd donutpay-monorepo
```
2. **Configure environment variables:**
   Create a `.env` file in the root directory with your Google OAuth 
   client ID, database credentials, and other required config.
   The AI service also needs the Donut weights in `ai-service/Version5/donut_result/` (not in git, see the deploy guide).
3. **Deploy the stack:**
```bash
   docker compose up -d --build --wait
```
4. **Verify deployment** (on a dev machine `SITE_ADDRESS` is empty, so the proxy serves plain HTTP on port 80):
```bash
   curl -f http://localhost/actuator/health
   curl -f http://localhost/ai/health
```

### Running the tests
`make check` runs the three suites in turn, the same commands as CI:
```bash
   cd ai-service && python3.10 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt   # once
   make check
```
- **AI service:** `pytest test_*.py` in `ai-service/` (`requirements.txt` holds the pinned runtime packages, `requirements-dev.txt` adds the test tools).
- **Backend:** `mvn -B clean test -Dtest=!CoreBackendApplicationTests` in `core-backend/` (Testcontainers tests need Docker and are skipped without it).
- **Mobile:** `flutter test` in `mobile-app/` (CI also runs `flutter analyze`).

API collections and load tests are described in [docs/testing/README.md](docs/testing/README.md).

## 6. Database (PostgreSQL on the VPS)
PostgreSQL runs as the `db` service of `docker-compose.yml` (`postgres:15-alpine`) on the same VPS as the backend and
the AI service. No cloud-hosted database is used.

- **Network:** the backend reaches it over the internal Docker network `finance-network` as
  `jdbc:postgresql://db:5432/finance_db` (set in `docker-compose.yml`; never `localhost` from inside a container).
  The host port is bound to `127.0.0.1:5432` only, so the database is not reachable from the Internet; use SSH on
  the VPS for admin work.
- **Persistence:** the data lives in the named volume `postgres_data` and survives rebuilds and restarts.
  Never run `docker compose down -v`: it deletes the volume and every row with it.
- **Credentials:** `DB_USERNAME` and `DB_PASSWORD` come from the `.env` file on the VPS (git-ignored) or from your
  secret store. Never commit real credentials.
- **Schema changes:** there is no Flyway/Liquibase. Hibernate runs with `ddl-auto: update`, and manual SQL
  migrations are applied by hand (take a backup first):
```bash
   docker compose exec -T db psql -U "$DB_USERNAME" -d finance_db -v ON_ERROR_STOP=1 < migration.sql
```

### Health checks
```bash
   docker compose ps                                             # db, redis and core-api should be "healthy"
   docker compose exec db pg_isready -U "$DB_USERNAME" -d finance_db
   curl -f http://localhost/actuator/health                     # through the proxy; use https://<domain> on the VPS
```

### Backup and restore (manual)
Take a backup before every deployment that changes the schema, and copy it off the VPS.
```bash
   # Backup (custom format, compressed)
   docker compose exec -T db pg_dump -U "$DB_USERNAME" -d finance_db -Fc > "finance_db_$(date +%F_%H%M).dump"

   # Restore into the running database: this OVERWRITES the objects in the dump, so stop core-api first
   docker compose stop core-api
   docker compose exec -T db pg_restore -U "$DB_USERNAME" -d finance_db --clean --if-exists < finance_db_YYYY-MM-DD_HHMM.dump
   docker compose restart redis   # empties the statistics cache, which must not outlive the data it was computed from
   docker compose start core-api
```

## 7. Statistics cache (Redis)
The statistics endpoints (the app's home page `GET /api/transactions/app-dashboard`, `GET /api/transactions/popular-vendors`,
their `/api/admin/transactions/...` variants and the admin dashboard page) are cached in Redis, the `redis` service of
`docker-compose.yml` (`redis:8.10-alpine`), which every core-api instance shares. PostgreSQL stays the source of truth:
when Redis is down or slow, requests read PostgreSQL directly and nothing fails.

- **Network & security:** no port is published, not even on `127.0.0.1`; only the containers of `finance-network` reach
  Redis, with the password `REDIS_PASSWORD`. `KEYS`, `FLUSHALL` and `FLUSHDB` are disabled, nothing is persisted (a
  restart starts empty) and memory is capped (`maxmemory` with `allkeys-lru`, plus a container limit). Tokens,
  passwords and OTPs are never cached.
- **Keys:** `<CACHE_KEY_PREFIX>:v1:<cache>:<key>`, e.g. `ledgermind:prod:v1:user-dashboard:42` or
  `ledgermind:prod:v1:admin-top-spenders:0:5`. The `v1` is raised in the code whenever a cached DTO changes shape.
- **Invalidation:** every write that changes a cached figure (transactions, receipts, accounts, a restore from the admin
  page) evicts the affected entries once its database transaction has committed; the TTLs bound anything else.

| Variable | Default | Meaning |
|---|---|---|
| `REDIS_PASSWORD` | *(required)* | Password of the `redis` service; `docker compose` refuses to start without it. Generate one with `openssl rand -hex 32`. |
| `REDIS_MAXMEMORY` / `REDIS_MEMORY_LIMIT` | `128mb` / `192M` | Cap of the Redis dataset / memory limit of its container (keep the limit about 1.5 x the cap). |
| `REDIS_CONNECT_TIMEOUT` / `REDIS_COMMAND_TIMEOUT` | `1s` / `500ms` | The most Redis can delay a request before the database is read instead. |
| `CACHE_KEY_PREFIX` | `ledgermind:<active Spring profile>` | Application and environment part of every key; staging and production must differ if they ever share a Redis. |
| `CACHE_TTL_USER_DASHBOARD` | `45s` | Home page of one user. |
| `CACHE_TTL_USER_POPULAR_VENDORS` | `60s` | Popular vendors of one user. |
| `CACHE_TTL_ADMIN_DASHBOARD_SUMMARY` | `45s` | Total volume, user count, low-balance list, receipt statuses. |
| `CACHE_TTL_ADMIN_TOP_SPENDERS` | `60s` | Top spenders. |
| `CACHE_TTL_ADMIN_STATISTICS` | `60s` | Six-month transaction chart. |
| `CACHE_TTL_JITTER_PERCENT` | `10` | An entry lives between (100 - jitter) % and 100 % of its TTL, so entries do not all expire together. |

`REDIS_HOST` (`redis`) and `REDIS_PORT` (`6379`) are set by `docker-compose.yml`; outside Docker they default to
`localhost:6379`.
```bash
   docker compose exec redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli INFO stats'   # keyspace_hits, keyspace_misses, evicted_keys
   docker compose exec redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli INFO memory'  # used_memory_human, maxmemory_human
   docker compose exec redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli --latency'    # round-trip latency, Ctrl+C to stop
   docker compose restart redis                                                             # empties every cache
```
