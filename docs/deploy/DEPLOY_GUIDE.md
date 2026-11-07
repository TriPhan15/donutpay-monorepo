# Hướng dẫn triển khai

Tài liệu cho người mới: đưa LedgerMind lên một máy AWS EC2 (Ubuntu) có HTTPS, để CI tự deploy mỗi lần push `main`, và
để mỗi tag `v*` tạo một file APK có mã QR tải về. Phần cuối là dữ liệu demo (T2b).

Không dùng AWS: tạo máy theo **Phụ lục A (Oracle Cloud Always Free, miễn phí)** thay cho mục 2,
rồi làm tiếp từ mục 3. Các secret CI vẫn tên `AWS_HOST`, `AWS_USERNAME`, `AWS_SSH_KEY` dù máy ở đâu.

Những ô **[ĐIỀN]** là chỗ bạn thay bằng giá trị của mình. Không ghi giá trị thật (mật khẩu, khóa) vào file này hay bất
kỳ file nào được commit.

| Ô | Giá trị của bạn |
|---|---|
| Tên miền API (`SITE_ADDRESS`) | **[ĐIỀN]** vd. `api.example.com` |
| Elastic IP của EC2 | **[ĐIỀN]** vd. `203.0.113.10` |
| User SSH | **[ĐIỀN]** `ubuntu` với AMI Ubuntu |
| File khóa SSH trên máy bạn | **[ĐIỀN]** vd. `~/.ssh/ledgermind-ec2.pem` (không để trong repo) |

## 1. Kiến trúc khi chạy trên EC2

```text
Điện thoại / trình duyệt
        │ HTTPS 443 (HTTP 80 chỉ để chuyển hướng và xin chứng chỉ)
        ▼
  proxy (Caddy)  ── tự xin + tự gia hạn chứng chỉ Let's Encrypt cho SITE_ADDRESS
        │  mạng nội bộ finance-network (không mở ra ngoài)
        ├── /ai/health ─────────────────────────────► data-mining-api:8000 (bỏ tiền tố /ai, công khai)
        ├── /ai/donut/*, /ai/spade/* ── hỏi core-api GET /api/auth/check (cần Bearer token, sai → 401)
        │                            └─ hợp lệ ──► data-mining-api:8000 (bỏ tiền tố /ai)
        ├── /ai/* còn lại, /actuator/* trừ health ──► 404
        └── mọi đường dẫn khác ─────────────────────► core-api:8080 (REST /api/..., trang admin)
                                                        ├── db (PostgreSQL)  127.0.0.1:5432
                                                        ├── redis            (không có cổng)
                                                        └── mongodb          127.0.0.1:27017
```

- Chỉ container `proxy` publish cổng ra Internet (80, 443). `core-api` và `data-mining-api` không còn publish
  8080/8000: muốn gọi thì đi qua proxy.
- Cấu hình proxy: `deploy/caddy/Caddyfile`. Chọn Caddy vì nó tự lo chứng chỉ HTTPS, không cần certbot hay cron.
- App mobile đọc hai địa chỉ lúc build (`mobile-app/lib/config/app_config.dart`): `API_BASE=https://<tên miền>` và
  `ML_BASE=https://<tên miền>/ai`. CI tự truyền hai giá trị này (mục 7).

## 2. Tạo máy EC2 và Security Group

1. AWS Console → EC2 → **Launch instance**:
   - AMI: **Ubuntu Server 24.04 LTS** (hoặc 22.04).
   - Loại máy: khuyến nghị **t3.large (8 GB RAM)**. Tổng giới hạn RAM (`deploy.resources.limits.memory` trong
     `docker-compose.yml`) của các service chạy mặc định là **4 928 MB**: data-mining-api (ai-service) 3 GB, PostgreSQL 512 MB,
     MongoDB 512 MB, core-api 512 MB, Redis 192 MB, proxy 128 MB. Tổng này đã vượt 4 GB của t3.medium và chưa tính hệ điều
     hành, nên t3.medium chỉ chạy được khi các container không dùng hết giới hạn và có swap (mục 4). Bật profile `search`
     (Elasticsearch 1,5 GB) thì tổng lên 6 464 MB; thêm profile `tools` (Kibana 1 GB) thì 7 488 MB.
   - Ổ đĩa: **30 GB** gp3 trở lên (image PyTorch + model Donut khá nặng).
   - Key pair: tạo mới, tải file `.pem` về máy bạn: **[ĐIỀN]** đường dẫn. Không commit file này.
2. **Security Group** (inbound), chỉ mở đúng 3 cổng:

   | Cổng | Giao thức | Nguồn | Dùng cho |
   |---|---|---|---|
   | 22 | TCP | `0.0.0.0/0` (xem ghi chú) | SSH: bạn và GitHub Actions deploy |
   | 80 | TCP | `0.0.0.0/0` | Caddy xin chứng chỉ, chuyển hướng sang HTTPS |
   | 443 | TCP + UDP | `0.0.0.0/0` | HTTPS (UDP cho HTTP/3, không bắt buộc) |

   Không mở 8080, 8000, 5432, 6379, 27017. Ghi chú: GitHub Actions SSH vào từ dải IP thay đổi liên tục, nên cổng 22 phải
   mở rộng; bù lại chỉ đăng nhập bằng khóa (mặc định của Ubuntu trên EC2, không có mật khẩu).
