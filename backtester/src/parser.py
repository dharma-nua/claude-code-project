import pandas as pd
import io


def parse_candles(uploaded_file) -> pd.DataFrame:
    """Parse candles CSV. Expects: timestamp, symbol, timeframe, open, high, low, close, volume."""
    if hasattr(uploaded_file, "read"):
        content = uploaded_file.read()
        if isinstance(content, bytes):
            content = content.decode("utf-8")
        df = pd.read_csv(io.StringIO(content))
    else:
        df = pd.read_csv(uploaded_file)

    df.columns = [c.strip().lower() for c in df.columns]

    # Normalize timestamp to date string
    if "timestamp" in df.columns:
        df["timestamp"] = pd.to_datetime(df["timestamp"]).dt.strftime("%Y-%m-%d")

    # Normalize symbol to uppercase
    if "symbol" in df.columns:
        df["symbol"] = df["symbol"].astype(str).str.strip().str.upper()

    # Normalize timeframe
    if "timeframe" in df.columns:
        df["timeframe"] = df["timeframe"].astype(str).str.strip().str.upper()

    # Coerce numeric columns
    for col in ["open", "high", "low", "close", "volume"]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    return df


def parse_signals(uploaded_file) -> pd.DataFrame:
    """Parse signals CSV. Expects: timestamp, symbol, signal."""
    if hasattr(uploaded_file, "read"):
        content = uploaded_file.read()
        if isinstance(content, bytes):
            content = content.decode("utf-8")
        df = pd.read_csv(io.StringIO(content))
    else:
        df = pd.read_csv(uploaded_file)

    df.columns = [c.strip().lower() for c in df.columns]

    # Normalize timestamp to date string
    if "timestamp" in df.columns:
        df["timestamp"] = pd.to_datetime(df["timestamp"]).dt.strftime("%Y-%m-%d")

    # Normalize symbol to uppercase
    if "symbol" in df.columns:
        df["symbol"] = df["symbol"].astype(str).str.strip().str.upper()

    # Coerce signal to int
    if "signal" in df.columns:
        df["signal"] = pd.to_numeric(df["signal"], errors="coerce").astype("Int64")

    return df
