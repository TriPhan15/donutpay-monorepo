-- =====================================================================================================================
-- Yearly budgets: lets budgets.period_type (and its Envers copy budgets_aud.period_type) hold YEAR, next to WEEK/MONTH.
-- core-backend, PostgreSQL 15 (docker-compose service "db", image postgres:15-alpine).                    2026-10-26
--
-- WHY
--   Hibernate 6 puts CHECK (period_type IN ('WEEK','MONTH')) on both tables when it creates them, and ddl-auto=update
--   never widens an existing CHECK. Without this script, saving a budget with periodType YEAR fails with a constraint
--   violation (the API answers it as the generic 409 of GlobalExceptionHandler.handleDataIntegrity).
--
-- HOW TO RUN (psql only)
--     psql -X -v ON_ERROR_STOP=1 -U <owner of budgets> -d <database> -f budget-period-year-migration.sql
--   * As the role that owns budgets and budgets_aud (DB_USERNAME): only the owner may drop or add a constraint.
--   * Before or after the build that knows BudgetPeriodType.YEAR starts; the older build never writes YEAR.
--   * After a backup (pg_dump), as before any change to production data.
--
-- WHAT IT GUARANTEES
--   * Atomic: one transaction; any failure leaves both tables as they were.
--   * Idempotent: a second run ends with the same single constraint per table.
--   * No row is changed. The new constraint is validated against the existing rows (WEEK/MONTH only, so it passes;
--     a row with any other value stops the script with its name). NULL stays allowed, as Envers writes NULL for a
--     deleted budget in budgets_aud.
--   * Every CHECK constraint that covers period_type alone is dropped first, whatever name it was given, and the new
--     one is added under the name PostgreSQL itself gives an inline column CHECK (<table>_period_type_check).
-- =====================================================================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    target       text;
    rel          regclass;
    column_no    smallint;
    old_check    record;
    unknown_rows bigint;
BEGIN
    IF to_regclass('public.budgets') IS NULL THEN
        RAISE EXCEPTION 'Table budgets not found: run this script on the database of core-backend';
    END IF;

    FOREACH target IN ARRAY ARRAY['budgets', 'budgets_aud'] LOOP
        rel := to_regclass('public.' || target);
        IF rel IS NULL THEN
            RAISE NOTICE 'Table % not found, skipped', target;
            CONTINUE;
        END IF;

        SELECT attnum INTO column_no FROM pg_attribute
        WHERE attrelid = rel AND attname = 'period_type' AND NOT attisdropped;
        IF column_no IS NULL THEN
            RAISE EXCEPTION 'Column %.period_type not found', target;
        END IF;

        EXECUTE format('SELECT count(*) FROM %s WHERE period_type IS NOT NULL '
                       || 'AND period_type NOT IN (''WEEK'', ''MONTH'', ''YEAR'')', rel) INTO unknown_rows;
        IF unknown_rows > 0 THEN
            RAISE EXCEPTION '% row(s) of % hold a period_type other than WEEK, MONTH, YEAR: fix them first',
                unknown_rows, target;
        END IF;

        FOR old_check IN
            SELECT conname FROM pg_constraint
            WHERE conrelid = rel AND contype = 'c' AND conkey = ARRAY[column_no]
        LOOP
            EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', rel, old_check.conname);
            RAISE NOTICE 'Dropped %.%', target, old_check.conname;
        END LOOP;

        EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I CHECK (period_type IN (''WEEK'', ''MONTH'', ''YEAR''))',
                       rel, target || '_period_type_check');
        RAISE NOTICE 'Added %.%_period_type_check (WEEK, MONTH, YEAR)', target, target;
    END LOOP;
END
$$;

-- Check: exactly one CHECK on period_type per table, and it accepts YEAR.
DO $$
DECLARE
    target text;
    rel    regclass;
    found  integer;
BEGIN
    FOREACH target IN ARRAY ARRAY['budgets', 'budgets_aud'] LOOP
        rel := to_regclass('public.' || target);
        CONTINUE WHEN rel IS NULL;
        SELECT count(*) INTO found FROM pg_constraint c
        JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attname = 'period_type'
        WHERE c.conrelid = rel AND c.contype = 'c' AND c.conkey = ARRAY[a.attnum]
          AND pg_get_constraintdef(c.oid) LIKE '%YEAR%';
        IF found <> 1 THEN
            RAISE EXCEPTION 'Expected one CHECK on %.period_type accepting YEAR, found %', target, found;
        END IF;
    END LOOP;
    RAISE NOTICE 'budget-period-year-migration: done';
END
$$;

COMMIT;