3. **Elastic IP**: EC2 → Elastic IPs → Allocate → Associate với máy vừa tạo. Không có Elastic IP thì IP đổi mỗi lần
   stop/start máy và DNS sẽ trỏ sai. Ghi lại: **[ĐIỀN]** IP.

## 3. Trỏ DNS

Ở nhà cung cấp tên miền, tạo bản ghi:

| Loại | Tên | Giá trị | TTL |
|---|---|---|---|
| A | **[ĐIỀN]** vd. `api` | **[ĐIỀN]** Elastic IP | 300 |

Kiểm tra từ máy bạn (đợi vài phút tới vài giờ):

```bash
dig +short [ĐIỀN tên miền API]      # phải in ra đúng Elastic IP
```

Làm bước này **trước** khi khởi động lần đầu: Caddy chỉ xin được chứng chỉ khi tên miền đã trỏ về máy và cổng 80/443
đã mở.

## 4. Cài Docker trên Ubuntu

```bash
chmod 400 [ĐIỀN đường dẫn file .pem]
ssh -i [ĐIỀN đường dẫn file .pem] [ĐIỀN user]@[ĐIỀN Elastic IP]

# Trên server:
sudo apt-get update && sudo apt-get -y upgrade
sudo apt-get install -y ca-certificates curl git
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo docker run --rm hello-world          # in ra "Hello from Docker!" là được

# Nên có swap 2 GB để build image không bị hết RAM:
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## 5. Lấy mã nguồn và tạo `.env` trên server

CI deploy vào đúng thư mục `~/Deploy_Project` (xem `.github/workflows/ci.yml`), nên clone vào đó:

```bash
cd ~
git clone https://github.com/TriPhan15/donutpay-monorepo.git Deploy_Project
cd Deploy_Project
cp .env.example .env
chmod 600 .env
nano .env
```

Danh sách biến (mẫu đầy đủ, có chú thích: `.env.example` ở gốc repo). Không biến nào có giá trị mặc định an toàn: tự
tạo mật khẩu mới cho server, đừng dùng lại mật khẩu máy dev.

| Biến | Giá trị trên EC2 | Ghi chú |
|---|---|---|
| `SPRING_PROFILES_ACTIVE` | `prod` | Bật kiểm tra bắt buộc `JWT_SECRET`, tắt Swagger |
| `SITE_ADDRESS` | **[ĐIỀN]** tên miền API, không có `https://` | Để trống = chỉ HTTP cổng 80 (máy dev) |
| `LANDING_ADDRESS` | **[ĐIỀN]** tên miền gốc, vd. `example.com` | Trang chủ tải app (`index.html`). Bản ghi A của tên miền gốc phải trỏ về máy. Để trống = không phục vụ |
| `CORE_API_MEMORY_LIMIT` | `1G` trên máy 8 GB | Giới hạn RAM của core-api, mặc định `512M` |
| `JWT_SECRET` | **[ĐIỀN]** kết quả `openssl rand -base64 48` | ≥ 32 ký tự. Thiếu hoặc ngắn hơn: core-api dừng lúc khởi động. Đổi khóa = mọi người phải đăng nhập lại |
| `DB_USERNAME`, `DB_PASSWORD` | **[ĐIỀN]** | PostgreSQL được tạo mới với tài khoản này ở lần chạy đầu |
| `REDIS_PASSWORD` | **[ĐIỀN]** | Bắt buộc |
| `MONGO_ROOT_USERNAME`, `MONGO_ROOT_PASSWORD` | **[ĐIỀN]** chỉ chữ và số | Bắt buộc; mật khẩu nằm trong URI |
| `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` | **[ĐIỀN]** | Ảnh hóa đơn |
| `MAIL_USERNAME`, `MAIL_PASSWORD` | **[ĐIỀN]** Gmail + App Password | Gửi OTP quên mật khẩu |
| `GOOGLE_WEB_CLIENT_ID` | **[ĐIỀN]** | Đăng nhập Google |
| `PAYMENT_SECRET`, `MOCK_GATEWAY_URL`, `PAYMENT_WEBHOOK_URL`, `VNPAY_SECRET`, `ZALOPAY_SECRET` | **[ĐIỀN]** | Thanh toán demo |
| `SEED_DEMO` | `true` ở lần đầu | Database trên EC2 tạo mới, không có dữ liệu cần giữ. Xem mục "Dữ liệu demo" |
| `SEED_ADMIN_PASSWORD`, `SEED_DEMO_PASSWORD` | **[ĐIỀN]** | 8–72 ký tự, có chữ và số |
| `DB_URL` | để trống | `docker-compose.yml` tự đặt `jdbc:postgresql://db:5432/finance_db` |

Tạo mật khẩu ngẫu nhiên chỉ có chữ và số (dùng được cho mọi ô trên): `openssl rand -hex 24`.

