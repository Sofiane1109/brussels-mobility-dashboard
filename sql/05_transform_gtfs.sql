-- =============================================================
-- 05_transform_gtfs.sql
-- Transforms the raw GTFS (staging) into the star schema (dwh).
-- Run automatically by collecte/load_gtfs.py, can also be run
-- by hand with psql after a load.
-- Safe to re-run: dimensions are upserted, facts are replaced
-- for the dates covered by the feed.
-- =============================================================

-- ---------- 1. dim_line ----------
INSERT INTO dwh.dim_line (route_id, line_number, line_name, mode_key, line_color, line_text_color)
SELECT DISTINCT ON (trim(route_id))
    trim(route_id),
    trim(route_short_name),
    NULLIF(trim(route_long_name), ''),
    trim(route_type)::SMALLINT,
    upper(NULLIF(trim(route_color), '')),
    upper(NULLIF(trim(route_text_color), ''))
FROM staging.gtfs_routes
WHERE trim(route_type) ~ '^\d+$'
  AND trim(route_type)::SMALLINT IN (SELECT mode_key FROM dwh.dim_mode)
ORDER BY trim(route_id)
ON CONFLICT (route_id) DO UPDATE SET
    line_number     = EXCLUDED.line_number,
    line_name       = EXCLUDED.line_name,
    mode_key        = EXCLUDED.mode_key,
    line_color      = EXCLUDED.line_color,
    line_text_color = EXCLUDED.line_text_color;

-- ---------- 2. dim_stop ----------
INSERT INTO dwh.dim_stop (stop_id, stop_name, latitude, longitude, parent_station)
SELECT DISTINCT ON (trim(stop_id))
    trim(stop_id),
    trim(stop_name),
    NULLIF(trim(stop_lat), '')::NUMERIC(9,6),
    NULLIF(trim(stop_lon), '')::NUMERIC(9,6),
    NULLIF(trim(parent_station), '')
FROM staging.gtfs_stops
WHERE NULLIF(trim(stop_name), '') IS NOT NULL
ORDER BY trim(stop_id)
ON CONFLICT (stop_id) DO UPDATE SET
    stop_name      = EXCLUDED.stop_name,
    latitude       = EXCLUDED.latitude,
    longitude      = EXCLUDED.longitude,
    parent_station = EXCLUDED.parent_station;

-- ---------- 3. Dates on which each service runs ----------
-- calendar.txt gives a weekly pattern between two dates,
-- calendar_dates.txt adds (1) or removes (2) specific days.
DROP TABLE IF EXISTS tmp_service_dates;
CREATE TEMP TABLE tmp_service_dates AS
WITH regular AS (
    SELECT trim(c.service_id) AS service_id, d.full_date
    FROM staging.gtfs_calendar AS c
    JOIN dwh.dim_date AS d
      ON d.full_date BETWEEN to_date(trim(c.start_date), 'YYYYMMDD')
                         AND to_date(trim(c.end_date),   'YYYYMMDD')
    -- pick the column matching the weekday (1 = monday ... 7 = sunday)
    WHERE trim((ARRAY[c.monday, c.tuesday, c.wednesday, c.thursday,
                      c.friday, c.saturday, c.sunday])[d.iso_weekday]) = '1'
),
added AS (
    SELECT trim(service_id), to_date(trim(date), 'YYYYMMDD')
    FROM staging.gtfs_calendar_dates
    WHERE trim(exception_type) = '1'
),
removed AS (
    SELECT trim(service_id), to_date(trim(date), 'YYYYMMDD')
    FROM staging.gtfs_calendar_dates
    WHERE trim(exception_type) = '2'
)
SELECT * FROM regular
UNION
SELECT * FROM added
EXCEPT
SELECT * FROM removed;

-- ---------- 4. Departures per service pattern and GTFS hour ----------
-- Aggregated BEFORE expanding to dates, to keep the volume small.
-- The GTFS hour can be >= 24 (a 25:10 departure belongs to the
-- service day but happens at 01:10 the next calendar day).
DROP TABLE IF EXISTS tmp_departures;
CREATE TEMP TABLE tmp_departures AS
SELECT
    trim(t.route_id)                                        AS route_id,
    trim(t.service_id)                                      AS service_id,
    COALESCE(NULLIF(trim(t.direction_id), '')::SMALLINT, 0) AS direction_id,
    trim(st.stop_id)                                        AS stop_id,
    split_part(trim(st.departure_time), ':', 1)::INTEGER    AS gtfs_hour,
    count(*)                                                AS departures
FROM staging.gtfs_stop_times AS st
JOIN staging.gtfs_trips      AS t ON trim(t.trip_id) = trim(st.trip_id)
WHERE trim(st.departure_time) ~ '^\d{1,2}:\d{2}:\d{2}$'
GROUP BY 1, 2, 3, 4, 5;

-- ---------- 5. Build the facts ----------
DROP TABLE IF EXISTS tmp_fact;
CREATE TEMP TABLE tmp_fact AS
SELECT
    d.date_key,
    (dep.gtfs_hour % 24)::SMALLINT AS hour_key,
    l.line_key,
    s.stop_key,
    dep.direction_id,
    sum(dep.departures)::INTEGER   AS departures_count
FROM tmp_departures    AS dep
JOIN tmp_service_dates AS sd ON sd.service_id = dep.service_id
JOIN dwh.dim_date      AS d  ON d.full_date = sd.full_date + (dep.gtfs_hour / 24)
JOIN dwh.dim_line      AS l  ON l.route_id = dep.route_id
JOIN dwh.dim_stop      AS s  ON s.stop_id  = dep.stop_id
GROUP BY 1, 2, 3, 4, 5;

-- Replace the facts for the dates covered by this feed only,
-- so older dates already in the table are kept.
DELETE FROM dwh.fact_scheduled_service
WHERE date_key IN (SELECT DISTINCT date_key FROM tmp_fact);

INSERT INTO dwh.fact_scheduled_service
    (date_key, hour_key, line_key, stop_key, direction_id, departures_count)
SELECT date_key, hour_key, line_key, stop_key, direction_id, departures_count
FROM tmp_fact;

DROP TABLE tmp_service_dates, tmp_departures, tmp_fact;

ANALYZE dwh.dim_line;
ANALYZE dwh.dim_stop;
ANALYZE dwh.fact_scheduled_service;
