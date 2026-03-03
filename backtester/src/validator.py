import pandas as pd

ALLOWED_SYMBOLS = {"EURUSD", "EURGBP", "AUDNZD", "AUDCAD", "CHFJPY"}
ALLOWED_TIMEFRAME = "D1"
ALLOWED_SIGNALS = {-1, 0, 1}

CANDLE_REQUIRED_COLUMNS = {"timestamp", "symbol", "timeframe", "open", "high", "low", "close", "volume"}
SIGNAL_REQUIRED_COLUMNS = {"timestamp", "symbol", "signal"}


def validate_candles(df: pd.DataFrame) -> tuple[bool, list[str]]:
    """Validate candles DataFrame. Returns (is_valid, list_of_errors)."""
    errors = []

    # Check required columns
    missing = CANDLE_REQUIRED_COLUMNS - set(df.columns)
    if missing:
        errors.append(f"Missing required columns: {sorted(missing)}")
        return False, errors

    # Check allowed symbols
    bad_symbols = set(df["symbol"].unique()) - ALLOWED_SYMBOLS
    if bad_symbols:
        errors.append(f"Unknown symbols found: {sorted(bad_symbols)}. Allowed: {sorted(ALLOWED_SYMBOLS)}")

    # Check timeframe is D1 only
    bad_tf = set(df["timeframe"].unique()) - {ALLOWED_TIMEFRAME}
    if bad_tf:
        errors.append(f"Non-D1 timeframes found: {sorted(bad_tf)}. Only D1 is supported.")

    # Check no duplicate (timestamp, symbol) pairs
    dupes = df.duplicated(subset=["timestamp", "symbol"], keep=False)
    if dupes.any():
        dupe_pairs = df[dupes][["timestamp", "symbol"]].drop_duplicates().values.tolist()
        errors.append(f"Duplicate (timestamp, symbol) pairs found: {dupe_pairs[:5]}")

    # Check sorted order (by timestamp then symbol)
    sorted_df = df.sort_values(["timestamp", "symbol"])
    if not df[["timestamp", "symbol"]].equals(sorted_df[["timestamp", "symbol"]].reset_index(drop=True)):
        errors.append("Candles are not sorted by (timestamp, symbol). Please sort before uploading.")

    is_valid = len(errors) == 0
    return is_valid, errors


def validate_signals(df: pd.DataFrame) -> tuple[bool, list[str]]:
    """Validate signals DataFrame. Returns (is_valid, list_of_errors)."""
    errors = []

    # Check required columns
    missing = SIGNAL_REQUIRED_COLUMNS - set(df.columns)
    if missing:
        errors.append(f"Missing required columns: {sorted(missing)}")
        return False, errors

    # Check allowed symbols
    bad_symbols = set(df["symbol"].unique()) - ALLOWED_SYMBOLS
    if bad_symbols:
        errors.append(f"Unknown symbols found: {sorted(bad_symbols)}. Allowed: {sorted(ALLOWED_SYMBOLS)}")

    # Check signal values
    signal_vals = set(df["signal"].dropna().astype(int).unique())
    bad_signals = signal_vals - ALLOWED_SIGNALS
    if bad_signals:
        errors.append(f"Invalid signal values found: {sorted(bad_signals)}. Allowed: {{-1, 0, 1}}")

    # Check no duplicate (timestamp, symbol) pairs
    dupes = df.duplicated(subset=["timestamp", "symbol"], keep=False)
    if dupes.any():
        dupe_pairs = df[dupes][["timestamp", "symbol"]].drop_duplicates().values.tolist()
        errors.append(f"Duplicate (timestamp, symbol) pairs found: {dupe_pairs[:5]}")

    is_valid = len(errors) == 0
    return is_valid, errors


def validate_alignment(candles_df: pd.DataFrame, signals_df: pd.DataFrame) -> list[str]:
    """Warn on timestamps present in signals but not in candles."""
    warnings = []

    candle_keys = set(zip(candles_df["timestamp"], candles_df["symbol"]))
    signal_keys = set(zip(signals_df["timestamp"], signals_df["symbol"]))

    orphan_signals = signal_keys - candle_keys
    if orphan_signals:
        sample = sorted(list(orphan_signals))[:5]
        warnings.append(
            f"{len(orphan_signals)} signal(s) have no matching candle bar "
            f"(e.g. {sample}). These will be ignored."
        )

    return warnings