**Cổng thanh toán giả lập bật ở production là có chủ đích.** Biến `MOCK_GATEWAY_ENABLED` không nằm trong bảng trên, nên
trên EC2 nó lấy mặc định `true` (`application.yml`: `${MOCK_GATEWAY_ENABLED:true}`), và `MockGatewayController` được
đăng ký với `matchIfMissing = true`. Lý do: để demo nạp và rút tiền khi chưa có cổng thanh toán thật. Trang
`/mock-gateway/pay` có nút "Thanh toán THÀNH CÔNG"; bấm nút này thì webhook ghi nhận đơn thành công và cập nhật số dư ví,
nên người dùng tự "nạp" được tiền ảo, không phải tiền thật. Khi nối cổng thật, đặt `MOCK_GATEWAY_ENABLED=false` trong `.env`. Lúc cổng giả
bật, `ProductionSecretsGuard` bắt buộc `VNPAY_SECRET` và `ZALOPAY_SECRET` phải có giá trị, nếu không profile prod không khởi
động; khi tắt, hai khóa này không còn bắt buộc.

### Chép model AI lên server (bắt buộc, làm một lần trước mục 6)

Git chỉ chứa phần cấu hình của model DONUT V5 (`ai-service/Version5/donut_result/*.json`). File trọng số
`model.safetensors` (~806 MB) bị `.gitignore` chặn, nên `git clone` không có nó. Thiếu file này, ai-service dừng ngay lúc
khởi động với lỗi "Không tìm thấy weights", và core-api (phụ thuộc ai-service healthy) cũng không lên.

Image ai-service được build bằng `COPY . .` từ thư mục `ai-service/` trên server, nên chỉ cần đặt file vào đúng chỗ
trước khi build. Từ **máy của bạn** (nơi đã giải nén `donut_result.zip`):

```bash
# 1. Kiểm tra file gốc (khoảng 806 MB)
ls -lh ai-service/Version5/donut_result/model.safetensors
sha256sum ai-service/Version5/donut_result/model.safetensors     # ghi lại chuỗi này

# 2. Chép lên server (mất vài phút, tùy mạng)
scp -i [ĐIỀN đường dẫn khóa SSH] \
    ai-service/Version5/donut_result/model.safetensors \
    [ĐIỀN user SSH]@[ĐIỀN IP máy]:~/Deploy_Project/ai-service/Version5/donut_result/
```

Mạng chập chờn thì dùng `rsync`, bị ngắt giữa chừng chạy lại sẽ tiếp tục phần còn thiếu:

```bash
rsync -avP -e "ssh -i [ĐIỀN đường dẫn khóa SSH]" \
    ai-service/Version5/donut_result/model.safetensors \
    [ĐIỀN user SSH]@[ĐIỀN IP máy]:~/Deploy_Project/ai-service/Version5/donut_result/
```

Trên **server**, kiểm tra file đủ và không hỏng:

```bash
cd ~/Deploy_Project/ai-service/Version5/donut_result
ls -lh model.safetensors          # ~806 MB
sha256sum model.safetensors       # phải trùng chuỗi đã ghi ở bước 1
ls                                # có cả config.json, tokenizer.json, processor_config.json... (từ git)
```

Lưu ý:

- Chỉ chép **một lần**. CI deploy bằng `git reset --hard`, lệnh này không xóa file bị ignore, nên model vẫn nằm đó qua
  các lần deploy sau. **Đừng** chạy `git clean -fdx` trong `~/Deploy_Project`: lệnh đó xóa luôn model (và `.env`).
- Khi train lại model mới: chép đè `model.safetensors`, commit các file `*.json` mới của `donut_result/`, rồi deploy
  (`docker compose build data-mining-api` sẽ đóng gói lại model).
- `training_args.bin` không cần chép: file này chỉ dùng lúc train.
- Model chiếm thêm ~800 MB trong image và ~1,5–2,5 GB RAM khi chạy; `docker-compose.yml` giới hạn ai-service ở 3 GB.

## 6. Khởi động lần đầu

```bash
cd ~/Deploy_Project
sudo docker compose up -d --build --wait     # lần đầu build mất 10–20 phút
sudo docker compose ps                        # mọi service "running (healthy)" hoặc "running"
sudo docker compose logs --tail=50 proxy      # tìm dòng "certificate obtained successfully"
```

Sau khi seed xong (log core-api có dòng của DataSeeder), có thể sửa `SEED_DEMO=false` trong `.env`; dữ liệu vẫn giữ.

## 7. GitHub Secrets và Variables

Repo trên GitHub → **Settings → Secrets and variables → Actions**.

**Secrets** (tab *Secrets*):

