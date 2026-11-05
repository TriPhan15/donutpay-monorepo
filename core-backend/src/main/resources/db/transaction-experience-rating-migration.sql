-- =====================================================================================================================
-- Transaction experience rating & review note: transactions.rating (0.5..5.0, step 0.5), transactions.review_note,
-- and their Envers audit copies on transactions_aud. core-backend, PostgreSQL 15. 2026-11-05
--
-- HOW TO RUN (psql only):
--     psql -X -v ON_ERROR_STOP=1 -U <owner of transactions> -d <database> -f transaction-experience-rating-migration.sql
--
-- WHAT IT GUARANTEES
--   * Atomic: one transaction. Idempotent: a second run changes nothing.
--   * Additive: adds nullable rating numeric(2,1) and review_note varchar(255) to transactions and transactions_aud,
--     plus chk_transactions_rating_half_star enforcing 0.5..5.0 in 0.5 increments when rating IS NOT NULL.
-- =====================================================================================================================

\set ON_ERROR_STOP on

BEGIN;

ALTER TABLE transactions ADD COLUMN IF NOT EXISTS rating numeric(2, 1);
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS review_note varchar(255);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'transactions'::regclass
          AND conname = 'chk_transactions_rating_half_star'
    ) THEN
        ALTER TABLE transactions
            ADD CONSTRAINT chk_transactions_rating_half_star
            CHECK (rating IS NULL OR (rating >= 0.5 AND rating <= 5.0 AND MOD(rating * 2, 1) = 0));
    END IF;

    IF to_regclass('transactions_aud') IS NOT NULL THEN
        ALTER TABLE transactions_aud ADD COLUMN IF NOT EXISTS rating numeric(2, 1);
        ALTER TABLE transactions_aud ADD COLUMN IF NOT EXISTS review_note varchar(255);
    END IF;
END
$$;

COMMIT;
