import io
import os
import tempfile
from pathlib import Path

import pandas as pd
import pytest

from src.ctf_adapter import parse_ctf, save_normalized_candles, _FALLBACK_MSG


def _make_fake_file(content: bytes, name: str = "test.ctf"):
    buf = io.BytesIO(content)
    buf.name = name
    return buf


def _valid_d1_csv_bytes() -> bytes:
    lines = [
        "timestamp,symbol,timeframe,open,high,low,close,volume",
        "2024-01-02,EURUSD,D1,1.1040,1.1075,1.1020,1.1060,22400",
        "2024-01-03,EURUSD,D1,1.1060,1.1095,1.1045,1.1080,23100",
    ]
    return "\n".join(lines).encode("utf-8")


class TestCtfAdapter:
    def test_ctf_fallback_on_binary_content(self):
        binary = bytes(range(256)) * 10
        f = _make_fake_file(binary)
        success, df, msg = parse_ctf(f)
        assert success is False
        assert df is None
        assert msg == _FALLBACK_MSG

    def test_ctf_fallback_on_csv_failing_d1_validation(self):
        # Valid CSV structure but H4 timeframe — fails D1 validation
        lines = [
            "timestamp,symbol,timeframe,open,high,low,close,volume",
            "2024-01-02,EURUSD,H4,1.1040,1.1075,1.1020,1.1060,22400",
        ]
        content = "\n".join(lines).encode("utf-8")
        f = _make_fake_file(content)
        success, df, msg = parse_ctf(f)
        assert success is False
        assert msg == _FALLBACK_MSG

    def test_ctf_success_on_valid_d1_csv_content(self):
        f = _make_fake_file(_valid_d1_csv_bytes())
        success, df, msg = parse_ctf(f)
        assert success is True
        assert df is not None
        assert len(df) == 2
        assert "timestamp" in df.columns
        assert "symbol" in df.columns

    def test_save_normalized_candles_writes_file(self, tmp_path):
        df = pd.DataFrame([{
            "timestamp": "2024-01-02", "symbol": "EURUSD", "timeframe": "D1",
            "open": 1.104, "high": 1.108, "low": 1.102, "close": 1.106, "volume": 1000,
        }])
        out_path = save_normalized_candles(df, tmp_path / "output")
        assert out_path.exists()
        loaded = pd.read_csv(out_path)
        assert len(loaded) == 1
        assert "timestamp" in loaded.columns