| Tên | Giá trị | Dùng bởi |
|---|---|---|
| `AWS_HOST` | **[ĐIỀN]** Elastic IP (hoặc tên miền) | job `deploy` |
| `AWS_USERNAME` | **[ĐIỀN]** user SSH, vd. `ubuntu` | job `deploy` |
| `AWS_SSH_KEY` | toàn bộ nội dung file `.pem` (cả dòng BEGIN/END) | job `deploy` |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w 0 upload-keystore.jks` | job `release-apk` |
| `ANDROID_KEYSTORE_PASSWORD` | **[ĐIỀN]** mật khẩu keystore | job `release-apk` |
| `ANDROID_KEY_ALIAS` | **[ĐIỀN]** vd. `upload` | job `release-apk` |
| `ANDROID_KEY_PASSWORD` | **[ĐIỀN]** mật khẩu khóa (thường trùng mật khẩu keystore) | job `release-apk` |
| `GOOGLE_SERVICES_JSON_BASE64` | `base64 -w 0 mobile-app/android/app/google-services.json` | job `release-apk` (file này không được commit nhưng Gradle cần nó) |

Từ khi job `deploy` chạy qua SSM (mục 14), `AWS_HOST`, `AWS_USERNAME`, `AWS_SSH_KEY` không còn dùng: job đọc
Variables `AWS_DEPLOY_ROLE_ARN`, `AWS_REGION`, `AWS_INSTANCE_ID`.

**Variables** (tab *Variables*, không bí mật):

| Tên | Giá trị |
|---|---|
| `APP_API_BASE` | `https://[ĐIỀN tên miền API]` (không có `/` cuối, không có `/api`) |

