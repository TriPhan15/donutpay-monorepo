-- =====================================================================================================================
-- Receipt owner (A7): receipts.owner_id, and its Envers copy receipts_aud.owner_id, filled from the transaction that
-- carries each receipt. core-backend, PostgreSQL 15 (docker-compose service "db", image postgres:15-alpine). 2026-10-29
--
-- ONLY FOR AN OLD LOCAL DATABASE. A new database (the deploy server) gets the column from Hibernate (ddl-auto) and every
-- receipt gets its owner when it is created: nothing to run there.
--
-- HOW TO RUN (psql only), after receipt-workflow-migration.sql and after a backup (pg_dump):
--     psql -X -v ON_ERROR_STOP=1 -U <owner of receipts> -d <database> -f receipt-owner-migration.sql
--   * As the role that owns receipts (DB_USERNAME): only the owner may add a column and a constraint.
--   * Before or after the build that maps Receipt.owner starts: its ddl-auto=update adds the same nullable column (but
--     fills nothing), and until then the build reads a receipt without owner through the transaction that carries it.
--
-- WHAT IT GUARANTEES
--   * Atomic: one transaction. Idempotent: a second run changes nothing.
--   * Additive: only owner_id is added and filled where it is NULL. A receipt that no transaction carries keeps a NULL
--     owner: only an administrator can act on it. The NOTICE at the end counts them.
-- =====================================================================================================================

\set ON_ERROR_STOP on

BEGIN;

ALTER TABLE receipts ADD COLUMN IF NOT EXISTS owner_id bigint;

DO $$
BEGIN
    -- The foreign key needs the users table (always there on a database of the application).
    IF to_regclass('users') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'receipts'::regclass AND conname = 'fk_receipts_owner') THEN
        ALTER TABLE receipts ADD CONSTRAINT fk_receipts_owner FOREIGN KEY (owner_id) REFERENCES users (id);
    END IF;
    IF to_regclass('receipts_aud') IS NOT NULL THEN
        ALTER TABLE receipts_aud ADD COLUMN IF NOT EXISTS owner_id bigint;
    END IF;
END
$$;

UPDATE receipts r
SET owner_id = t.user_id
FROM transactions t
WHERE t.receipt_id = r.id
  AND r.owner_id IS NULL;

DO $$
DECLARE
    with_owner    bigint := (SELECT count(*) FROM receipts WHERE owner_id IS NOT NULL);
    without_owner bigint := (SELECT count(*) FROM receipts WHERE owner_id IS NULL);
BEGIN
    RAISE NOTICE 'receipt-owner-migration: with_owner=% without_owner=%', with_owner, without_owner;
END
$$;

COMMIT;
