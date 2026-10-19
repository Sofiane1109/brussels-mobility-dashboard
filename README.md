# Brussels Mobility Dashboard

End-to-end Brussels mobility analytics: Python data collection, PostgreSQL star schema, Power BI report and a web dashboard.

> 🚧 Work in progress. See [ROADMAP.md](ROADMAP.md) for the plan.

## Goal

Answer concrete questions about mobility in Brussels using open data:

1. _Question 1 (to define)_
2. _Question 2 (to define)_
3. _Question 3 (to define)_

## Architecture

```
Open data API  →  Python collection  →  PostgreSQL (staging → star schema)  →  Power BI report  →  Web dashboard
```

_Architecture diagram to be added in `docs/`._

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

1. Clone the repo and copy `.env.example` to `.env`, then fill in your values.
2. Create the database and run the scripts in `sql/`.
3. Run the collection scripts in `collecte/`.
4. Open the report in `powerbi/` and point it to your database.

_Detailed instructions to be completed._

## Data source and license

_Source name, link and license of the open data used (to be completed)._

## Live demo

_Link to the deployed site and the published Power BI report (to be added)._

## License

MIT, see [LICENSE](LICENSE).
