#!/usr/bin/env bash
# Chạy TRÊN SERVER (root, qua SSM Run Command hoặc az vm run-command) sau khi repo đã được reset về đúng commit.
# Build image mới trong khi bản cũ vẫn chạy, đổi container, chờ healthcheck, in log khi lỗi.
# Output giữ ngắn vì SSM chỉ trả về khoảng 24 000 ký tự đầu: log build đầy đủ nằm ở $BUILD_LOG trên server.
set -euo pipefail

readonly APP_DIR="${1:?Cách dùng: server-deploy.sh <thư mục repo>}"
readonly BUILD_LOG=/var/log/ledgermind-build.log
readonly WAIT_TIMEOUT_SECONDS=600
readonly LOG_TAIL_LINES=80
readonly BUILD_CACHE_KEEP=168h   # 7 ngày: lần build sau không phải tải lại torch và thư viện Maven

cd "$APP_DIR"

# 1. Cấu hình bắt buộc (bị .gitignore nên reset --hard không đụng tới).
[ -f .env ] || { echo "Lỗi: không tìm thấy .env trong $APP_DIR"; exit 1; }
# core-api ở profile prod dừng ngay nếu thiếu JWT_SECRET: báo sớm thay vì đợi healthcheck hết giờ.
grep -qE '^JWT_SECRET=.{32,}' .env || { echo "Lỗi: .env thiếu JWT_SECRET (ít nhất 32 ký tự)"; exit 1; }
# Model bị .gitignore chặn nên phải chép tay lên server một lần (DEPLOY_GUIDE mục 5).
[ -s ai-service/Version5/donut_result/model.safetensors ] || { echo "Lỗi: thiếu model.safetensors"; exit 1; }

# Script chạy bằng root trong repo của user thường: Git từ chối ("dubious ownership") nếu không khai báo safe.directory.
echo "Deploy commit $(git -c safe.directory="$APP_DIR" log --oneline -1)"

# 2. Build image mới (log đầy đủ vào file, chỉ in phần cuối khi lỗi).
echo "Build image mới (log: $BUILD_LOG)..."
if ! DOCKER_BUILDKIT=1 docker compose build --progress=plain >"$BUILD_LOG" 2>&1; then
  tail -n "$LOG_TAIL_LINES" "$BUILD_LOG"
  exit 1
fi

# 3. Đổi container và chờ mọi service qua healthcheck.
echo "Đổi container và chờ healthcheck..."
if ! docker compose up -d --wait --wait-timeout "$WAIT_TIMEOUT_SECONDS" --remove-orphans; then
  docker compose ps
  docker compose logs --tail="$LOG_TAIL_LINES" core-api data-mining-api proxy
  exit 1
fi
docker compose ps

# 4. Dọn image cũ, giữ build cache gần đây.
docker image prune -f >/dev/null
docker builder prune -f --filter "until=$BUILD_CACHE_KEEP" >/dev/null

echo "TOÀN BỘ HỆ THỐNG ĐÃ LÊN LIVE THÀNH CÔNG!"