### Tạo keystore ký APK (làm một lần)

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
base64 -w 0 upload-keystore.jks > upload-keystore.b64   # dán nội dung vào secret ANDROID_KEYSTORE_BASE64
rm upload-keystore.b64
```

**Cất bản sao keystore và mật khẩu ở nơi an toàn** (trình quản lý mật khẩu, ổ cứng riêng). Mất keystore thì không phát
hành bản cập nhật cho người đã cài app được nữa: điện thoại sẽ từ chối cài đè bản ký bằng khóa khác.

Nếu máy bạn đã có `mobile-app/android/app/upload-keystore.jks` và `mobile-app/android/key.properties` (đang dùng để build
release tại máy) thì dùng chính keystore đó cho CI, đừng tạo khóa mới. Gradle (`android/app/build.gradle.kts`) đọc
`key.properties` nếu có, nếu không thì đọc biến môi trường `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` (CI đặt các biến này).

## 8. Quy trình hằng ngày

- **Deploy backend:** push lên `main`. CI chạy test backend/mobile/AI; xanh hết thì job `deploy` SSH vào EC2,
  `git reset --hard <commit vừa qua test>`, `docker compose build` rồi `up -d --wait`. Job dừng ngay nếu `.env` trên server thiếu
  hoặc thiếu `JWT_SECRET`, hoặc thiếu `model.safetensors`; healthcheck lỗi thì log core-api/ai/proxy được in trên trang Actions.
  - Hai lần push liền nhau thì lần deploy sau đợi lần trước xong (`concurrency: deploy-production`).
  - **Migration SQL không tự chạy.** Commit nào có file `core-backend/src/main/resources/db/*.sql` mới: chạy nó trên server
    trước (`docker compose exec -T db sh -c 'psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d finance_db' < <file>.sql`),
    rồi mới push `main`.
- **Phát hành APK:**

  ```bash
  git tag v1.1.0
  git push origin v1.1.0
  ```

  Job `release-apk` build APK release (tên phiên bản lấy từ tag, `versionCode` = số lần chạy CI), ký bằng keystore,
  tạo GitHub Release và đính kèm `LedgerMind.apk`. Nút tải và mã QR ở `index.html` trỏ tới
  `https://github.com/TriPhan15/donutpay-monorepo/releases/latest/download/LedgerMind.apk`, nên luôn là bản mới nhất.
  Repo phải để **public** thì link mới mở được khi chưa đăng nhập GitHub.

## 9. Kiểm tra sau deploy

```bash
# Từ máy bạn:
curl -I http://[ĐIỀN tên miền API]                 # 308 chuyển sang https
curl https://[ĐIỀN tên miền API]/actuator/health   # {"status":"UP"...}
curl https://[ĐIỀN tên miền API]/ai/health         # trả lời của ai-service
curl -o /dev/null -w '%{http_code}\n' https://[ĐIỀN tên miền API]/ai/spade/analyze   # 401: không có token thì bị chặn
curl -o /dev/null -w '%{http_code}\n' https://[ĐIỀN tên miền API]/ai/admin/segment   # 404: không lộ ra ngoài
nc -zv -w 5 [ĐIỀN Elastic IP] 8080                  # phải thất bại (timeout/refused)
nc -zv -w 5 [ĐIỀN Elastic IP] 8000                  # phải thất bại
```

Sau đó: mở Web Admin qua `https://[ĐIỀN tên miền API]` (đường dẫn trang admin của core-api) bằng tài khoản `admin`, cài APK bằng cách quét QR, đăng nhập bằng
tài khoản demo, quét thử một hóa đơn.

## 10. Xem log

```bash
cd ~/Deploy_Project
sudo docker compose ps
sudo docker compose logs -f --tail=100 core-api          # Ctrl+C để thoát
sudo docker compose logs --tail=100 data-mining-api
sudo docker compose logs --tail=100 proxy                # lỗi chứng chỉ, request bị từ chối
sudo docker stats --no-stream                            # RAM/CPU từng container
```

Mọi service chạy lâu dài trong `docker-compose.yml` giới hạn log 3 file × 10 MB (`logging.options`), nên không làm đầy
ổ đĩa. Container khởi tạo một lần `elasticsearch-init-snapshots` (profile `search`) không khai báo log.

## 11. Rollback

Backend (trên server):

```bash
cd ~/Deploy_Project
git log --oneline -5                       # chọn commit ổn định trước đó
git reset --hard [ĐIỀN mã commit]
sudo docker compose up -d --build --wait
```

Cách này chỉ tạm thời: lần push `main` sau CI sẽ đưa server về `origin/main`. Muốn rollback lâu dài thì `git revert`
commit lỗi trên máy bạn rồi push.

APK: trên GitHub → Releases, sửa bản phát hành trước đó và tick **Set as the latest release** (link `latest` sẽ trỏ về
bản đó), hoặc xóa bản lỗi. Điện thoại đã cài bản mới hơn phải gỡ app rồi cài lại bản cũ (Android không cho hạ
`versionCode`).

Không bao giờ chạy `docker compose down -v` trên server: `-v` xóa volume database và chứng chỉ.

## 12. Lỗi thường gặp

| Hiện tượng | Nguyên nhân hay gặp |
|---|---|
| Log proxy báo không xin được chứng chỉ | DNS chưa trỏ đúng Elastic IP, hoặc Security Group chưa mở 80/443, hoặc `SITE_ADDRESS` có `https://` |
| core-api khởi động lại liên tục, log "Thiếu JWT_SECRET" | `.env` thiếu `JWT_SECRET` hoặc ngắn hơn 32 ký tự khi `SPRING_PROFILES_ACTIVE=prod` |
| `docker compose` báo "Set REDIS_PASSWORD in .env" / "Set MONGO_..." | Thiếu biến bắt buộc trong `.env` |
| App trên điện thoại báo lỗi mạng | `APP_API_BASE` sai hoặc không phải `https://`, hoặc build APK trước khi đặt variable |
| Job `release-apk` dừng ở "Check release secrets" | Thiếu một secret/variable ở mục 7 (tên được in trong log) |
| Build trên EC2 bị kill | Hết RAM: thêm swap (mục 4) hoặc dùng máy lớn hơn |
| data-mining-api dừng ngay, log "Không tìm thấy weights" hoặc lỗi đọc safetensors | Chưa chép `model.safetensors` hoặc file chép thiếu (so `sha256sum`), xem "Chép model AI lên server" ở mục 5; chép xong chạy `sudo docker compose build data-mining-api && sudo docker compose up -d --wait` |
| data-mining-api bị khởi động lại khi quét hóa đơn (`docker compose ps` báo restart, `dmesg` có "Out of memory") | Máy thiếu RAM cho model: thêm swap hoặc dùng máy ≥ 8 GB RAM (t3.large) |

## 13. Máy dev (docker compose tại máy)

- Để trống `SITE_ADDRESS` trong `.env`: proxy chạy HTTP ở `http://localhost` (cổng 80). 8080/8000 không còn mở ra máy
  host.
- Điện thoại thật trong cùng Wi-Fi: `mobile-app/deploy.sh` build với `API_BASE=http://<IP máy>` và
  `ML_BASE=http://<IP máy>/ai`.
- `SPRING_PROFILES_ACTIVE=dev` thì `JWT_SECRET` có thể để trống (dùng khóa dev cố định, log có cảnh báo).

## 14. Deploy không mở cổng 22: SSM Run Command + GitHub OIDC (AWS)

Job `deploy` không SSH nữa. GitHub Actions xin OIDC token, đổi lấy quyền tạm của IAM role (chỉ repo
`TriPhan15/donutpay-monorepo`, nhánh `main`), rồi gửi lệnh qua **SSM Run Command** tới SSM agent trên EC2 (agent tự gọi
ra AWS qua HTTPS, không cần cổng vào nào). Không có khóa SSH hay access key nào nằm trong GitHub. Không dùng
self-hosted runner vì repo PUBLIC: PR từ fork có thể chạy code trên máy production.

Lệnh trên server: `git fetch` + `reset --hard <github.sha>` bằng user thường (dùng deploy key của user đó), rồi
`scripts/deploy/server-deploy.sh` chạy bằng root: kiểm tra `.env`/model, build (log đầy đủ ở
`/var/log/ledgermind-build.log`), `up -d --wait`, in `ps` + log khi lỗi, dọn image cũ. Giới hạn thực thi 40 phút; máy đang
Stop thì lệnh hết hạn sau 10 phút. Migration SQL vẫn **không** tự chạy.

### 14.1 Dựng một lần (AWS Console, đúng region của máy)

1. **IAM → Identity providers → Add provider**: OpenID Connect, URL `https://token.actions.githubusercontent.com`,
   Audience `sts.amazonaws.com`.
2. **IAM → Roles → Create role → Custom trust policy** (thay `<ACCOUNT_ID>`), tên `ledgermind-gha-deploy`:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Principal": {"Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"},
       "Action": "sts:AssumeRoleWithWebIdentity",
       "Condition": {"StringEquals": {
         "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
         "token.actions.githubusercontent.com:sub": "repo:TriPhan15/donutpay-monorepo:ref:refs/heads/main"
       }}
     }]
   }
   ```

   Nếu job `deploy` sau này có `environment:`, `sub` đổi thành `repo:TriPhan15/donutpay-monorepo:environment:<tên>`.
3. Thêm inline policy `ssm-deploy-one-instance` cho role đó (thay `<REGION>`, `<ACCOUNT_ID>`, `<INSTANCE_ID>`):

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {"Effect": "Allow", "Action": "ssm:SendCommand", "Resource": [
         "arn:aws:ec2:<REGION>:<ACCOUNT_ID>:instance/<INSTANCE_ID>",
         "arn:aws:ssm:<REGION>::document/AWS-RunShellScript"]},
       {"Effect": "Allow", "Action": ["ssm:GetCommandInvocation", "ssm:ListCommandInvocations"], "Resource": "*"}
     ]
   }
   ```

4. **Role cho máy**: IAM → Roles → Create role → AWS service / EC2 → policy `AmazonSSMManagedInstanceCore`, tên
   `ledgermind-ec2-ssm`. Rồi EC2 → chọn máy → Actions → Security → **Modify IAM role** → chọn role này.
5. Kiểm tra agent: Ubuntu AMI có sẵn `amazon-ssm-agent` (snap). Sau 1–5 phút, **Systems Manager → Fleet Manager** phải
   thấy máy *Online* (chậm thì `sudo snap restart amazon-ssm-agent`). Thử: Systems Manager → Run Command →
   `AWS-RunShellScript`, lệnh `whoami; docker compose version`.
6. GitHub → Settings → Secrets and variables → Actions → **Variables**: `AWS_DEPLOY_ROLE_ARN` = ARN role bước 2,
   `AWS_REGION` (vd. `ap-southeast-1`), `AWS_INSTANCE_ID` (vd. `i-0258cd0be41d37ec5`); `DEPLOY_USER` chỉ cần khi user
   trên máy khác `ubuntu`. Không cần secret nào.

### 14.2 Sau khi một lần deploy qua SSM xanh

- EC2 → Security Group của máy: xóa rule SSH `22` từ `0.0.0.0/0` (giữ 80/443). Cần vào máy thì dùng
  **Session Manager** (EC2 → Connect → Session Manager) hoặc tạm thêm rule 22 cho `<IP của bạn>/32` rồi xóa.
- Xóa secret `AWS_SSH_KEY` (và `AWS_HOST`, `AWS_USERNAME`, không còn dùng). Xóa khóa công khai CI tương ứng khỏi
  `~/.ssh/authorized_keys` trên server.

### 14.3 Tương đương trên Azure (khi chuyển máy)

- Thay SSM bằng **`az vm run-command`** (VM agent có sẵn trên Ubuntu image, cũng không cần cổng vào).
- Entra ID → App registrations → New (vd. `ledgermind-gha-deploy`) → **Certificates & secrets → Federated credentials →
  GitHub Actions**: org `TriPhan15`, repo `donutpay-monorepo`, entity *Branch* `main`. Cấp cho app đó role
  **Virtual Machine Contributor** chỉ trên VM `ledgermind-server` (VM → Access control (IAM)). Nếu tài khoản sinh viên
  không cho tạo App registration, dùng User-assigned managed identity + federated credential (cùng các trường).
- GitHub Variables: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`. Job: `permissions: id-token: write`,
  `azure/login@v2` (client-id/tenant-id/subscription-id), rồi:

  ```bash
  az vm run-command create -g ledgermind-rg --vm-name ledgermind-server --name deploy-$GITHUB_RUN_ID \
    --timeout-in-seconds 2400 --async-execution false \
    --script "set -eu; cd /home/azureuser/Deploy_Project; sudo -H -u azureuser git fetch origin main; \
  sudo -H -u azureuser git reset --hard $GITHUB_SHA; bash scripts/deploy/server-deploy.sh /home/azureuser/Deploy_Project"
  az vm run-command show -g ledgermind-rg --vm-name ledgermind-server --name deploy-$GITHUB_RUN_ID --instance-view \
    --query 'instanceView.{state:executionState,exit:exitCode,out:output,err:error}'
  ```

  Lệnh này chưa chạy thử trên máy Azure thật (unverified): thử và chỉnh trước khi đưa vào CI. Xong thì xóa rule NSG `SSH-owner` hoặc giới hạn về IP của bạn.

## Dữ liệu demo

`core-backend` có bộ seed dữ liệu demo (`Config/DataSeeder.java`, `Service/DemoData/`). Mặc định **tắt**.

### Bật seed

Thêm vào `.env` (máy dev) hoặc `.env_deploy` (EC2), rồi `docker compose up -d`:

```env
SEED_DEMO=true
SEED_ADMIN_PASSWORD=<mật khẩu admin do bạn tự đặt, KHÔNG ghi vào repo>
SEED_DEMO_PASSWORD=<mật khẩu demo do bạn tự đặt, KHÔNG ghi vào repo>
```

- Hai mật khẩu phải đạt `@StrongPassword`: 8–72 ký tự, có ít nhất một chữ cái và một chữ số. Thiếu hoặc yếu thì
  core-api dừng ngay lúc khởi động và log ghi rõ lý do.
- Seed chỉ chạy khi bảng `users` **còn trống**. Database đã có người dùng thì bỏ qua; seeder không bao giờ xóa dữ liệu.
- Sau lần khởi động đầu tiên có thể để `SEED_DEMO=false` (để `true` cũng không sao vì seeder sẽ bỏ qua).
- Production thật (có người dùng thật): luôn để `SEED_DEMO=false`.
- Muốn seed lại trên máy dev: `docker compose down -v` (**xóa toàn bộ dữ liệu local**), rồi `up` lại với `SEED_DEMO=true`.

### Tài khoản

| Vai trò | Tên đăng nhập | Email | Mật khẩu |
|---|---|---|---|
| Admin (Web Admin) | `admin` | `admin@example.com` | giá trị `SEED_ADMIN_PASSWORD` |
| Demo: nhân viên văn phòng | `demo.vanphong` | `demo.vanphong@example.com` | giá trị `SEED_DEMO_PASSWORD` |
| Demo: sinh viên | `demo.sinhvien` | `demo.sinhvien@example.com` | giá trị `SEED_DEMO_PASSWORD` |

`example.com` là tên miền dành riêng cho ví dụ nên không email nào tới hộp thư thật. Vì vậy luồng quên mật khẩu (gửi OTP)
không dùng được với các tài khoản này. 36 tài khoản nền chỉ để thống kê có số liệu và không đăng nhập được.

### Nội dung được seed

- 21 danh mục mặc định (15 chi, 6 thu). Mỗi danh mục có `key` ổn định trong `Entity/DefaultCategory.java` để mobile
  dịch sang tiếng Anh (T4).
- Khoảng vài nghìn giao dịch. Tài khoản đang dùng có dữ liệu trong 3 tháng trước và tháng hiện tại; tài khoản nền chia
  theo nhóm VIP / ACTIVE / AT-RISK / CHURN. `walletBalance` của mỗi người bằng tổng thu trừ tổng chi.
- Riêng hai tài khoản demo:
  - ngân sách tuần và tháng; ngân sách "Ăn uống" tháng này của `demo.vanphong` đã vượt 80% nên có thông báo cảnh báo;
  - mục tiêu tiết kiệm;
  - hóa đơn ở các trạng thái `COMPLETED_RAW`, `EDITED`, `FAILED`, `WAITING_FOR_REVIEW`, `APPROVED`, kèm thông báo;
  - vài dòng nhật ký hệ thống.
- MongoDB: mỗi hóa đơn có một log OCR thô; hóa đơn được sửa hoặc đang chờ duyệt có thêm một phản hồi. Nếu MongoDB không
  chạy thì phần này bị bỏ qua và app vẫn khởi động.
- Nhãn phân khúc khách hàng (`ai_label`) **không** được seed sẵn. Vào Dashboard của Web Admin, bấm "Chạy Phân Lớp AI Tự
  Động" (cần ai-service đang chạy) để nhãn được tính từ dữ liệu demo.

Dữ liệu được sinh với hạt giống cố định (`Random(42)`) và tính theo ngày seed. Seed vào hai ngày khác nhau sẽ ra cùng
cấu trúc, nhưng khoảng ngày của dữ liệu sẽ dời theo.

Lưu ý: hạn mức ngân sách được tính từ số tiền đã chi trong kỳ hiện tại. Nếu seed vào sáng sớm ngày 1 (tháng chưa có
khoản chi nào) thì ngân sách "Ăn uống" chưa vượt 80% và sẽ không có thông báo cảnh báo. Nên seed từ ngày 2 trở đi.

## Phụ lục: tiền và credit

Máy chạy 24/7 nên bị tính tiền cả khi không ai dùng. Máy t3.large 8 GB RAM (khuyến nghị ở mục 2) + ổ đĩa 30 GB + IP tĩnh
tốn khoảng 65–85 USD/tháng theo giá on-demand (tùy vùng): 100 USD credit chỉ đủ hơn 1 tháng. Máy 4 GB RAM (t3.medium) tốn
khoảng 30–40 USD/tháng, đủ khoảng 3 tháng (đây là lý do subscription Azure for Students cũ bị khóa). Ổ đĩa và IP tĩnh vẫn tính tiền khi
máy đã tắt; chỉ xóa máy mới dừng hẳn. Ở nhà cung cấp nào cũng đặt **cảnh báo ngân sách** (vd. báo khi đã tiêu 50% credit).

## Phụ lục A. Oracle Cloud Always Free (máy ARM)

Gói Always Free cho máy **Ampere A1 (ARM64)** tối đa 4 OCPU và 24 GB RAM, không mất tiền nếu không vượt giới hạn. Kiểm tra
lại giới hạn hiện hành trên trang Oracle Cloud Free Tier.

Lưu ý ARM: mọi image trong `docker-compose.yml` (Caddy, PostgreSQL, Redis, MongoDB 6, Temurin, python-slim) và PyTorch
CPU đều có bản ARM64, nhưng project **chưa từng được build trên ARM**. Lần build đầu hãy xem kỹ log `data-mining-api`.

### A1. Tài khoản và thẻ

1. Đăng ký ở https://www.oracle.com/cloud/free/. Oracle giữ tạm một khoản nhỏ trên thẻ để xác minh rồi hoàn lại.
   Thẻ ảo/trả trước thường bị từ chối; tên và địa chỉ khai báo nên trùng với thẻ.
2. **Home Region chọn một lần, không đổi được**, và máy A1 miễn phí chỉ tạo được ở Home Region. Vùng đông người
   (Singapore, Tokyo) hay hết máy; vùng ít người hơn dễ tạo hơn, đổi lại độ trễ cao hơn.
3. Tùy chọn: nâng tài khoản lên **Pay As You Go**. Tài nguyên Always Free vẫn miễn phí, máy dễ tạo hơn và không bị
   thu hồi khi chạy rảnh lâu ngày; bù lại vượt giới hạn là bị tính tiền thật, nên phải đặt **Budget** (Billing → Budgets)
   trước.

### A2. Tạo máy

1. **Compute → Instances → Create instance**:
   - Image: **Canonical Ubuntu 24.04** (bản aarch64 khớp với shape bên dưới).
   - Shape: **Ampere → VM.Standard.A1.Flex**, chọn **2 OCPU / 12 GB** (hoặc 4 / 24). Phải thấy nhãn *Always Free-eligible*.
   - Networking: tạo VCN mới, subnet **public**, **Assign a public IPv4 address**.
   - SSH keys: tải lên `~/.ssh/ledgermind-oci.pub` (tạo bằng `ssh-keygen -t ed25519 -f ~/.ssh/ledgermind-oci`).
   - Boot volume: 50 GB là đủ (giới hạn miễn phí tính tổng các ổ).
2. Báo lỗi **"Out of capacity for shape VM.Standard.A1.Flex"**: thử Availability Domain khác, giảm xuống 1 OCPU / 6 GB,
   hoặc thử lại vào giờ khác. Đây là lỗi thiếu máy của Oracle, không phải lỗi cấu hình.
3. Mở cổng ở **hai lớp tường lửa**:
   - **VCN → Subnet → Security List → Add Ingress Rules**: Source `0.0.0.0/0`, TCP, cổng `80` và `443` (cổng 22 có sẵn).
   - **Bên trong máy Ubuntu của Oracle**, iptables mặc định chặn mọi cổng trừ 22. Mở 80 và 443 và lưu lại:

     ```bash
     sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
     sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
     sudo netfilter-persistent save
     ```

   Thiếu một trong hai lớp thì Caddy không xin được chứng chỉ (mục 12).
4. SSH: `ssh -i ~/.ssh/ledgermind-oci ubuntu@<Public IP>`. User mặc định là `ubuntu` (có `sudo` không cần mật khẩu).

Rồi làm tiếp **mục 3–6** (máy 12 GB RAM thì không cần swap). Secrets CI: `AWS_HOST` = Public IP, `AWS_USERNAME` =
`ubuntu`, `AWS_SSH_KEY` = nội dung `~/.ssh/ledgermind-oci`. IP công khai kiểu ephemeral giữ nguyên khi stop/start máy,
chỉ mất khi xóa (terminate) máy; muốn chắc chắn hơn thì đổi sang *Reserved public IP* trong VNIC của máy.

## Phụ lục B. Chuyển sang máy hoặc nhà cung cấp khác

Toàn bộ hệ thống là mã nguồn trên GitHub + `docker compose`, nên chuyển máy chỉ là dựng lại:

1. Muốn giữ dữ liệu thì sao lưu database trên máy cũ **trước khi** máy bị khóa/xóa (biến lấy từ `.env`):

   ```bash
   cd ~/Deploy_Project
   sudo docker compose exec -T db pg_dump -U "$(grep ^DB_USERNAME= .env | cut -d= -f2)" finance_db > backup.sql
   scp -i <file khóa> <user>@<IP cũ>:~/Deploy_Project/backup.sql .    # chạy trên máy bạn
   ```

   Không cần giữ dữ liệu (chỉ có dữ liệu demo) thì bỏ qua bước này và để `SEED_DEMO=true` ở máy mới.
2. Sao lại file `.env` của máy cũ về máy bạn (hoặc tạo lại theo mục 5). Không commit file này.
3. Máy mới: làm mục 4–6. Có `backup.sql` thì trước khi bật core-api lần đầu, chạy `sudo docker compose up -d db`, rồi
   `sudo docker compose exec -T db psql -U <DB_USERNAME> finance_db < backup.sql`, sau đó mới `up -d --build --wait`.
4. Sửa bản ghi A (`api` và bản ghi gốc) trên name.com sang IP mới, và sửa secret `AWS_HOST`, `AWS_USERNAME`,
   `AWS_SSH_KEY` trên GitHub. App mobile không phải build lại vì vẫn gọi `https://api.ledgermind.dev`.
