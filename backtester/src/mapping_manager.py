import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

from .validator import ALLOWED_SYMBOLS

_MAPPINGS_ROOT = Path(__file__).parent.parent / "library" / "mappings"

SCHEMA_VERSION = "1.0"


def attach_mapping(indicator_id: str, signal_csv_path: "str | Path") -> dict:
    """Compute sha256 of signal CSV, write mapping JSON. Returns mapping dict."""
    signal_csv_path = Path(signal_csv_path)
    raw = signal_csv_path.read_bytes()
    sha256 = hashlib.sha256(raw).hexdigest()

    _MAPPINGS_ROOT.mkdir(parents=True, exist_ok=True)

    mapping = {
        "indicator_id": indicator_id,
        "signal_csv_path": str(signal_csv_path.resolve()),
        "signal_csv_sha256": sha256,
        "schema_version": SCHEMA_VERSION,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }

    mapping_path = _MAPPINGS_ROOT / f"{indicator_id}.json"
    with open(mapping_path, "w", encoding="utf-8") as f:
        json.dump(mapping, f, indent=2)

    return mapping


def get_mapping(indicator_id: str) -> "dict | None":
    """Read <indicator_id>.json. Returns None if not found."""
    mapping_path = _MAPPINGS_ROOT / f"{indicator_id}.json"
    if not mapping_path.exists():
        return None
    with open(mapping_path, encoding="utf-8") as f:
        return json.load(f)


def validate_mapping_csv(df: pd.DataFrame) -> tuple[bool, list[str]]:
    """Validate signal CSV for mapping attachment.
    Rules: timestamp/symbol/signal columns present, signal in {-1,0,1},
    no duplicate (timestamp,symbol), symbols in ALLOWED_SYMBOLS basket."""
    errors = []

    required = {"timestamp", "symbol", "signal"}
    missing = required - set(df.columns)
    if missing:
        errors.append(f"Missing required columns: {sorted(missing)}")
        return False, errors

    bad_symbols = set(df["symbol"].unique()) - ALLOWED_SYMBOLS
    if bad_symbols:
        errors.append(f"Unknown symbols: {sorted(bad_symbols)}. Allowed: {sorted(ALLOWED_SYMBOLS)}")

    valid_signals = {-1, 0, 1}
    signal_vals = set(df["signal"].dropna().astype(int).unique())
    bad_signals = signal_vals - valid_signals
    if bad_signals:
        errors.append(f"Invalid signal values: {sorted(bad_signals)}. Allowed: {{-1, 0, 1}}")

    dupes = df.duplicated(subset=["timestamp", "symbol"], keep=False)
    if dupes.any():
        dupe_pairs = df[dupes][["timestamp", "symbol"]].drop_duplicates().values.tolist()
        errors.append(f"Duplicate (timestamp, symbol) pairs found: {dupe_pairs[:5]}")

    return len(errors) == 0, errors
