import io
from pathlib import Path

import pytest

from src.statement_parser import parse_statement, save_statement_outputs

FIXTURE = Path(__file__).parent / "fixtures" / "sample_statement.html"


def _load_fixture() -> io.BytesIO:
    data = FIXTURE.read_bytes()
    buf = io.BytesIO(data)
    buf.name = "sample_statement.html"
    return buf


class TestStatementParser:
    def test_parse_statement_returns_trades(self):
        success, trades, summary, err = parse_statement(_load_fixture())
        assert success is True
        assert len(trades) >= 1
        first = trades[0]
        assert "ticket" in first or "symbol" in first

    def test_parse_statement_returns_summary(self):
        success, trades, summary, err = parse_statement(_load_fixture())
        assert success is True
        assert "net_profit" in summary or "profit_factor" in summary

    def test_parse_statement_on_empty_html(self):
        buf = io.BytesIO(b"<html><body></body></html>")
        buf.name = "empty.html"
        success, trades, summary, err = parse_statement(buf)
        # Either a clean failure or partial success with empty data
        if success:
            assert trades == [] or trades is not None
        else:
            assert err != ""

    def test_save_statement_outputs_writes_files(self, tmp_path):
        trades = [{"ticket": "123", "symbol": "EURUSD", "profit": "400.00"}]
        summary = {"net_profit": 400.0, "profit_factor": 2.5}
        csv_path, json_path = save_statement_outputs(trades, summary, tmp_path)
        assert csv_path.exists()
        assert json_path.exists()
        import json
        loaded = json.loads(json_path.read_text())
        assert loaded["net_profit"] == 400.0
