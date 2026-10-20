"""Collect the positions of STIB vehicles from the real-time API.

Each run:
  1. Calls the Vehicle Positions API once.
  2. Stores the raw JSON response in staging.vehicle_positions_raw.
  3. Runs sql/06_transform_vehicles.sql to fill dwh.fact_vehicle_snapshot.

Usage (from the repo root, with the venv activated):
    python collecte/collect_vehicles.py                  # one snapshot
    python collecte/collect_vehicles.py --loop           # one snapshot every 15 min, Ctrl+C to stop
    python collecte/collect_vehicles.py --loop --interval 600

Without an API key, the API allows 100 requests per day and 10 per minute:
one call every 15 minutes (96 per day) stays under the limit.
"""

import argparse
import json
import os
import sys
import time
from datetime import datetime

import requests
from psycopg.types.json import Jsonb

from db import REPO_ROOT, get_connection

DEFAULT_URL = (
    "https://api-management-discovery-production.azure-api.net"
    "/api/datasets/stibmivb/rt/VehiclePositions"
)
TRANSFORM_SQL = REPO_ROOT / "sql" / "06_transform_vehicles.sql"
MIN_INTERVAL = 900  # seconds, keeps anonymous use under 100 requests per day


def fetch_positions() -> dict:
    """Call the API and return the decoded JSON."""
    headers = {"Accept": "application/json"}
    api_key = os.getenv("STIB_API_KEY", "")
    if api_key and api_key != "your_api_key":
        # Azure API Management header (check the name in the developer portal)
        headers["Ocp-Apim-Subscription-Key"] = api_key

    url = os.getenv("VEHICLE_POSITIONS_URL", DEFAULT_URL)
    response = requests.get(url, headers=headers, timeout=30)
    if response.status_code == 429:
        raise RuntimeError("Rate limit reached (429). Wait before the next call.")
    response.raise_for_status()
    return response.json()


def collect_once() -> None:
    payload = fetch_positions()
    results = payload.get("results", [])
    api_lines = {str(r.get("lineid", "")).strip() for r in results}

    with get_connection() as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO staging.vehicle_positions_raw (payload) VALUES (%s)",
            (Jsonb(payload),),
        )
        cur.execute(TRANSFORM_SQL.read_text(encoding="utf-8"))
        inserted = cur.rowcount

        cur.execute(
            """
            SELECT coalesce(sum(vehicles_count), 0)
            FROM dwh.fact_vehicle_snapshot
            WHERE snapshot_at = (SELECT max(snapshot_at) FROM dwh.fact_vehicle_snapshot)
            """
        )
        vehicles = cur.fetchone()[0]

        cur.execute("SELECT line_number FROM dwh.dim_line")
        known = {row[0] for row in cur.fetchall()}

    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{now}] {len(results)} lines, {vehicles} vehicles, {inserted} rows added")
    unknown = sorted(api_lines - known)
    if unknown:
        # lines sent by the API but missing from the GTFS: they are skipped
        print(f"  lines not found in dim_line (skipped): {', '.join(unknown)}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Collect STIB vehicle positions")
    parser.add_argument("--loop", action="store_true", help="collect again and again until Ctrl+C")
    parser.add_argument("--interval", type=int, default=MIN_INTERVAL,
                        help=f"seconds between two calls in --loop mode (default {MIN_INTERVAL})")
    args = parser.parse_args()

    if not args.loop:
        collect_once()
        return 0

    print(f"Collecting every {args.interval} s. Press Ctrl+C to stop.")
    while True:
        try:
            collect_once()
        except KeyboardInterrupt:
            raise
        except Exception as error:  # keep the loop alive on network errors
            print(f"  error: {error}")
        try:
            time.sleep(args.interval)
        except KeyboardInterrupt:
            print("Stopped.")
            return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("Stopped.")
        sys.exit(0)