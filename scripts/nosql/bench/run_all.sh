#!/usr/bin/env bash
# Runs the LedgerMind NoSQL benchmarks E1..E5 in one private, throwaway docker network (nothing is published on the host,
# the finance-* stack is never touched). See README.md.
#
#   scripts/nosql/bench/run_all.sh            # E1 E2 E3 E4 E5
#   scripts/nosql/bench/run_all.sh E3 E4      # only these
#
# Output: JSON per experiment in docs/nosql/bench_raw/ (then: python3 docs/nosql/build/report_bench.py).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
RUN_ID="${RUN_ID:-$(date +%Y%m%d%H%M%S)}"
NET="ledgermind-bench-$RUN_ID"
LABEL="ledgermind-bench=$RUN_ID"
OUT="${OUT:-$REPO/docs/nosql/bench_raw}"
DATA="${DATA:-${TMPDIR:-/tmp}/ledgermind-bench-data-$RUN_ID}"
IMG_CLIENT="ledgermind-bench-client:1"
EXPERIMENTS=("$@")
if [ ${#EXPERIMENTS[@]} -eq 0 ]; then EXPERIMENTS=(E1 E2 E3 E4 E5); fi

mkdir -p "$OUT" "$DATA"

cleanup() {
  set +e
  docker ps -aq --filter "label=$LABEL" | xargs -r docker rm -f >/dev/null 2>&1
  docker network rm "$NET" >/dev/null 2>&1
  echo "teardown: containers with label $LABEL removed, network $NET removed"
}
trap cleanup EXIT

echo "== host"
{
  echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "cpu: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //')"
  echo "cpus: $(nproc)"
  echo "mem: $(grep MemTotal /proc/meminfo | sed 's/  */ /g')"
  echo "kernel: $(uname -r)"
  echo "docker: $(docker version --format '{{.Server.Version}}')"
  for img in mongo:6.0 redis:8.10-alpine elasticsearch:8.11.4 postgres:15-alpine; do
    echo "image $img: $(docker image inspect --format '{{.Id}}' "$img")"
  done
} | tee "$OUT/host.txt"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) scripts/nosql/bench/run_all.sh ${EXPERIMENTS[*]}" >> "$OUT/runs.log"

echo "== data (seed 42)"
python3 -I "$HERE/gen_data.py" "$DATA" | tee "$OUT/data_manifest.txt"
cp "$DATA/MANIFEST.sha256" "$OUT/MANIFEST.sha256"

echo "== client image"
docker build -q -t "$IMG_CLIENT" "$HERE" >/dev/null

docker network create --label "$LABEL" "$NET" >/dev/null

start_mongo() {
  docker run -d --label "$LABEL" --network "$NET" --network-alias bench-mongo --name "bench-mongo-$RUN_ID" \
    --memory 512m mongo:6.0 --wiredTigerCacheSizeGB 0.25 >/dev/null
}
start_redis() {
  docker run -d --label "$LABEL" --network "$NET" --network-alias bench-redis --name "bench-redis-$RUN_ID" \
    --memory 192m redis:8.10-alpine redis-server --maxmemory 128mb --maxmemory-policy allkeys-lru --save '' --appendonly no >/dev/null
}
start_es() {
  docker run -d --label "$LABEL" --network "$NET" --network-alias bench-es --name "bench-es-$RUN_ID" \
    --memory 1g -e discovery.type=single-node -e xpack.security.enabled=false -e ES_JAVA_OPTS="-Xms512m -Xmx512m" \
    -e action.auto_create_index=false elasticsearch:8.11.4 >/dev/null
}
start_pg() {
  docker run -d --label "$LABEL" --network "$NET" --network-alias bench-pg --name "bench-pg-$RUN_ID" \
    -e POSTGRES_USER=bench -e POSTGRES_PASSWORD=bench -e POSTGRES_DB=bench postgres:15-alpine >/dev/null
}
stop_servers() {
  docker ps -aq --filter "label=$LABEL" --filter "name=bench-" | xargs -r docker rm -f >/dev/null
}
client() {  # client SCRIPT
  docker run --rm --label "$LABEL" --network "$NET" --user "$(id -u):$(id -g)" -e BENCH_WARMUP -e BENCH_ITERATIONS \
    -v "$HERE:/bench:ro" -v "$DATA:/data:ro" -v "$OUT:/results" \
    -v "$REPO/core-backend/src/main/resources/elasticsearch:/es_conf:ro" \
    "$IMG_CLIENT" python "/bench/$1"
}

for e in "${EXPERIMENTS[@]}"; do
  echo "=================== $e"
  case "$e" in
    E1) start_mongo; client bench_e1_mongo.py ;;
    E2) start_pg; start_es; client bench_e2_search.py ;;
    E3) start_pg; start_redis; client bench_e3_leaderboard.py ;;
    E4) start_pg; start_redis; client bench_e4_cache.py ;;
    E5) start_mongo; client bench_e5_embed.py ;;
    *) echo "unknown experiment $e"; exit 2 ;;
  esac
  stop_servers
done
