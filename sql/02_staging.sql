-- =============================================================
-- 02_staging.sql
-- Raw tables. Every column is TEXT on purpose: the load never
-- fails on a badly formatted value. Types are enforced later,
-- when the data is transformed into the dwh schema.
--
-- Sources (STIB-MIVB open data, licence CC BY 4.0):
--   * GTFS static feed (zip, refreshed daily)
--   * Real-time "Vehicle Positions" API (JSON)
-- =============================================================

-- ---------- GTFS static ----------

DROP TABLE IF EXISTS staging.gtfs_routes;
CREATE TABLE staging.gtfs_routes (
    route_id          TEXT,
    agency_id         TEXT,
    route_short_name  TEXT,
    route_long_name   TEXT,
    route_desc        TEXT,
    route_type        TEXT,
    route_url         TEXT,
    route_color       TEXT,
    route_text_color  TEXT,
    loaded_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TABLE IF EXISTS staging.gtfs_stops;
CREATE TABLE staging.gtfs_stops (
    stop_id         TEXT,
    stop_code       TEXT,
    stop_name       TEXT,
    stop_desc       TEXT,
    stop_lat        TEXT,
    stop_lon        TEXT,
    zone_id         TEXT,
    stop_url        TEXT,
    location_type   TEXT,
    parent_station  TEXT,
    loaded_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TABLE IF EXISTS staging.gtfs_trips;
CREATE TABLE staging.gtfs_trips (
    route_id        TEXT,
    service_id      TEXT,
    trip_id         TEXT,
    trip_headsign   TEXT,
    direction_id    TEXT,
    block_id        TEXT,
    shape_id        TEXT,
    loaded_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TABLE IF EXISTS staging.gtfs_stop_times;
CREATE TABLE staging.gtfs_stop_times (
    trip_id         TEXT,
    arrival_time    TEXT,   -- GTFS format HH:MM:SS, can exceed 24:00:00 (night services)
    departure_time  TEXT,
    stop_id         TEXT,
    stop_sequence   TEXT,
    pickup_type     TEXT,
    drop_off_type   TEXT,
    loaded_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TABLE IF EXISTS staging.gtfs_calendar;
CREATE TABLE staging.gtfs_calendar (
    service_id  TEXT,
    monday      TEXT,
    tuesday     TEXT,
    wednesday   TEXT,
    thursday    TEXT,
    friday      TEXT,
    saturday    TEXT,
    sunday      TEXT,
    start_date  TEXT,   -- YYYYMMDD
    end_date    TEXT,
    loaded_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TABLE IF EXISTS staging.gtfs_calendar_dates;
CREATE TABLE staging.gtfs_calendar_dates (
    service_id      TEXT,
    date            TEXT,   -- YYYYMMDD
    exception_type  TEXT,   -- 1 = service added, 2 = service removed
    loaded_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- Real-time API ----------
-- One row per API call. The JSON is kept intact and parsed in SQL
-- during the transformation, so no information is lost.

CREATE TABLE IF NOT EXISTS staging.vehicle_positions_raw (
    raw_id        BIGSERIAL PRIMARY KEY,
    collected_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    payload       JSONB NOT NULL
);

CREATE INDEX IF NOT EXISTS ix_vehicle_positions_raw_collected_at
    ON staging.vehicle_positions_raw (collected_at);