import io
import pytest
import pandas as pd
from src.parser import parse_candles, parse_signals


VALID_CANDLES_CSV = """timestamp,symbol,timeframe,open,high,low,close,volume
2024-01-02,EURUSD,D1,1.1040,1.1075,1.1020,1.1060,22400
2024-01-02,EURGBP,D1,0.8590,0.8615,0.8575,0.8605,15300
"""

VALID_SIGNALS_CSV = """timestamp,symbol,signal
2024-01-02,EURUSD,1
2024-01-02,EURGBP,-1
"""


def make_file(content: str):
    return io.StringIO(content)


class TestParseCandles:
    def test_valid_csv_parses_correctly(self):
        df = parse_candles(make_file(VALID_CANDLES_CSV))
        assert len(df) == 2
        assert list(df.columns) == ["timestamp", "symbol", "timeframe", "open", "high", "low", "close", "volume"]
        assert df["symbol"].iloc[0] == "EURUSD"
        assert df["close"].dtype in [float, "float64"]

    def test_timestamp_normalized_to_date_string(self):
        df = parse_candles(make_file(VALID_CANDLES_CSV))
        assert df["timestamp"].iloc[0] == "2024-01-02"

    def test_symbol_uppercased(self):
        csv = "timestamp,symbol,timeframe,open,high,low,close,volume\n2024-01-02,eurusd,D1,1.1040,1.1075,1.1020,1.1060,22400\n"
        df = parse_candles(make_file(csv))
        assert df["symbol"].iloc[0] == "EURUSD"

    def test_missing_columns_readable(self):
        # parse_candles should still return a df; validator will catch missing columns
        csv = "timestamp,symbol,open\n2024-01-02,EURUSD,1.104\n"
        df = parse_candles(make_file(csv))
        assert "timestamp" in df.columns
        assert "close" not in df.columns

    def test_bad_numeric_coerced_to_nan(self):
        csv = "timestamp,symbol,timeframe,open,high,low,close,volume\n2024-01-02,EURUSD,D1,bad,1.1075,1.1020,1.1060,22400\n"
        df = parse_candles(make_file(csv))
        assert pd.isna(df["open"].iloc[0])


class TestParseSignals:
    def test_valid_csv_parses_correctly(self):
        df = parse_signals(make_file(VALID_SIGNALS_CSV))
        assert len(df) == 2
        assert "signal" in df.columns
        assert int(df["signal"].iloc[0]) == 1

    def test_signal_coerced_to_int(self):
        csv = "timestamp,symbol,signal\n2024-01-02,EURUSD,1.0\n"
        df = parse_signals(make_file(csv))
        assert int(df["signal"].iloc[0]) == 1

    def test_timestamp_normalized_to_date_string(self):
        df = parse_signals(make_file(VALID_SIGNALS_CSV))
        assert df["timestamp"].iloc[0] == "2024-01-02"

    def test_bad_signal_coerced_to_nan(self):
        csv = "timestamp,symbol,signal\n2024-01-02,EURUSD,xyz\n"
        df = parse_signals(make_file(csv))
        assert pd.isna(df["signal"].iloc[0])
