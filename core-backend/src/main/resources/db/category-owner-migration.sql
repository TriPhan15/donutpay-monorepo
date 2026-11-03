-- =====================================================================================================================
-- Category owner (B8): categories.owner_id, its mirror categories.owner_key, and categories_aud.owner_id; the foreign key,
-- the index of owner_id and the uniqueness of a name per owner. core-backend, PostgreSQL 15 (docker-compose service "db",
-- image postgres:15-alpine). 2026-11-01
--
-- ONLY FOR AN OLD LOCAL DATABASE. A new database (the deploy server) gets the columns, the constraint and the index from
-- Hibernate (ddl-auto) and every category a user names gets its owner when it is created: nothing to run there.
--
-- HOW TO RUN (psql only), after a backup (pg_dump):
--     psql -X -v ON_ERROR_STOP=1 -U <owner of categories> -d <database> -f category-owner-migration.sql
--   * As the role that owns categories (DB_USERNAME): only the owner may add a column and a constraint.
--   * Before or after the build that maps Category.owner starts: its ddl-auto=update adds the same columns (but fills
--     nothing and does not add the uniqueness over data that already repeats a name), so the script adds only what is
--     missing.
--
-- WHAT IT GUARANTEES
--   * Atomic: one transaction. Idempotent: a second run changes nothing.
--   * Additive: no category is changed, moved or deleted. Every category that exists keeps a NULL owner: it stays a
--     default one and every user sees it, as before. Nobody can tell who typed an old category in, and guessing would
--     hide a category from the user who uses it.
--   * A name is unique per owner, not overall: UNIQUE (owner_key, name). owner_key is owner_id, or 0 when there is no
--     owner, because SQL treats NULLs as distinct and UNIQUE (owner_id, name) would let the default categories repeat a
--     name. Two users can each have the same name; one user (or the default set) cannot have it twice.
--   * An old database may already hold the same name twice (nothing prevented it). Then the uniqueness is NOT added,
--     nothing is merged, and the NOTICE at the end counts the names. Merge them by hand (move their transactions and
--     budgets to one of the categories, then delete the others) and run the script again: it adds the uniqueness then.
-- =====================================================================================================================

\set ON_ERROR_STOP on

BEGIN;

ALTER TABLE categories ADD COLUMN IF NOT EXISTS owner_id bigint;
ALTER TABLE categories ADD COLUMN IF NOT EXISTS owner_key bigint NOT NULL DEFAULT 0;

DO $$
BEGIN
    -- The foreign key needs the users table (always there on a database of the application).
    IF to_regclass('users') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'categories'::regclass AND conname = 'fk_categories_owner') THEN
        ALTER TABLE categories ADD CONSTRAINT fk_categories_owner FOREIGN KEY (owner_id) REFERENCES users (id);
    END IF;
    IF to_regclass('categories_aud') IS NOT NULL THEN
        ALTER TABLE categories_aud ADD COLUMN IF NOT EXISTS owner_id bigint;
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_categories_owner_id ON categories (owner_id);

DO $$
DECLARE
    duplicate_names bigint := (SELECT count(*) FROM (SELECT 1 FROM categories GROUP BY owner_key, name HAVING count(*) > 1) d);
BEGIN
    IF duplicate_names = 0
       AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'categories'::regclass AND conname = 'uk_categories_owner_name') THEN
        ALTER TABLE categories ADD CONSTRAINT uk_categories_owner_name UNIQUE (owner_key, name);
    END IF;
END
$$;

DO $$
DECLARE
    total           bigint := (SELECT count(*) FROM categories);
    with_owner      bigint := (SELECT count(*) FROM categories WHERE owner_id IS NOT NULL);
    duplicate_names bigint := (SELECT count(*) FROM (SELECT 1 FROM categories GROUP BY owner_key, name HAVING count(*) > 1) d);
BEGIN
    RAISE NOTICE 'category-owner-migration: categories=% with_owner=% duplicate_names=%', total, with_owner, duplicate_names;
END
$$;

COMMIT;
