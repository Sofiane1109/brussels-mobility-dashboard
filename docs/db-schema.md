# Database schema

PostgreSQL database `brussels_mobility`, organised in two schemas.

| Schema    | Role |
|-----------|------|
| `staging` | Raw STIB data, loaded as-is (all columns `TEXT`, real-time responses kept as `JSONB`). |
| `dwh`     | Cleaned star schema, read by Power BI. |

## Data flow

```
GTFS zip (daily)        ─┐
                         ├─►  staging.*  ──(SQL transform)──►  dwh.dim_* / dwh.fact_*  ──►  Power BI
Vehicle Positions API  ──┘
```

## Star schema (`dwh`)

```mermaid
erDiagram
    dim_date ||--o{ fact_scheduled_service : date_key
    dim_hour ||--o{ fact_scheduled_service : hour_key
    dim_line ||--o{ fact_scheduled_service : line_key
    dim_stop ||--o{ fact_scheduled_service : stop_key

    dim_date ||--o{ fact_vehicle_snapshot : date_key
    dim_hour ||--o{ fact_vehicle_snapshot : hour_key
    dim_line ||--o{ fact_vehicle_snapshot : line_key
    dim_stop |o--o{ fact_vehicle_snapshot : direction_stop_key

    dim_mode ||--o{ dim_line : mode_key

    fact_scheduled_service {
        int date_key PK
        smallint hour_key PK
        int line_key PK
        int stop_key PK
        smallint direction_id PK
        int departures_count
    }
    fact_vehicle_snapshot {
        timestamptz snapshot_at
        int date_key FK
        smallint hour_key FK
        int line_key FK
        int direction_stop_key FK
        int vehicles_count
    }
    dim_date {
        int date_key PK
        date full_date
        text weekday_name
        text day_type
        boolean is_weekend
    }
    dim_hour {
        smallint hour_key PK
        text hour_label
        text day_period
    }
    dim_line {
        int line_key PK
        text route_id
        text line_number
        smallint mode_key FK
        text line_color
    }
    dim_stop {
        int stop_key PK
        text stop_id
        text stop_name
        numeric latitude
        numeric longitude
    }
    dim_mode {
        smallint mode_key PK
        text mode_name
    }
```

## Fact tables

| Table | Source | Grain | Measure |
|-------|--------|-------|---------|
| `fact_scheduled_service` | GTFS timetable | date × hour × line × stop × direction | `departures_count` (planned departures) |
| `fact_vehicle_snapshot` | Real-time API | snapshot × line × direction | `vehicles_count` (vehicles actually running) |

The two facts share the same dimensions, so the report can compare **planned service** with **vehicles actually on the network** for the same line and hour.

## Design choices

- **Hourly aggregation** for the timetable: one row per departure would produce tens of millions of rows per month, too heavy for Power BI in Import mode.
- **Surrogate keys** (`*_key`) for joins, STIB identifiers kept as natural keys with a `UNIQUE` constraint.
- **Times after midnight**: GTFS allows times like `25:10:00` for night services. They are moved to the next calendar day during the transformation, so `hour_key` stays between 0 and 23.
- **Raw JSON kept** in `staging.vehicle_positions_raw`: the API format can be re-parsed later without collecting again.

## Build the database

```bash
createdb brussels_mobility
cd sql
psql -d brussels_mobility -f 00_run_all.sql
```

Tested on PostgreSQL 16 (15+ required for `NULLS NOT DISTINCT`).