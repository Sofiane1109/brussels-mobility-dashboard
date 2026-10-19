-- =============================================================
-- 01_schemas.sql
-- Creates the two schemas of the project:
--   staging : raw data, loaded as-is from the STIB sources
--   dwh     : cleaned star schema used by Power BI
-- =============================================================
 
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS dwh;
 
COMMENT ON SCHEMA staging IS 'Raw STIB data (GTFS files and real-time API responses), loaded without transformation.';
COMMENT ON SCHEMA dwh     IS 'Star schema (dimensions + facts) consumed by the Power BI report.';