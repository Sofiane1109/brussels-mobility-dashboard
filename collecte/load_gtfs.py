"""Load the STIB GTFS timetable into PostgreSQL.

Steps:
  1. Download the GTFS zip (or use a zip already on disk with --file).
  2. Load each GTFS file into its staging table (staging.gtfs_*).
  3. Run sql/05_transform_gtfs.sql to fill the star schema (dwh.*).

Usage (from the repo root):
    python collecte/load_gtfs.py                   # download, then load
    python collecte/load_gtfs.py --file gtfs.zip   # use a zip you downloaded yourself
    python collecte/load_gtfs.py --file data       # use a folder with the unzipped .txt files
"""

import argparse
import csv
import io
import os
import sys
import time
import zipfile
from pathlib import Path

import requests

from db import REPO_ROOT, get_connection

DEFAULT_GTFS_URL = (
    "https://stibmivb.opendatasoft.com/api/datasets/1.0/"
    "gtfs-files-production/alternative_exports/gtfszip/"
)
DATA_DIR = REPO_ROOT / "data"           # ignored by Git
TRANSFORM_SQL = REPO_ROOT / "sql" / "05_transform_gtfs.sql"

# GTFS file -> staging table
GTFS_FILES = {
    "routes.txt": "gtfs_routes",
    "stops.txt": "gtfs_stops",
    "trips.txt": "gtfs_trips",
    "stop_times.txt": "gtfs_stop_times",
    "calendar.txt": "gtfs_calendar",
    "calendar_dates.txt": "gtfs_calendar_dates",
}


def download_gtfs(url: str) -> Path:
    """Download the GTFS zip into data/ and return its path."""
    DATA_DIR.mkdir(exist_ok=True)
    target = DATA_DIR / "gtfs_stib.zip"
    print(f"Downloading GTFS from {url}")
    with requests.get(url, stream=True, timeout=120) as response:
        response.raise_for_status()
        with open(target, "wb") as f:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                f.write(chunk)
    print(f"  saved to {target} ({target.stat().st_size / 1e6:.1f} MB)")
    return target


def staging_columns(cur, table: str) -> list[str]:
    """Return the column names of a staging table (except loaded_at)."""
    cur.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'staging' AND table_name = %s
          AND column_name <> 'loaded_at'
        ORDER BY ordinal_position
        """,
        (table,),
    )
    return [row[0] for row in cur.fetchall()]


class GtfsSource:
    """Gives access to the GTFS files, from a zip or from an unzipped folder."""

    def __init__(self, path: Path):
        self.path = path
        self.archive = zipfile.ZipFile(path) if path.is_file() else None
        if self.archive is None and not path.is_dir():
            raise FileNotFoundError(f"{path} is neither a zip file nor a folder")

    def names(self) -> set[str]:
        if self.archive:
            return set(self.archive.namelist())
        return {p.name for p in self.path.iterdir() if p.is_file()}

    def open(self, filename: str):
        if self.archive:
            return self.archive.open(filename)
        return open(self.path / filename, "rb")

    def close(self) -> None:
        if self.archive:
            self.archive.close()


def load_file(cur, source: GtfsSource, filename: str, table: str) -> int:
    """Empty the staging table, then copy the GTFS file into it.

    Only the columns that exist in both the file and the table are loaded,
    so extra or missing optional GTFS columns do not break the load.
    """
    with source.open(filename) as raw:
        # utf-8-sig removes the BOM some GTFS producers add
        reader = csv.reader(io.TextIOWrapper(raw, encoding="utf-8-sig", newline=""))
        header = [h.strip() for h in next(reader)]

        table_cols = staging_columns(cur, table)
        common = [c for c in header if c in table_cols]
        if not common:
            raise ValueError(f"{filename}: no column matches staging.{table}")
        positions = [header.index(c) for c in common]

        cur.execute(f"TRUNCATE staging.{table}")
        count = 0
        cols_sql = ", ".join(common)
        with cur.copy(f"COPY staging.{table} ({cols_sql}) FROM STDIN") as copy:
            for row in reader:
                if not row:
                    continue
                copy.write_row([row[i] if i < len(row) else None for i in positions])
                count += 1
    return count


def main() -> int:
    parser = argparse.ArgumentParser(description="Load the STIB GTFS into PostgreSQL")
    parser.add_argument(
        "--file", type=Path,
        help="GTFS zip already downloaded, or folder containing the unzipped .txt files",
    )
    args = parser.parse_args()

    gtfs_path = args.file or download_gtfs(os.getenv("GTFS_URL", DEFAULT_GTFS_URL))
    source = GtfsSource(gtfs_path)
    start = time.time()

    with get_connection() as conn, conn.cursor() as cur:
        available = source.names()

        print("Loading staging tables")
        for filename, table in GTFS_FILES.items():
            if filename not in available:
                # calendar.txt or calendar_dates.txt can be missing in a valid GTFS
                print(f"  {filename:<20} missing, skipped")
                cur.execute(f"TRUNCATE staging.{table}")
                continue
            n = load_file(cur, source, filename, table)
            print(f"  {filename:<20} {n:>10,} rows -> staging.{table}")

        print("Transforming staging -> dwh")
        cur.execute(TRANSFORM_SQL.read_text(encoding="utf-8"))

        for table in ("dim_line", "dim_stop", "fact_scheduled_service"):
            cur.execute(f"SELECT count(*) FROM dwh.{table}")
            print(f"  dwh.{table:<24} {cur.fetchone()[0]:>10,} rows")

    # leaving the "with" block commits the transaction:
    # if anything fails above, nothing is written to the database
    source.close()
    print(f"Done in {time.time() - start:.0f} s")
    return 0


if __name__ == "__main__":
    sys.exit(main())