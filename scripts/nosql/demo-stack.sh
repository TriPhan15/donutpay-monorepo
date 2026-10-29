#!/usr/bin/env bash
# Demo stack of the NoSQL report: MongoDB + Redis + Elasticsearch (security on) + Kibana + Elasticvue + RedisInsight,
# loaded with the demo data of scripts/nosql. Project "nosql-demo", ports on 127.0.0.1 only. See demo-stack.README.md.
#
#   scripts/nosql/demo-stack.sh up       start everything, set the kibana_system password, load the demo data
#   scripts/nosql/demo-stack.sh load     load the demo data again (Mongo demo DB, Redis keys, ES index "transactions")
#   scripts/nosql/demo-stack.sh status   containers, ports and docker stats
#   scripts/nosql/demo-stack.sh info     URLs and logins
#   scripts/nosql/demo-stack.sh down     stop and delete containers, network AND volumes of the demo stack
#
# Ports and passwords can be changed with the NOSQL_DEMO_* variables listed in demo-stack.compose.yml.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE=(docker compose -p nosql-demo -f "$HERE/demo-stack.compose.yml")

export NOSQL_DEMO_MONGO_PORT="${NOSQL_DEMO_MONGO_PORT:-27018}"
export NOSQL_DEMO_REDIS_PORT="${NOSQL_DEMO_REDIS_PORT:-6380}"
export NOSQL_DEMO_ES_PORT="${NOSQL_DEMO_ES_PORT:-9201}"
export NOSQL_DEMO_KIBANA_PORT="${NOSQL_DEMO_KIBANA_PORT:-5602}"
export NOSQL_DEMO_ELASTICVUE_PORT="${NOSQL_DEMO_ELASTICVUE_PORT:-8081}"
export NOSQL_DEMO_REDISINSIGHT_PORT="${NOSQL_DEMO_REDISINSIGHT_PORT:-5541}"
export NOSQL_DEMO_MONGO_USER="${NOSQL_DEMO_MONGO_USER:-root}"
export NOSQL_DEMO_MONGO_PASSWORD="${NOSQL_DEMO_MONGO_PASSWORD:-demo-mongo-pass}"
export NOSQL_DEMO_REDIS_PASSWORD="${NOSQL_DEMO_REDIS_PASSWORD:-demo-redis-pass}"
export NOSQL_DEMO_ELASTIC_PASSWORD="${NOSQL_DEMO_ELASTIC_PASSWORD:-demo-elastic-pass}"
export NOSQL_DEMO_KIBANA_PASSWORD="${NOSQL_DEMO_KIBANA_PASSWORD:-demo-kibana-pass}"

log() { printf '\n==> %s\n' "$*"; }

wait_healthy() { # container, timeout seconds
  local name="$1" left="${2:-180}"
  until [ "$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null)" = "healthy" ]; do
    left=$((left - 3))
    if [ "$left" -le 0 ]; then echo "$name is not healthy" >&2; docker logs --tail 30 "$name" >&2; exit 1; fi
    sleep 3
  done
  echo "$name: healthy"
}

wait_http() { # url, timeout seconds (any HTTP answer below 500 counts)
  local url="$1" left="${2:-240}" code
  while :; do
    code="$(curl -s -o /dev/null -w '%{http_code}' "$url" || true)"
    if [ "$code" != "000" ] && [ "$code" -lt 500 ]; then echo "$url: HTTP $code"; return; fi
    left=$((left - 3))
    if [ "$left" -le 0 ]; then echo "$url does not answer" >&2; exit 1; fi
    sleep 3
  done
}

mongosh_demo() { # args for mongosh, run inside the Mongo container from /s
  "${COMPOSE[@]}" exec -T -w /s mongo mongosh -u "$NOSQL_DEMO_MONGO_USER" -p "$NOSQL_DEMO_MONGO_PASSWORD" \
    --authenticationDatabase admin --quiet "$@"
}

es_curl() { # args for curl, run inside the Elasticsearch container
  "${COMPOSE[@]}" exec -T elasticsearch curl -s -u "elastic:$NOSQL_DEMO_ELASTIC_PASSWORD" "$@"
}

