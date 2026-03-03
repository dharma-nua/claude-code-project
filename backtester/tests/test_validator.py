import pandas as pd
import pytest
from src.validator import validate_candles, validate_signals, validate_alignment


def make_candles(**overrides):
    data = {
        "timestamp": ["2024-01-02", "2024-01-03"],
        "symbol": ["EURUSD", "EURUSD"],
        "timeframe": ["D1", "D1"],
        "open": [1.1040, 1.1060],
        "high": [1.1075, 1.1095],
        "low": [1.1020, 1.1045],
        "close": [1.1060, 1.1080],
        "volume": [22400, 23100],
    }
    data.update(overrides)
    return pd.DataFrame(data)


def make_signals(**overrides):
    data = {
        "timestamp": ["2024-01-02", "2024-01-03"],
        "symbol": ["EURUSD", "EURUSD"],
        "signal": [1, 0],
    }
    data.update(overrides)
    return pd.DataFrame(data)


class TestValidateCandles:
    def test_valid_candles_pass(self):
        ok, errors = validate_candles(make_candles())
        assert ok is True
        assert errors == []

    def test_invalid_symbol_rejected(self):
        df = make_candles(symbol=["INVALID", "INVALID"])
        ok, errors = validate_candles(df)
        assert ok is False
        assert any("Unknown symbols" in e for e in errors)

    def test_non_d1_timeframe_rejected(self):
        df = make_candles(timeframe=["H4", "H4"])
        ok, errors = validate_candles(df)
        assert ok is False
        assert any("Non-D1" in e for e in errors)

    def test_duplicate_timestamp_symbol_flagged(self):
        df = make_candles(
            timestamp=["2024-01-02", "2024-01-02"],
            symbol=["EURUSD", "EURUSD"],
        )
        ok, errors = validate_candles(df)
        assert ok is False
        assert any("Duplicate" in e for e in errors)

    def test_missing_required_column(self):
        df = make_candles()
        df = df.drop(columns=["close"])
        ok, errors = validate_candles(df)
        assert ok is False
        assert any("Missing" in e for e in errors)

    def test_unsorted_data_flagged(self):
        df = make_candles(
            timestamp=["2024-01-03", "2024-01-02"],
            symbol=["EURUSD", "EURUSD"],
        )
        ok, errors = validate_candles(df)
        assert ok is False
        assert any("sorted" in e for e in errors)


class TestValidateSignals:
    def test_valid_signals_pass(self):
        ok, errors = validate_signals(make_signals())
        assert ok is True
        assert errors == []

    def test_invalid_symbol_rejected(self):
        df = make_signals(symbol=["FAKEPAIR", "FAKEPAIR"])
        ok, errors = validate_signals(df)
        assert ok is False
        assert any("Unknown symbols" in e for e in errors)

    def test_signal_value_2_rejected(self):
        df = make_signals(signal=[2, 0])
        ok, errors = validate_signals(df)
        assert ok is False
        assert any("Invalid signal values" in e for e in errors)

    def test_duplicate_timestamp_symbol_in_signals_flagged(self):
        df = make_signals(
            timestamp=["2024-01-02", "2024-01-02"],
            symbol=["EURUSD", "EURUSD"],
        )
        ok, errors = validate_signals(df)
        assert ok is False
        assert any("Duplicate" in e for e in errors)

    def test_missing_required_column(self):
        df = make_signals()
        df = df.drop(columns=["signal"])
        ok, errors = validate_signals(df)
        assert ok is False
        assert any("Missing" in e for e in errors)


class TestValidateAlignment:
    def test_no_warnings_when_aligned(self):
        candles = make_candles()
        signals = make_signals()
        warnings = validate_alignment(candles, signals)
        assert warnings == []

    def test_warns_on_signal_without_candle(self):
        candles = make_candles(timestamp=["2024-01-02", "2024-01-03"])
        signals = make_signals(timestamp=["2024-01-02", "2024-01-99"])  # 99 = orphan
        warnings = validate_alignment(candles, signals)
        assert len(warnings) > 0
        assert any("no matching candle" in w for w in warnings)
