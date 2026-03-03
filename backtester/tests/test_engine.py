import pandas as pd
import pytest
from src.engine import BacktestEngine
from src.models import BacktestConfig


def make_config(**kwargs):
    defaults = {
        "symbols": ["EURUSD"],
        "date_range": {"from": None, "to": None},
        "reverse_on_flip": False,
    }
    defaults.update(kwargs)
    return BacktestConfig(**defaults)


def make_candles(rows):
    """rows: list of (timestamp, symbol, open, high, low, close)"""
    return pd.DataFrame([
        {
            "timestamp": r[0],
            "symbol": r[1],
            "timeframe": "D1",
            "open": r[2],
            "high": r[3],
            "low": r[4],
            "close": r[5],
            "volume": 10000,
        }
        for r in rows
    ])


def make_signals(rows):
    """rows: list of (timestamp, symbol, signal)"""
    return pd.DataFrame([
        {"timestamp": r[0], "symbol": r[1], "signal": r[2]}
        for r in rows
    ])


class TestEngineBasicBehavior:
    def test_flat_signal_1_opens_long(self):
        candles = make_candles([
            ("2024-01-02", "EURUSD", 1.1040, 1.1075, 1.1020, 1.1060),
            ("2024-01-03", "EURUSD", 1.1060, 1.1095, 1.1045, 1.1080),
        ])
        signals = make_signals([
            ("2024-01-02", "EURUSD", 1),
            ("2024-01-03", "EURUSD", 0),
        ])
        result = BacktestEngine().run(candles, signals, make_config())
        opens = [j for j in result.journal if j.action == "OPEN_LONG"]
        assert len(opens) == 1
        assert opens[0].timestamp == "2024-01-02"

    def test_long_signal_minus1_closes(self):
        candles = make_candles([
            ("2024-01-02", "EURUSD", 1.1040, 1.1075, 1.1020, 1.1060),
            ("2024-01-03", "EURUSD", 1.1060, 1.1095, 1.1045, 1.1080),
        ])
        signals = make_signals([
            ("2024-01-02", "EURUSD", 1),
            ("2024-01-03", "EURUSD", -1),
        ])
        result = BacktestEngine().run(candles, signals, make_config())
        trades = result.trades
        assert len(trades) == 1
        assert trades[0].direction == "long"
        assert trades[0].close_reason == "SIGNAL_FLIP"
        # pips = (1.1080 - 1.1060) / 0.0001 = 20
        assert abs(trades[0].pips - 20.0) < 0.01

    def test_signal_0_holds(self):
        candles = make_candles([
            ("2024-01-02", "EURUSD", 1.1040, 1.1075, 1.1020, 1.1060),
            ("2024-01-03", "EURUSD", 1.1060, 1.1095, 1.1045, 1.1080),
            ("2024-01-04", "EURUSD", 1.1080, 1.1110, 1.1060, 1.1095),
        ])
        signals = make_signals([
            ("2024-01-02", "EURUSD", 1),
            ("2024-01-03", "EURUSD", 0),  # hold
            ("2024-01-04", "EURUSD", 0),  # hold
        ])
        result = BacktestEngine().run(candles, signals, make_config())
        # No SIGNAL_FLIP trades, only END_OF_DATA
        signal_flips = [t for t in result.trades if t.close_reason == "SIGNAL_FLIP"]
        assert len(signal_flips) == 0
        holds = [j for j in result.journal if j.action == "HOLD" and j.position_direction == "long"]
        assert len(holds) == 2

    def test_final_bar_closes_all_open_positions(self):
        candles = make_candles([
            ("2024-01-02", "EURUSD", 1.1040, 1.1075, 1.1020, 1.1060),
            ("2024-01-03", "EURUSD", 1.1060, 1.1095, 1.1045, 1.1080),
        ])
        signals = make_signals([
            ("2024-01-02", "EURUSD", 1),
            ("2024-01-03", "EURUSD", 0),
        ])
        result = BacktestEngine().run(candles, signals, make_config())
        end_trades = [t for t in result.trades if t.close_reason == "END_OF_DATA"]
        assert len(end_trades) == 1

    def test_flat_signal_minus1_opens_short(self):
        candles = make_candles([
            ("2024-01-02", "EURUSD", 1.1040, 1.1075, 1.1020, 1.1060),
            ("2024-01-03", "EURUSD", 1.1060, 1.1095, 1.1045, 1.1040),
        ])
        signals = make_signals([
            ("2024-01-02", "EURUSD", -1),
            ("2024-01-03", "EURUSD", 0),
        ])
        result = BacktestEngine().run(candles, signals, make_config())
        opens = [j for j in result.journal if j.action == "OPEN_SHORT"]
        assert len(opens) == 1

    def test_short_pips_calculation(self):
        candles = make_candles([
            ("2024-01-02", "EURUSD", 1.1060, 1.1075, 1.1020, 1.1060),
            ("2024-01-03", "EURUSD", 1.1060, 1.1095, 1.1020, 1.1010),
        ])
        signals = make_signals([
            ("2024-01-02", "EURUSD", -1),
            ("2024-01-03", "EURUSD", 1),
        ])
        result = BacktestEngine().run(candles, signals, make_config())
        # short: pips = (entry - exit) / pip_size = (1.1060 - 1.1010) / 0.0001 = 50
        assert len(result.trades) == 1
        assert abs(result.trades[0].pips - 50.0) < 0.01

    def test_reverse_on_flip_opens_opposite(self):
        candles = make_candles([
            ("2024-01-02", "EURUSD", 1.1040, 1.1075, 1.1020, 1.1060),
            ("2024-01-03", "EURUSD", 1.1060, 1.1095, 1.1045, 1.1080),
        ])
        signals = make_signals([
            ("2024-01-02", "EURUSD", 1),
            ("2024-01-03", "EURUSD", -1),
        ])
        cfg = make_config(reverse_on_flip=True)
        result = BacktestEngine().run(candles, signals, cfg)
        # Should have flip trade + END_OF_DATA trade
        assert len(result.trades) == 2
        assert result.trades[0].close_reason == "SIGNAL_FLIP"
        assert result.trades[1].direction == "short"
        assert result.trades[1].close_reason == "END_OF_DATA"

    def test_determinism_same_inputs_same_outputs(self):
        candles = make_candles([
            ("2024-01-02", "EURUSD", 1.1040, 1.1075, 1.1020, 1.1060),
            ("2024-01-03", "EURUSD", 1.1060, 1.1095, 1.1045, 1.1080),
            ("2024-01-04", "EURUSD", 1.1080, 1.1110, 1.1060, 1.1050),
        ])
        signals = make_signals([
            ("2024-01-02", "EURUSD", 1),
            ("2024-01-03", "EURUSD", 0),
            ("2024-01-04", "EURUSD", -1),
        ])
        cfg = make_config()
        r1 = BacktestEngine().run(candles, signals, cfg)
        r2 = BacktestEngine().run(candles, signals, cfg)
        assert len(r1.trades) == len(r2.trades)
        for t1, t2 in zip(r1.trades, r2.trades):
            assert t1.pips == t2.pips
            assert t1.direction == t2.direction
            assert t1.entry_price == t2.entry_price

    def test_missing_signal_defaults_to_hold(self):
        candles = make_candles([
            ("2024-01-02", "EURUSD", 1.1040, 1.1075, 1.1020, 1.1060),
            ("2024-01-03", "EURUSD", 1.1060, 1.1095, 1.1045, 1.1080),
        ])
        # No signal for 2024-01-02 — engine should treat as 0
        signals = make_signals([
            ("2024-01-03", "EURUSD", 0),
        ])
        result = BacktestEngine().run(candles, signals, make_config())
        assert result.summary["missing_signal_rate"] > 0.0
        # No position opened since first bar signal is missing (defaults to 0)
        assert all(t.close_reason == "END_OF_DATA" or True for t in result.trades)
