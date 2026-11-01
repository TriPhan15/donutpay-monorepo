# Runbook: schema PostgreSQL và 4 file migration

Các file migration nằm ở `core-backend/src/main/resources/db/`. Tài liệu này chỉ ra lúc nào cần chạy, lúc nào không.

## 1. Server mới (deploy): không chạy migration

Server deploy dùng DB **trống**. Khi `core-api` chạy lần đầu, Hibernate (`ddl-auto`) tự tạo toàn bộ schema theo entity,
gồm các ràng buộc CHECK của cột enum và các bảng `*_aud` của Envers.

- Không chạy file nào trong `db/`. Hai file `action-log-audit-migration.sql` và `budget-period-year-migration.sql` cố ý
  `RAISE EXCEPTION` hoặc dừng khi không thấy bảng cũ.
- Test `SchemaEnumConstraintsPostgresTest` (Testcontainers, PostgreSQL 15) dựng đúng một DB mới như vậy và kiểm tra:
  mỗi CHECK của cột enum chứa đủ giá trị enum Java, các cột lưu tên enum dạng chuỗi đủ dài, và insert được từng giá trị.
  Chạy lại test này sau mỗi lần thêm giá trị enum:

  ```bash
  cd core-backend && mvn -B test -Dtest=SchemaEnumConstraintsPostgresTest
  ```

## 2. DB local còn dữ liệu cũ

`ddl-auto=update` chỉ **thêm** bảng và cột, không bao giờ sửa CHECK đã có. Vì vậy DB local tạo từ bản code cũ có thể
từ chối giá trị enum mới (ví dụ ngân sách `YEAR`), với lỗi dạng `violates check constraint "..._check"`, hoặc API trả
409 chung. Có hai cách xử lý.

### Cách 1 (khuyên dùng): xóa DB và tạo lại

Mất toàn bộ dữ liệu PostgreSQL local. Mongo, Redis và Elasticsearch không bị đụng tới.

```bash
docker compose stop core-api db
docker compose rm -f db
docker volume ls | grep postgres_data          # tìm tên volume, ví dụ donutpay-monorepo_postgres_data
docker volume rm <tên volume postgres_data>
# Muốn có dữ liệu mẫu: đặt SEED_DEMO=true trong .env
docker compose up -d db core-api
```

Không dùng `docker compose down -v`: lệnh này xóa **mọi** volume, gồm cả Mongo, Elasticsearch và chứng chỉ của Caddy.

Sau khi tạo lại, chỉ mục tìm kiếm Elasticsearch còn chứa giao dịch của DB cũ. Dựng lại chỉ mục từ trang admin
(Vận hành NoSQL) nếu cần.

### Cách 2: chạy 4 file migration

Dùng khi muốn giữ dữ liệu local. Trước khi chạy:

1. Backup trước: `docker exec finance-postgres pg_dump -U "$DB_USERNAME" -d finance_db -Fc > before-migration.dump`.
2. Chạy bằng `psql` với role sở hữu bảng (`DB_USERNAME` trong `.env`). Các file dùng lệnh meta của psql, không chạy
   được bằng DBeaver hay pgAdmin.
3. Không thêm `-1` hay `--single-transaction`. Mỗi file tự mở và commit transaction của nó, và
   `CREATE INDEX CONCURRENTLY` không chạy được trong transaction.

Lệnh chung, chạy từ thư mục gốc repo (Git Bash hoặc Linux), sau khi `set -a; . ./.env; set +a`:

```bash
docker exec -i finance-postgres psql -X -v ON_ERROR_STOP=1 -U "$DB_USERNAME" -d finance_db \
  < core-backend/src/main/resources/db/<tên file>.sql
```

Thứ tự chạy, theo ngày ghi ở đầu mỗi file:

