"""Database connection shared by the collection scripts.

Connection settings are read from the .env file at the root of the repo
(see .env.example). No password is ever written in the code.
"""

import os
from pathlib import Path

import psycopg
from dotenv import load_dotenv

REPO_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(REPO_ROOT / ".env")


def get_connection() -> psycopg.Connection:
    """Open a connection to the PostgreSQL database defined in .env."""
    return psycopg.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "brussels_mobility"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
    )