load_data() {
  log "MongoDB: schema of finance_nosql (idempotent) + demo database finance_nosql_demo (36 + 36 documents)"
  mongosh_demo mongodb_init.js >/dev/null
  mongosh_demo mongodb_demo.js >/dev/null
  mongosh_demo --eval 'const d=db.getSiblingDB("finance_nosql_demo"); printjson({ocr_logs:d.ocr_logs.countDocuments(), ocr_feedbacks:d.ocr_feedbacks.countDocuments()})'

  log "Redis: redis_demo.txt (Q-17..Q-29, Q-41), then keys left to look at in RedisInsight"
  "${COMPOSE[@]}" exec -T redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli < /s/redis_demo.txt' >/dev/null
  # redis_demo.txt deletes its leaderboards at the end (Q-28): put back one month and one OTP so that every key type
  # of the app (String cache, Hash OTP, Sorted Set leaderboard) can be seen in RedisInsight. The OTP expires after 5 min.
  "${COMPOSE[@]}" exec -T redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli' >/dev/null <<'REDIS'
ZADD "ledgermind:leaderboard:spend:2026-10" 4200000 1 6850000 2 1250000 3 9100000 4 3300000 5
EXPIRE "ledgermind:leaderboard:spend:2026-10" 5356800
HSET "ledgermind:password-reset-otp:sv01@huit.edu.vn" code 482931 expiresAt 4102444800000
PEXPIRE "ledgermind:password-reset-otp:sv01@huit.edu.vn" 300000
REDIS
  "${COMPOSE[@]}" exec -T redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli DBSIZE'

  log "Elasticsearch: index transactions from the app's settings + mapping, then 47 demo documents"
  es_curl -o /dev/null -X DELETE "localhost:9200/transactions?ignore_unavailable=true"
  "${COMPOSE[@]}" exec -T elasticsearch sh -c '
    printf "{\"settings\":%s,\"mappings\":%s}" "$(cat /app-es/transactions-settings.json)" "$(cat /app-es/transactions-mapping.json)" |
    curl -s -u "elastic:$ELASTIC_PASSWORD" -X PUT localhost:9200/transactions -H "Content-Type: application/json" --data-binary @-'
  echo
  es_curl "localhost:9200/_bulk?refresh=true&filter_path=errors" -H "Content-Type: application/x-ndjson" \
    --data-binary @/s-es/transactions-bulk.ndjson
  echo
  es_curl "localhost:9200/transactions/_count"
  echo
}

set_kibana_password() {
  log "Elasticsearch: password of kibana_system (security API, as user elastic), then Kibana starts with it"
  # Not bin/elasticsearch-reset-password: that tool starts a second JVM inside the Elasticsearch container, which already
  # uses about 990 MiB at a 1G limit; on 2026-10-28 it got Elasticsearch OOM-killed
  # (exit 137) twice, even with a 48 MB heap for the tool. The API call below is the way Elastic's own compose example
  # sets this password.
  local answer
  answer="$(es_curl -X POST localhost:9200/_security/user/kibana_system/_password -H "Content-Type: application/json" \
    -d "{\"password\":\"$NOSQL_DEMO_KIBANA_PASSWORD\"}")"
  if [ "$answer" != "{}" ]; then echo "could not set the kibana_system password: $answer" >&2; exit 1; fi
  echo "kibana_system password set"
}

info() {
  cat <<INFO

Demo stack "nosql-demo" (127.0.0.1 only):
  MongoDB      mongodb://$NOSQL_DEMO_MONGO_USER:$NOSQL_DEMO_MONGO_PASSWORD@127.0.0.1:$NOSQL_DEMO_MONGO_PORT/?authSource=admin   (Compass)
  Redis        127.0.0.1:$NOSQL_DEMO_REDIS_PORT, password $NOSQL_DEMO_REDIS_PASSWORD
  RedisInsight http://localhost:$NOSQL_DEMO_REDISINSIGHT_PORT   (database "nosql-demo-redis" already added)
  Elasticsearch http://localhost:$NOSQL_DEMO_ES_PORT, user elastic / $NOSQL_DEMO_ELASTIC_PASSWORD
  Kibana       http://localhost:$NOSQL_DEMO_KIBANA_PORT, user elastic / $NOSQL_DEMO_ELASTIC_PASSWORD
  Elasticvue   http://localhost:$NOSQL_DEMO_ELASTICVUE_PORT   (cluster "nosql-demo" already added)
INFO
}

case "${1:-}" in
  up)
    log "Starting MongoDB, Redis, Elasticsearch, Elasticvue, RedisInsight"
    "${COMPOSE[@]}" up -d mongo redis elasticsearch elasticvue redisinsight
    wait_healthy nosql-demo-mongo 120
    wait_healthy nosql-demo-redis 60
    wait_healthy nosql-demo-es 240
    # A new named volume is owned by root, and Elasticsearch (uid 1000) then fails every snapshot with
    # access_denied_exception (docker-compose.yml does the same in its elasticsearch-init-snapshots service).
    "${COMPOSE[@]}" exec -T -u 0 elasticsearch chown 1000:0 /usr/share/elasticsearch/snapshots
    set_kibana_password
    "${COMPOSE[@]}" --profile kibana up -d kibana
    load_data
    log "Waiting for Kibana (1-2 minutes on the first start)"
    wait_http "http://127.0.0.1:$NOSQL_DEMO_KIBANA_PORT/api/status" 300
    info
    ;;
  load) load_data ;;
  status)
    "${COMPOSE[@]}" --profile kibana ps
    docker stats --no-stream nosql-demo-mongo nosql-demo-redis nosql-demo-es nosql-demo-kibana nosql-demo-elasticvue \
      nosql-demo-redisinsight 2>/dev/null || true
    ;;
  info) info ;;
  down)
    "${COMPOSE[@]}" --profile kibana down -v --remove-orphans
    ;;
  *)
    sed -n '2,10p' "$0"
    exit 2
    ;;
esac
