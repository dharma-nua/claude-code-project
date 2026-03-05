import json
from pathlib import Path
from unittest import mock

import pytest

import bridge.job_manager as jm


def _patch_dirs(tmp_path):
    pending = tmp_path / "jobs" / "pending"
    done = tmp_path / "jobs" / "done"
    pending.mkdir(parents=True)
    done.mkdir(parents=True)
    return (
        mock.patch.object(jm, "JOB_DIR", tmp_path / "jobs"),
        mock.patch.object(jm, "PENDING_DIR", pending),
        mock.patch.object(jm, "DONE_DIR", done),
        pending,
        done,
    )


class TestBridgeJobManager:
    def test_write_job_creates_pending_file(self, tmp_path):
        p1, p2, p3, pending, done = _patch_dirs(tmp_path)
        with p1, p2, p3:
            path = jm.write_job(
                run_id="run-abc",
                indicator_id="ind-123",
                indicator_file="ind-123.mq4",
                candle_source_type="csv",
                candle_file=None,
                config_dict={"symbols": ["EURUSD"], "date_range": {"from": None, "to": None}},
            )
        assert (pending / "run-abc.json").exists()
        job = json.loads(path.read_text())
        assert job["job_id"] == "run-abc"
        assert job["status"] == "pending"

    def test_read_job_status_pending(self, tmp_path):
        p1, p2, p3, pending, done = _patch_dirs(tmp_path)
        with p1, p2, p3:
            jm.write_job(
                run_id="run-xyz",
                indicator_id="ind-1",
                indicator_file="ind-1.mq4",
                candle_source_type="csv",
                candle_file=None,
                config_dict={},
            )
            result = jm.read_job_status("run-xyz")
        assert result["status"] == "pending"
        assert result["job"] is not None

    def test_read_job_status_done(self, tmp_path):
        p1, p2, p3, pending, done = _patch_dirs(tmp_path)
        with p1, p2, p3:
            done_dir = done / "run-done"
            done_dir.mkdir(parents=True)
            result_json = {"status": "done", "error": None}
            (done_dir / "job_result.json").write_text(json.dumps(result_json))
            result = jm.read_job_status("run-done")
        assert result["status"] == "done"

    def test_get_done_outputs_returns_paths(self, tmp_path):
        p1, p2, p3, pending, done = _patch_dirs(tmp_path)
        with p1, p2, p3:
            done_dir = done / "run-outputs"
            done_dir.mkdir(parents=True)
            (done_dir / "normalized_candles.csv").write_text("timestamp,symbol\n")
            (done_dir / "normalized_signals.csv").write_text("timestamp,symbol,signal\n")
            outputs = jm.get_done_outputs("run-outputs")
        assert "normalized_candles" in outputs
        assert "normalized_signals" in outputs

    def test_is_bridge_available_true_when_dirs_exist(self, tmp_path):
        p1, p2, p3, pending, done = _patch_dirs(tmp_path)
        with p1, p2, p3:
            available = jm.is_bridge_available()
        assert available is True
