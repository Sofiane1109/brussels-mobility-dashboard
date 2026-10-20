# Brussels Mobility Dashboard

End-to-end Brussels mobility analytics: Python data collection, PostgreSQL star schema, Power BI report and a web dashboard.

> 🚧 Work in progress. See [ROADMAP.md](ROADMAP.md) for the plan.

## Goal

Answer concrete questions about the STIB public transport network using open data:

1. Which lines and stops offer the most service, and at what hours?
2. How does the planned service change between weekdays, Saturdays and Sundays?
3. How many vehicles are actually running per line compared with the timetable?
4. How is service split between metro, tram and bus?

## Architecture

```
Open data API  →  Python collection  →  PostgreSQL (staging → star schema)  →  Power BI report  →  Web dashboard
```

Database design: see [docs/db-schema.md](docs/db-schema.md).

## Tech stack

- **Collection:** Python
- **Database:** PostgreSQL (SQL: CTE, window functions, views)
- **BI:** Power BI Desktop (data model, DAX)
- **Web:** HTML/CSS/JS or React, deployed on Vercel / Netlify / GitHub Pages

## Repository structure

```
collecte/   Python collection scripts
sql/        Schema, staging, transformations, views, analysis queries
powerbi/    .pbix file, screenshots, main DAX measures
site/       Web dashboard source code
docs/       Architecture diagram and documentation
```

## Getting started

Requirements: PostgreSQL 15+, Python 3.10+.

```bash
# 1. Configuration
cp .env.example .env            # then fill in your PostgreSQL user and password

# 2. Database structure
createdb brussels_mobility
cd sql && psql -d brussels_mobility -f 00_run_all.sql && cd ..

# 3. Python dependencies
python -m venv .venv
source .venv/bin/activate       # Windows: .venv\Scripts\activate
pip install -r collecte/requirements.txt

# 4. Load the STIB timetable (download + staging + star schema)
python collecte/load_gtfs.py
```

If the download fails, download the GTFS zip manually from the
[Belgian Mobility Open Data Portal](https://data.belgianmobility.io/en/data.html) and run
`python collecte/load_gtfs.py --file path/to/gtfs.zip` (a folder with the unzipped files also works).

```bash
# 5. Collect real-time vehicle positions
python collecte/collect_vehicles.py            # one snapshot
python collecte/collect_vehicles.py --loop     # one snapshot every 15 minutes
```

Then open the report in `powerbi/` and point it to your database.

## Data source and license

Data from **STIB-MIVB Open Data** via the [Belgian Mobility Open Data Portal](https://data.belgianmobility.io/), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

- GTFS static timetable (refreshed daily)
- Real-time Vehicle Positions API

Source: STIB-MIVB – Open Data – _date of dataset update_

## Live demo

_Link to the deployed site and the published Power BI report (to be added)._

## License

MIT, see [LICENSE](LICENSE).