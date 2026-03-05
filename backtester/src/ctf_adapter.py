from pathlib import Path
import io
import pandas as pd

from .validator import validate_candles

_FALLBACK_MSG = "CTF parse unavailable; please convert/export to CSV format."
_REQUIRED_COLS = 7
_ENCODINGS = ["utf-8", "latin-1", "cp1252"]
_SEPARATORS = [",", "\t", ";", "|"]


def parse_ctf(uploaded_file) -> tuple[bool, "pd.DataFrame | None", str]:
    """Try to parse .ctf as column-delimited data.
    Returns (True, df, msg) on success or (False, None, fallback_msg)."""
    content = _read_bytes(uploaded_file)
    df = _attempt_parse(content)
    if df is None:
        return False, None, _FALLBACK_MSG

    df = _normalize_columns(df)

    ok, errors = validate_candles(df)
    if not ok:
        return False, None, _FALLBACK_MSG

    return True, df, f"CTF parsed successfully — {len(df)} rows."


def save_normalized_candles(df: pd.DataFrame, output_dir: Path) -> Path:
    """Write df to output_dir/normalized_candles.csv. Creates dirs."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    path = output_dir / "normalized_candles.csv"
    df.to_csv(path, index=False)
    return path


def _read_bytes(uploaded_file) -> bytes:
    if hasattr(uploaded_file, "read"):
        data = uploaded_file.read()
        if hasattr(uploaded_file, "seek"):
            uploaded_file.seek(0)
        return data
    return bytes(uploaded_file)


def _attempt_parse(content: bytes) -> "pd.DataFrame | None":
    """Try utf-8/latin-1/cp1252 decoding, then ,/tab/;/| separators.
    Return None if no combination yields ≥7 columns."""
    for enc in _ENCODINGS:
        try:
            text = content.decode(enc)
        except (UnicodeDecodeError, ValueError):
            continue
        for sep in _SEPARATORS:
            try:
                df = pd.read_csv(io.StringIO(text), sep=sep, engine="python")
                if len(df.columns) >= _REQUIRED_COLS and len(df) > 0:
                    return df
            except Exception:
                continue
    return None


def _normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Apply same normalization as parser.parse_candles()."""
    df = df.copy()
    df.columns = [c.strip().lower() for c in df.columns]

    rename_map = {
        "date": "timestamp",
        "time": "timestamp",
        "datetime": "timestamp",
        "sym": "symbol",
        "tf": "timeframe",
        "o": "open",
        "h": "high",
        "l": "low",
        "c": "close",
        "vol": "volume",
        "tick_volume": "volume",
    }
    df = df.rename(columns={k: v for k, v in rename_map.items() if k in df.columns})

    if "timestamp" in df.columns:
        df["timestamp"] = df["timestamp"].astype(str).str.strip()

    numeric_cols = ["open", "high", "low", "close", "volume"]
    for col in numeric_cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    return df
