-- =============================================================
-- 06_transform_vehicles.sql
-- Parses the raw real-time API responses (staging.vehicle_positions_raw)
-- into dwh.fact_vehicle_snapshot.
-- Run automatically by collecte/collect_vehicles.py.
-- Safe to re-run: snapshots already in the fact table are skipped.
--
-- API format (one row per line):
--   {"results": [{"lineid": "39",
--                 "vehiclepositions": "[{\"directionId\":\"8733\",
--                                         \"distanceFromPoint\":0,
--                                         \"pointId\":\"5759\"}, ...]"}],
--    "totalCount": 72}
-- "vehiclepositions" is a JSON array stored as a STRING, so it
-- has to be parsed a second time.
-- =============================================================

WITH new_raw AS (
    -- responses not yet transformed
    SELECT date_trunc('second', r.collected_at) AS snapshot_at, r.payload
    FROM staging.vehicle_positions_raw AS r
    WHERE NOT EXISTS (
        SELECT 1 FROM dwh.fact_vehicle_snapshot AS f
        WHERE f.snapshot_at = date_trunc('second', r.collected_at)
    )
),
lines AS (
    -- one row per line and per snapshot
    SELECT
        n.snapshot_at,
        trim(res ->> 'lineid') AS lineid,
        CASE jsonb_typeof(res -> 'vehiclepositions')
            WHEN 'string' THEN (res ->> 'vehiclepositions')::JSONB
            ELSE res -> 'vehiclepositions'
        END AS positions
    FROM new_raw AS n
    CROSS JOIN LATERAL jsonb_array_elements(n.payload -> 'results') AS res
),
vehicles AS (
    -- one row per vehicle
    SELECT
        l.snapshot_at,
        l.lineid,
        trim(v ->> 'directionId') AS direction_code
    FROM lines AS l
    CROSS JOIN LATERAL jsonb_array_elements(
        CASE WHEN jsonb_typeof(l.positions) = 'array' THEN l.positions ELSE '[]'::JSONB END
    ) AS v
),
line_map AS (
    -- the API "lineid" is the public line number (GTFS route_short_name)
    SELECT DISTINCT ON (line_number) line_number, line_key
    FROM dwh.dim_line
    ORDER BY line_number, line_key
),
stop_map AS (
    -- the API "directionId" is the stop code of the terminus.
    -- Exact match first, then the GTFS stop_id without its letters
    -- (e.g. GTFS "5759F" -> "5759").
    SELECT DISTINCT ON (code) code, stop_key
    FROM (
        SELECT stop_id AS code, stop_key, 0 AS priority FROM dwh.dim_stop
        UNION ALL
        SELECT regexp_replace(stop_id, '[^0-9]', '', 'g'), stop_key, 1 FROM dwh.dim_stop
    ) AS codes
    WHERE code <> ''
    ORDER BY code, priority, stop_key
)
INSERT INTO dwh.fact_vehicle_snapshot
    (snapshot_at, date_key, hour_key, line_key, direction_stop_key, vehicles_count)
SELECT
    v.snapshot_at,
    to_char(v.snapshot_at AT TIME ZONE 'Europe/Brussels', 'YYYYMMDD')::INTEGER,
    EXTRACT(HOUR FROM v.snapshot_at AT TIME ZONE 'Europe/Brussels')::SMALLINT,
    lm.line_key,
    sm.stop_key,
    count(*)
FROM vehicles AS v
JOIN line_map      AS lm ON lm.line_number = v.lineid
LEFT JOIN stop_map AS sm ON sm.code = v.direction_code
GROUP BY 1, 2, 3, 4, 5
ON CONFLICT DO NOTHING;