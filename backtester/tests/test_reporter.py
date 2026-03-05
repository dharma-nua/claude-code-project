import os
import json
import tempfile
import pandas as pd
import pytest
from src.engine import BacktestEngine
from src.models import BacktestConfig
from src.reporter import generate_outputs


def make_config(**kwargs):
    defaults = {
        "symbols": ["EURUSD"],
        "date_range": {"from": None, "to": None},
        "reverse_on_flip": False,
    }
    defaults.update(kwargs)
    return BacktestConfig(**defaults)


def make_result_with_trades():
    candles = pd.DataFrame([
        {"timestamp": "2024-01-02", "symbol": "EURUSD", "timeframe": "D1",
         "open": 1.1040, "high": 1.1075, "low": 1.1020, "close": 1.1060, "volume": 22400},
        {"timestamp": "2024-01-03", "symbol": "EURUSD", "timeframe": "D1",
         "open": 1.1060, "high": 1.1095, "low": 1.1045, "close": 1.1080, "volume": 23100},
        {"timestamp": "2024-01-04", "symbol": "EURUSD", "timeframe": "D1",
         "open": 1.1080, "high": 1.1110, "low": 1.1060, "close": 1.1050, "volume": 21800},
    ])
    signals = pd.DataFrame([
        {"timestamp": "2024-01-02", "symbol": "EURUSD", "signal": 1},
        {"timestamp": "2024-01-03", "symbol": "EURUSD", "signal": 0},
        {"timestamp": "2024-01-04", "symbol": "EURUSD", "signal": -1},
    ])
    return BacktestEngine().run(candles, signals, make_config())


def make_result_all_signals_present():
    """All signals present -> missing_signal_rate should be 0.0"""
    candles = pd.DataFrame([
        {"timestamp": "2024-01-02", "symbol": "EURUSD", "timeframe": "D1",
         "open": 1.104, "high": 1.108, "low": 1.102, "close": 1.106, "volume": 1000},
        {"timestamp": "2024-01-03", "symbol": "EURUSD", "timeframe": "D1",
         "open": 1.106, "high": 1.110, "low": 1.104, "close": 1.108, "volume": 1000},
    ])
    signals = pd.DataFrame([
        {"timestamp": "2024-01-02", "symbol": "EURUSD", "signal": 0},
        {"timestamp": "2024-01-03", "symbol": "EURUSD", "signal": 0},
    ])
    return BacktestEngine().run(candles, signals, make_config())


class TestReporterOutputFiles:
    def test_all_5_output_files_created(self):
        result = make_result_with_trades()
        with tempfile.TemporaryDirectory() as tmpdir:
            paths = generate_outputs(result, tmpdir)
            assert "trades" in paths
            assert "journal" in paths
            assert "summary" in paths
            assert "report" in paths
            assert "simulation" in paths
            for name, path in paths.items():
                assert os.path.exists(path), f"{name} file not found at {path}"

    def test_summary_json_has_required_keys(self):
        result = make_result_with_trades()
        with tempfile.TemporaryDirectory() as tmpdir:
            paths = generate_outputs(result, tmpdir)
            with open(paths["summary"]) as f:
                summary = json.load(f)
            required_keys = [
                "total_trades", "winning_trades", "losing_trades", "win_rate",
                "total_pips", "avg_pips_per_trade", "avg_win_pips", "avg_loss_pips",
                "profit_factor", "max_drawdown_pips", "missing_signal_rate", "per_symbol",
            ]
            for key in required_keys:
                assert key in summary, f"Missing key in summary.json: {key}"

    def test_trade_count_matches_engine_output(self):
        result = make_result_with_trades()
        with tempfile.TemporaryDirectory() as tmpdir:
            paths = generate_outputs(result, tmpdir)
            with open(paths["summary"]) as f:
                summary = json.load(f)
            assert summary["total_trades"] == len(result.trades)

    def test_missing_signal_rate_is_0_when_all_signals_present(self):
        result = make_result_all_signals_present()
        with tempfile.TemporaryDirectory() as tmpdir:
            paths = generate_outputs(result, tmpdir)
            with open(paths["summary"]) as f:
                summary = json.load(f)
            assert summary["missing_signal_rate"] == 0.0

    def test_trades_csv_has_correct_columns(self):
        result = make_result_with_trades()
        with tempfile.TemporaryDirectory() as tmpdir:
            paths = generate_outputs(result, tmpdir)
            import csv
            with open(paths["trades"]) as f:
                reader = csv.DictReader(f)
                cols = reader.fieldnames
            expected = ["trade_id", "symbol", "direction", "entry_timestamp",
                        "entry_price", "exit_timestamp", "exit_price", "pips", "close_reason"]
            for col in expected:
                assert col in cols, f"Missing column in trades.csv: {col}"

    def test_simulation_json_has_run_id(self):
        result = make_result_with_trades()
        with tempfile.TemporaryDirectory() as tmpdir:
            paths = generate_outputs(result, tmpdir)
            with open(paths["simulation"]) as f:
                sim = json.load(f)
            assert "run_id" in sim
            assert sim["run_id"] == result.config.run_id
            # Phase 1.5 new fields
            assert "candle_source_type" in sim
            assert "selected_indicator_id" in sim
            assert "selected_indicator_hash" in sim
            assert "mapped_signal_csv_path" in sim
            assert "mapped_signal_csv_hash" in sim
            assert "candle_normalized_output_path" in sim
            assert "statement_import_run_id" in sim

    def test_report_html_is_valid_html(self):
        result = make_result_with_trades()
        with tempfile.TemporaryDirectory() as tmpdir:
            paths = generate_outputs(result, tmpdir)
            with open(paths["report"]) as f:
                content = f.read()
            assert "<!DOCTYPE html>" in content
            assert result.config.run_id[:8] in content
