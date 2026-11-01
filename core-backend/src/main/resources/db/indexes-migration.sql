-- =====================================================================================================================
-- Two indexes (RB6): transactions (user_id, transaction_date) and receipts (status, created_at).
-- core-backend, PostgreSQL 15 (docker-compose service "db", image postgres:15-alpine). 2026-11-01
--
-- ONLY FOR AN OLD LOCAL DATABASE. A new database (the deploy server) gets both indexes from Hibernate (ddl-auto, from the
-- @Table(indexes) of Transaction and Receipt): nothing to run there. The same holds for an old database when the build that
-- maps the indexes starts first: its ddl-auto=update creates the same indexes under the same names. This file is for the
-- database that must have them before that, or whose ddl-auto cannot do it.
--
-- HOW TO RUN (psql only), after a backup (pg_dump):
--     psql -X -v ON_ERROR_STOP=1 -U <owner of the tables> -d <database> -f indexes-migration.sql
--   * As the role that owns transactions and receipts (DB_USERNAME): only the owner may create an index on a table.
--   * CREATE INDEX (not CONCURRENTLY, so that the file runs in one transaction) blocks every write to the table while the
--     index is built; reads go on. On a local database this lasts a moment. On a big table, stop core-api first.
--
-- WHAT IT GUARANTEES
--   * Atomic: one transaction. Idempotent: a second run changes nothing (CREATE INDEX IF NOT EXISTS).
--   * Additive: no table, column, row or other index is changed. The names and column lists are those of the @Index
--     entries, so ddl-auto finds them and creates nothing more.
--
--   idx_transactions_user_date    one user's transactions in a date range (dashboard, statistics, ledger)
--   idx_receipts_status_created   the receipts of one status, oldest or newest first (the admin review pages)
-- =====================================================================================================================

\set ON_ERROR_STOP on

BEGIN;

SET LOCAL lock_timeout = '10s';

CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON transactions (user_id, transaction_date);
CREATE INDEX IF NOT EXISTS idx_receipts_status_created ON receipts (status, created_at);

DO $$
DECLARE
    present bigint := (SELECT count(*) FROM pg_indexes
                       WHERE schemaname = current_schema()
                         AND indexname IN ('idx_transactions_user_date', 'idx_receipts_status_created'));
BEGIN
    IF present <> 2 THEN
        RAISE EXCEPTION 'indexes-migration: expected 2 indexes, found %', present;
    END IF;
    RAISE NOTICE 'indexes-migration: ok indexes=%', present;
END
$$;

COMMIT;
