-- =============================================================
-- 04_facts.sql
-- Fact tables of the star schema.
-- =============================================================

-- -------------------------------------------------------------
-- fact_scheduled_service
-- What STIB PLANS to run, from the GTFS timetable.
-- Grain: one row per date x line x stop x direction x hour.
-- Aggregated per hour (instead of one row per departure) to keep
-- the table light enough for Power BI in Import mode.
-- GTFS times after midnight (e.g. 25:10) are moved to the next
-- day during the transformation, so hour_key stays in 0..23.
-- -------------------------------------------------------------
DROP TABLE IF EXISTS dwh.fact_scheduled_service;
CREATE TABLE dwh.fact_scheduled_service (
    date_key          INTEGER  NOT NULL REFERENCES dwh.dim_date (date_key),
    hour_key          SMALLINT NOT NULL REFERENCES dwh.dim_hour (hour_key),
    line_key          INTEGER  NOT NULL REFERENCES dwh.dim_line (line_key),
    stop_key          INTEGER  NOT NULL REFERENCES dwh.dim_stop (stop_key),
    direction_id      SMALLINT NOT NULL DEFAULT 0 CHECK (direction_id IN (0, 1)),
    departures_count  INTEGER  NOT NULL CHECK (departures_count > 0),
    PRIMARY KEY (date_key, hour_key, line_key, stop_key, direction_id)
);

-- The primary key already indexes date_key first; add the other FKs
CREATE INDEX ix_fss_line ON dwh.fact_scheduled_service (line_key);
CREATE INDEX ix_fss_stop ON dwh.fact_scheduled_service (stop_key);

-- -------------------------------------------------------------
-- fact_vehicle_snapshot
-- What is ACTUALLY running, from the real-time API.
-- Grain: one row per snapshot x line x direction.
-- -------------------------------------------------------------
DROP TABLE IF EXISTS dwh.fact_vehicle_snapshot;
CREATE TABLE dwh.fact_vehicle_snapshot (
    snapshot_at         TIMESTAMPTZ NOT NULL,
    date_key            INTEGER     NOT NULL REFERENCES dwh.dim_date (date_key),
    hour_key            SMALLINT    NOT NULL REFERENCES dwh.dim_hour (hour_key),
    line_key            INTEGER     NOT NULL REFERENCES dwh.dim_line (line_key),
    direction_stop_key  INTEGER     REFERENCES dwh.dim_stop (stop_key),  -- terminus the vehicles head to
    vehicles_count      INTEGER     NOT NULL CHECK (vehicles_count >= 0)
);

-- A line/direction can only appear once per snapshot
-- (NULLS NOT DISTINCT requires PostgreSQL 15+)
CREATE UNIQUE INDEX ux_fvs_snapshot_line_direction
    ON dwh.fact_vehicle_snapshot (snapshot_at, line_key, direction_stop_key)
    NULLS NOT DISTINCT;

CREATE INDEX ix_fvs_date ON dwh.fact_vehicle_snapshot (date_key);
CREATE INDEX ix_fvs_line ON dwh.fact_vehicle_snapshot (line_key);