| # | File | Làm gì | Lưu ý |
|---|---|---|---|
| 1 | `action-log-audit-migration.sql` | Thêm `target_type`, `target_id`, `result` vào `action_logs` và 5 index | Báo lỗi nếu không có bảng `action_logs`, vì DB mới không cần file này. Nếu báo index INVALID: `DROP INDEX CONCURRENTLY <tên>;` rồi chạy lại. |
| 2 | `receipt-workflow-migration.sql` | Thêm bảng `receipt_processing_attempts` và các cột mới của `receipts`, đổi trạng thái cũ (`SUCCESS`…) sang tên mới | **Dừng `core-api` trước**: `docker compose stop core-api`. Có `lock_timeout` 10 giây. Lỗi giữa chừng thì không có gì được áp dụng. |
| 3 | `budget-period-year-migration.sql` | Nới CHECK của `budgets.period_type` và `budgets_aud.period_type` để nhận `YEAR` | Báo lỗi nếu có dòng mang giá trị lạ. |
| 4 | `username-email-collision-check.sql` | Chỉ `SELECT`: liệt kê tài khoản có username dạng email của người khác | Không sửa dữ liệu. Có dòng nào thì xử lý tay. |

Cả 4 file đều idempotent: chạy lần hai không đổi gì.

Không file nào nới CHECK của `notifications.type`. Nếu DB local báo lỗi CHECK ở bảng `notifications`, dùng cách 1.

## 3. Cột mới sau đợt sửa schema (A6, A7)

Server mới không cần làm gì. Với DB local còn dữ liệu cũ, `ddl-auto=update` tự thêm cột khi `core-api` khởi động, nhưng
không điền dữ liệu cũ và không thêm CHECK cho cột đã có. Nếu muốn tự làm (hoặc khi `update` báo lỗi), chạy bằng `psql`
như mục 2, sau khi backup:

```sql
BEGIN;

-- A6: nguồn của giao dịch. GOAL_REFUND là tiền của mục tiêu tiết kiệm đã xóa quay về ví, không tính là thu nhập.
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS source varchar(16) NOT NULL DEFAULT 'NORMAL'
    CHECK (source IN ('NORMAL', 'GOAL_REFUND'));
ALTER TABLE transactions_aud ADD COLUMN IF NOT EXISTS source varchar(16)
    CHECK (source IN ('NORMAL', 'GOAL_REFUND'));
-- Các khoản hoàn tiền tạo trước cột này: nhận ra qua ghi chú mà SavingGoalService luôn ghi.
UPDATE transactions SET source = 'GOAL_REFUND'
WHERE is_expense = FALSE AND note LIKE 'Hoàn tiền từ mục tiêu tiết kiệm đã xóa:%' AND source = 'NORMAL';

COMMIT;
```

A7 (chủ sở hữu hóa đơn) có file riêng, chạy sau `receipt-workflow-migration.sql`:

```bash
docker exec -i finance-postgres psql -X -v ON_ERROR_STOP=1 -U "$DB_USERNAME" -d finance_db \
  < core-backend/src/main/resources/db/receipt-owner-migration.sql
```

File này thêm `receipts.owner_id` (khóa ngoại tới `users`) và `receipts_aud.owner_id`, rồi điền chủ của mỗi hóa đơn
từ giao dịch gắn với nó. Hóa đơn không gắn giao dịch nào giữ `owner_id` NULL, chỉ admin xử lý được. Chạy lại không đổi gì.
Chưa chạy file này thì app vẫn nhận ra chủ của hóa đơn cũ qua giao dịch gắn với nó.

RB6 (hai index `idx_transactions_user_date` và `idx_receipts_status_created`) có file `indexes-migration.sql`, chạy bằng `psql` như mục 2. Server mới không cần chạy. `CREATE INDEX` khóa ghi vào bảng đang tạo index (đọc vẫn được) trong lúc tạo: DB local nhỏ thì chỉ một thoáng, bảng lớn thì dừng `core-api` trước. Chạy lại không đổi gì.

## 4. Không cần chạy thử migration trên dữ liệu cũ

Server deploy bắt đầu từ DB trống, nên không cần chạy thử 4 file migration trên bản sao dữ liệu cũ.
