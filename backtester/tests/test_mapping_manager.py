import json
from pathlib import Path
from unittest import mock

import pandas as pd
import pytest

import src.mapping_manager as mgr


def _patch_mappings_root(tmp_path):
    root = tmp_path / "mappings"
    return mock.patch.object(mgr, "_MAPPINGS_ROOT", root)


def _valid_signals_df():
    return pd.DataFrame([
        {"timestamp": "2024-01-02", "symbol": "EURUSD", "signal": 1},
        {"timestamp": "2024-01-03", "symbol": "EURUSD", "signal": -1},
        {"timestamp": "2024-01-04", "symbol": "EURUSD", "signal": 0},
    ])


class TestMappingManager:
    def test_attach_mapping_writes_json(self, tmp_path):
        csv_path = tmp_path / "signals.csv"
        _valid_signals_df().to_csv(csv_path, index=False)

        with _patch_mappings_root(tmp_path):
            mapping = mgr.attach_mapping("test-id-123", csv_path)

        assert mapping["indicator_id"] == "test-id-123"
        assert "signal_csv_sha256" in mapping
        assert mapping["schema_version"] == mgr.SCHEMA_VERSION
        root = tmp_path / "mappings"
        assert (root / "test-id-123.json").exists()

    def test_get_mapping_returns_none_when_missing(self, tmp_path):
        with _patch_mappings_root(tmp_path):
            result = mgr.get_mapping("nonexistent-id")
        assert result is None

    def test_validate_mapping_csv_valid(self):
        ok, errors = mgr.validate_mapping_csv(_valid_signals_df())
        assert ok is True
        assert errors == []

    def test_validate_mapping_csv_invalid_signal_value(self):
        df = pd.DataFrame([
            {"timestamp": "2024-01-02", "symbol": "EURUSD", "signal": 2},
        ])
        ok, errors = mgr.validate_mapping_csv(df)
        assert ok is False
        assert any("signal" in e.lower() for e in errors)

    def test_validate_mapping_csv_invalid_symbol(self):
        df = pd.DataFrame([
            {"timestamp": "2024-01-02", "symbol": "XAUUSD", "signal": 1},
        ])
        ok, errors = mgr.validate_mapping_csv(df)
        assert ok is False
        assert any("symbol" in e.lower() for e in errors)

    def test_validate_mapping_csv_duplicate_rows(self):
        df = pd.DataFrame([
            {"timestamp": "2024-01-02", "symbol": "EURUSD", "signal": 1},
            {"timestamp": "2024-01-02", "symbol": "EURUSD", "signal": -1},
        ])
        ok, errors = mgr.validate_mapping_csv(df)
        assert ok is False
        assert any("duplicate" in e.lower() for e in errors)
