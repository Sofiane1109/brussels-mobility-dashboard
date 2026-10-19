-- =============================================================
-- 03_dimensions.sql
-- Dimension tables of the star schema.
-- Surrogate keys (*_key) are used for joins; the STIB identifiers
-- are kept as natural keys with a UNIQUE constraint.
-- =============================================================

-- ---------- dim_date : one row per calendar day ----------
DROP TABLE IF EXISTS dwh.dim_date CASCADE;
CREATE TABLE dwh.dim_date (
    date_key      INTEGER     PRIMARY KEY,           -- YYYYMMDD, e.g. 20261019
    full_date     DATE        NOT NULL UNIQUE,
    year          SMALLINT    NOT NULL,
    quarter       SMALLINT    NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    month         SMALLINT    NOT NULL CHECK (month BETWEEN 1 AND 12),
    month_name    TEXT        NOT NULL,              -- French label
    day_of_month  SMALLINT    NOT NULL,
    iso_weekday   SMALLINT    NOT NULL CHECK (iso_weekday BETWEEN 1 AND 7), -- 1 = Monday
    weekday_name  TEXT        NOT NULL,              -- French label
    iso_week      SMALLINT    NOT NULL,
    is_weekend    BOOLEAN     NOT NULL,
    day_type      TEXT        NOT NULL               -- 'Semaine', 'Samedi', 'Dimanche'
);

-- ---------- dim_hour : one row per hour of the day ----------
DROP TABLE IF EXISTS dwh.dim_hour CASCADE;
CREATE TABLE dwh.dim_hour (
    hour_key     SMALLINT PRIMARY KEY CHECK (hour_key BETWEEN 0 AND 23),
    hour_label   TEXT     NOT NULL,                  -- '07h'
    day_period   TEXT     NOT NULL,                  -- 'Pointe du matin', ...
    period_order SMALLINT NOT NULL                   -- to sort periods in Power BI
);

-- ---------- dim_mode : tram, metro, bus ----------
DROP TABLE IF EXISTS dwh.dim_mode CASCADE;
CREATE TABLE dwh.dim_mode (
    mode_key   SMALLINT PRIMARY KEY,                 -- GTFS route_type
    mode_name  TEXT     NOT NULL UNIQUE
);

-- ---------- dim_line : one row per STIB line ----------
DROP TABLE IF EXISTS dwh.dim_line CASCADE;
CREATE TABLE dwh.dim_line (
    line_key        SERIAL   PRIMARY KEY,
    route_id        TEXT     NOT NULL UNIQUE,        -- natural key from GTFS
    line_number     TEXT     NOT NULL,               -- '1', '92', 'N04' ...
    line_name       TEXT,
    mode_key        SMALLINT NOT NULL REFERENCES dwh.dim_mode (mode_key),
    line_color      TEXT,                            -- hex without '#'
    line_text_color TEXT
);

CREATE INDEX ix_dim_line_line_number ON dwh.dim_line (line_number);

-- ---------- dim_stop : one row per stop ----------
DROP TABLE IF EXISTS dwh.dim_stop CASCADE;
CREATE TABLE dwh.dim_stop (
    stop_key        SERIAL        PRIMARY KEY,
    stop_id         TEXT          NOT NULL UNIQUE,   -- natural key from GTFS
    stop_name       TEXT          NOT NULL,
    latitude        NUMERIC(9,6)  CHECK (latitude  BETWEEN -90  AND 90),
    longitude       NUMERIC(9,6)  CHECK (longitude BETWEEN -180 AND 180),
    parent_station  TEXT                             -- groups platforms of one station
);

-- =============================================================
-- Fill the dimensions that do not depend on STIB data
-- =============================================================

-- dim_date : 2026-01-01 to 2027-12-31 (extend if needed)
INSERT INTO dwh.dim_date
SELECT
    to_char(d, 'YYYYMMDD')::INTEGER,
    d::DATE,
    EXTRACT(YEAR    FROM d),
    EXTRACT(QUARTER FROM d),
    EXTRACT(MONTH   FROM d),
    (ARRAY['janvier','février','mars','avril','mai','juin','juillet',
           'août','septembre','octobre','novembre','décembre'])[EXTRACT(MONTH FROM d)],
    EXTRACT(DAY     FROM d),
    EXTRACT(ISODOW  FROM d),
    (ARRAY['lundi','mardi','mercredi','jeudi','vendredi','samedi','dimanche'])[EXTRACT(ISODOW FROM d)],
    EXTRACT(WEEK    FROM d),
    EXTRACT(ISODOW  FROM d) IN (6, 7),
    CASE EXTRACT(ISODOW FROM d)
        WHEN 6 THEN 'Samedi'
        WHEN 7 THEN 'Dimanche'
        ELSE 'Semaine'
    END
FROM generate_series(DATE '2026-01-01', DATE '2027-12-31', INTERVAL '1 day') AS d;

-- dim_hour : 24 rows with a day period
INSERT INTO dwh.dim_hour
SELECT
    h,
    lpad(h::TEXT, 2, '0') || 'h',
    p.day_period,
    p.period_order
FROM generate_series(0, 23) AS h
CROSS JOIN LATERAL (
    SELECT
        CASE
            WHEN h BETWEEN 0  AND 5  THEN 'Nuit'
            WHEN h = 6               THEN 'Début de matinée'
            WHEN h BETWEEN 7  AND 9  THEN 'Pointe du matin'
            WHEN h BETWEEN 10 AND 15 THEN 'Journée'
            WHEN h BETWEEN 16 AND 18 THEN 'Pointe du soir'
            ELSE 'Soirée'
        END AS day_period,
        CASE
            WHEN h BETWEEN 0  AND 5  THEN 1
            WHEN h = 6               THEN 2
            WHEN h BETWEEN 7  AND 9  THEN 3
            WHEN h BETWEEN 10 AND 15 THEN 4
            WHEN h BETWEEN 16 AND 18 THEN 5
            ELSE 6
        END AS period_order
) AS p;

-- dim_mode : GTFS route_type codes used by STIB
INSERT INTO dwh.dim_mode (mode_key, mode_name) VALUES
    (0, 'Tram'),
    (1, 'Métro'),
    (3, 'Bus');