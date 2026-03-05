import pytest

from src.comparator import compare_results


class TestComparator:
    def test_compare_results_returns_metric_rows(self):
        sim = {"total_trades": 10, "win_rate": 0.6, "total_pips": 150.0,
               "profit_factor": 2.0, "max_drawdown_pips": 30.0}
        stmt = {"total_trades": 12, "net_profit": 600.0, "profit_factor": 1.8, "drawdown_pct": 5.2}
        result = compare_results(sim, stmt)
        assert "metrics" in result
        assert isinstance(result["metrics"], list)
        assert len(result["metrics"]) > 0
        first = result["metrics"][0]
        assert "metric" in first
        assert "simulation" in first
        assert "statement" in first
        assert "delta" in first

    def test_compare_results_delta_is_numeric(self):
        sim = {"total_trades": 10, "win_rate": 0.6, "total_pips": 150.0,
               "profit_factor": 2.0, "max_drawdown_pips": 30.0}
        stmt = {"total_trades": 8, "net_profit": 100.0, "profit_factor": 1.5, "drawdown_pct": 10.0}
        result = compare_results(sim, stmt)
        for row in result["metrics"]:
            if row["simulation"] is not None and row["statement"] is not None:
                assert isinstance(row["delta"], (int, float)), f"Expected numeric delta for {row['metric']}"

    def test_compare_results_missing_fields_null_delta(self):
        sim = {"total_trades": 5}
        stmt = {}
        result = compare_results(sim, stmt)
        for row in result["metrics"]:
            if row["statement"] is None:
                assert row["delta"] is None
