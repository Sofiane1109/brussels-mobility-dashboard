-- =============================================================
-- 00_run_all.sql
-- Builds the whole database structure in the right order.
-- Run from the sql/ folder:
--   psql -U <user> -d brussels_mobility -f 00_run_all.sql
-- Warning: dwh tables are dropped and recreated (data is lost).
-- =============================================================
 
\set ON_ERROR_STOP on
SET client_min_messages = warning;   -- hide "does not exist, skipping" notices
 
BEGIN;
\i 01_schemas.sql
\i 02_staging.sql
\i 03_dimensions.sql
\i 04_facts.sql
COMMIT;