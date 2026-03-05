"""
tests/test_runner.py — Bridge runner lifecycle and engine integration tests.

All MT4 process calls are mocked. Tests verify state transitions, error
handling, and that valid bridge outputs feed correctly into the C1 engine.
"""
import json
import logging
import sys
from pathlib import Path
from unittest import mock

import pandas as pd
import pytest

# ─── Fixtures / sample data ───────────────────────────────────────────────────

SAMPLE_CANDLES_CSV = """\
timestamp,symbol,timeframe,open,high,low,close,volume
2024-01-02,EURGBP,D1,0.8590,0.8615,0.8575,0.8605,15300
2024-01-02,EURUSD,D1,1.1040,1.1075,1.1020,1.1060,22400
2024-01-03,EURGBP,D1,0.8605,0.8640,0.8590,0.8625,14800
2024-01-03,EURUSD,D1,1.1060,1.1095,1.1045,1.1080,23100
"""

SAMPLE_SIGNALS_CSV = """\
timestamp,symbol,signal
2024-01-02,EURGBP,0
2024-01-02,EURUSD,1
2024-01-03,EURGBP,-1
2024-01-03,EURUSD,0
"""

BAD_SIGNALS_CSV = """\
timestamp,symbol,signal
2024-01-02,EURGBP,99
2024-01-02,EURUSD,99
2024-01-03,EURGBP,99
2024-01-03,EURUSD,99
"""

_BACKTESTER_ROOT = Path(__file__).parent.parent


def _make_job(tmp_path: Path, run_id: str = "test-run-001") -> dict:
    return {
        "job_id": run_id,
        "status": "pending",
        "indicator_id": "ind-abc",
        "indicator_file": "MyIndicator.mq4",
        "candle_source_type": "ctf",
        "candle_file": str(tmp_path / "test.ctf"),
        "config": {
            "symbols": ["EURUSD", "EURGBP"],
            "date_range": {"from": "2024-01-01", "to": "2024-12-31"},
        },
    }


def _write_pending_job(pending_dir: Path, job: dict) -> Path:
    p = pending_dir / f"{job['job_id']}.json"
    p.write_text(json.dumps(job))
    return p


def _write_mock_mt4_output(output_dir: Path, run_id: str) -> None:
    """Simulate MT4 EA writing its output files and done marker."""
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "normalized_candles.csv").write_text(SAMPLE_CANDLES_CSV)
    (output_dir / "normalized_signals.csv").write_text(SAMPLE_SIGNALS_CSV)
    (output_dir / f"bridge_done_{run_id}.txt").write_text("done\n")


def _patch_job_dirs(tmp_path: Path):
    """Return context managers that redirect job_manager paths to tmp_path."""
    import bridge.job_manager as jm
    pending = tmp_path / "jobs" / "pending"
    done = tmp_path / "jobs" / "done"
    pending.mkdir(parents=True)
    done.mkdir(parents=True)
    return (
        mock.patch.object(jm, "PENDING_DIR", pending),
        mock.patch.object(jm, "DONE_DIR", done),
        pending,
        done,
    )


# ─── TestRunnerLifecycle ──────────────────────────────────────────────────────

class TestRunnerLifecycle:

    def test_job_transitions_pending_to_running_to_done(self, tmp_path):
        """Happy path: job goes pending → running → done when MT4 writes output."""
        import bridge.job_manager as jm
        import bridge.runner as runner

        run_id = "lifecycle-001"
        p_pending, p_done, pending_dir, done_dir = _patch_job_dirs(tmp_path)

        # Fake MT4 terminal
        fake_terminal = tmp_path / "terminal.exe"
        fake_terminal.write_bytes(b"")
        fake_metaeditor = tmp_path / "metaeditor.exe"
        fake_metaeditor.write_bytes(b"")

        # Pre-write bridge output so polling sees it immediately
        common_output_dir = tmp_path / "common" / "bridge_output" / run_id

        with p_pending, p_done:
            _write_pending_job(pending_dir, _make_job(tmp_path, run_id))

            # Fake indicator in library
            lib_dir = _BACKTESTER_ROOT / "library" / "indicators"
            lib_dir.mkdir(parents=True, exist_ok=True)
            fake_ind = lib_dir / "MyIndicator.mq4"
            fake_ind.write_text("// fake indicator")

            config_override = {
                "mt4_terminal_path": str(fake_terminal),
                "mt4_metaeditor_path": str(fake_metaeditor),
                "job_timeout_seconds": 10,
                "poll_interval_seconds": 0.1,
            }

            # Mock subprocess.run (metaeditor compile) and subprocess.Popen (MT4 launch)
            mock_proc = mock.MagicMock()
            mock_proc.poll.return_value = 0  # MT4 exits immediately

            def _write_outputs_on_popen(*args, **kwargs):
                _write_mock_mt4_output(common_output_dir, run_id)
                return mock_proc

            with (
                mock.patch("bridge.runner._load_config", return_value=config_override),
                mock.patch("bridge.runner.compile_if_needed", return_value=True),
                mock.patch("bridge.runner.compile_bridge_ea_if_needed", return_value=True),
                mock.patch("subprocess.Popen", side_effect=_write_outputs_on_popen),
                mock.patch("bridge.mt4_runner.ea_builder.get_done_marker_path",
                           return_value=common_output_dir / f"bridge_done_{run_id}.txt"),
                mock.patch("bridge.mt4_runner.ea_builder.get_output_dir",
                           return_value=common_output_dir),
                mock.patch("bridge.mt4_runner.ea_builder.build_launch_files",
                           return_value={
                               "indicator_dest": tmp_path / "ind.mq4",
                               "bridge_ea_src": tmp_path / "ea.mq4",
                               "bridge_config": tmp_path / "cfg.ini",
                               "ea_params": tmp_path / "params.ini",
                               "tester_ini": tmp_path / "tester.ini",
                               "output_dir": str(common_output_dir),
                           }),
            ):
                runner.process_job(run_id)

            status_info = jm.read_job_status(run_id)
            assert status_info["status"] == "done", f"Expected done, got: {status_info}"
            outputs = jm.get_done_outputs(run_id)
            assert "normalized_candles" in outputs
            assert "normalized_signals" in outputs

    def test_runner_fails_when_mt4_not_found(self, tmp_path):
        """Runner should mark job failed if MT4 terminal cannot be located."""
        import bridge.job_manager as jm
        import bridge.runner as runner

        run_id = "no-mt4-001"
        p_pending, p_done, pending_dir, done_dir = _patch_job_dirs(tmp_path)

        with p_pending, p_done:
            _write_pending_job(pending_dir, _make_job(tmp_path, run_id))

            config_override = {
                "mt4_terminal_path": str(tmp_path / "nonexistent" / "terminal.exe"),
                "job_timeout_seconds": 10,
                "poll_interval_seconds": 0.1,
            }
            with mock.patch("bridge.runner._load_config", return_value=config_override):
                runner.process_job(run_id)

            status_info = jm.read_job_status(run_id)
            assert status_info["status"] == "failed"
            assert "MT4 terminal not found" in status_info["job"].get("error", "")

    def test_runner_fails_when_compilation_fails(self, tmp_path):
        """Runner should mark job failed if indicator .ex4 is not produced."""
        import bridge.job_manager as jm
        import bridge.runner as runner

        run_id = "compile-fail-001"
        p_pending, p_done, pending_dir, done_dir = _patch_job_dirs(tmp_path)

        fake_terminal = tmp_path / "terminal.exe"
        fake_terminal.write_bytes(b"")
        fake_metaeditor = tmp_path / "metaeditor.exe"
        fake_metaeditor.write_bytes(b"")

        with p_pending, p_done:
            _write_pending_job(pending_dir, _make_job(tmp_path, run_id))

            config_override = {
                "mt4_terminal_path": str(fake_terminal),
                "mt4_metaeditor_path": str(fake_metaeditor),
                "job_timeout_seconds": 10,
                "poll_interval_seconds": 0.1,
            }

            # compile_if_needed returns False → job should fail
            with (
                mock.patch("bridge.runner._load_config", return_value=config_override),
                mock.patch("bridge.runner.compile_if_needed", return_value=False),
            ):
                runner.process_job(run_id)

            status_info = jm.read_job_status(run_id)
            assert status_info["status"] == "failed"
            assert "compilation failed" in status_info["job"].get("error", "").lower()

    def test_runner_fails_on_schema_violation(self, tmp_path):
        """Runner should mark failed when bridge signals CSV has invalid values."""
        import bridge.job_manager as jm
        import bridge.runner as runner

        run_id = "schema-fail-001"
        p_pending, p_done, pending_dir, done_dir = _patch_job_dirs(tmp_path)

        fake_terminal = tmp_path / "terminal.exe"
        fake_terminal.write_bytes(b"")

        # Output dir with bad signals
        common_output_dir = tmp_path / "common" / "bridge_output" / run_id
        common_output_dir.mkdir(parents=True, exist_ok=True)
        (common_output_dir / "normalized_candles.csv").write_text(SAMPLE_CANDLES_CSV)
        (common_output_dir / "normalized_signals.csv").write_text(BAD_SIGNALS_CSV)
        (common_output_dir / f"bridge_done_{run_id}.txt").write_text("done\n")

        with p_pending, p_done:
            _write_pending_job(pending_dir, _make_job(tmp_path, run_id))

            config_override = {
                "mt4_terminal_path": str(fake_terminal),
                "job_timeout_seconds": 10,
                "poll_interval_seconds": 0.1,
            }

            mock_proc = mock.MagicMock()
            mock_proc.poll.return_value = 0

            with (
                mock.patch("bridge.runner._load_config", return_value=config_override),
                mock.patch("bridge.runner.compile_if_needed", return_value=True),
                mock.patch("bridge.runner.compile_bridge_ea_if_needed", return_value=True),
                mock.patch("subprocess.Popen", return_value=mock_proc),
                mock.patch("bridge.mt4_runner.ea_builder.build_launch_files",
                           return_value={
                               "tester_ini": tmp_path / "tester.ini",
                               "output_dir": str(common_output_dir),
                           }),
                mock.patch("bridge.mt4_runner.ea_builder.get_done_marker_path",
                           return_value=common_output_dir / f"bridge_done_{run_id}.txt"),
                mock.patch("bridge.mt4_runner.ea_builder.get_output_dir",
                           return_value=common_output_dir),
            ):
                runner.process_job(run_id)

            status_info = jm.read_job_status(run_id)
            assert status_info["status"] == "failed"
            assert "schema error" in status_info["job"].get("error", "").lower()

    def test_log_file_created_for_job(self, tmp_path):
        """A .log file should be created under bridge/jobs/logs/ for every job."""
        import bridge.runner as runner

        run_id = "log-test-001"
        p_pending, p_done, pending_dir, done_dir = _patch_job_dirs(tmp_path)

        log_dir = tmp_path / "logs"
        log_dir.mkdir()

        with p_pending, p_done:
            _write_pending_job(pending_dir, _make_job(tmp_path, run_id))

            config_override = {
                "mt4_terminal_path": str(tmp_path / "nonexistent.exe"),
                "job_timeout_seconds": 5,
                "poll_interval_seconds": 0.1,
            }
            with (
                mock.patch("bridge.runner._load_config", return_value=config_override),
                mock.patch("bridge.runner._LOGS_DIR", log_dir),
            ):
                runner.process_job(run_id)

        log_file = log_dir / f"{run_id}.log"
        assert log_file.exists(), "Log file was not created"
        content = log_file.read_text(encoding="utf-8")
        assert run_id in content


# ─── TestEngineFromBridgeOutputs ─────────────────────────────────────────────

class TestEngineFromBridgeOutputs:

    def test_engine_runs_with_valid_bridge_candles_and_signals(self, tmp_path):
        """Valid bridge CSVs should produce a BacktestResult via the real engine."""
        from src.engine import BacktestEngine
        from src.models import BacktestConfig
        from src.validator import validate_candles, validate_signals

        # Write mock bridge outputs
        output_dir = tmp_path / "bridge_output" / "test-engine-run"
        _write_mock_mt4_output(output_dir, "test-engine-run")

        candles_df = pd.read_csv(output_dir / "normalized_candles.csv")
        signals_df = pd.read_csv(output_dir / "normalized_signals.csv")

        c_ok, c_errors = validate_candles(candles_df)
        s_ok, s_errors = validate_signals(signals_df)
        assert c_ok, f"Candles validation failed: {c_errors}"
        assert s_ok, f"Signals validation failed: {s_errors}"

        config = BacktestConfig(
            symbols=["EURUSD", "EURGBP"],
            date_range={"from": None, "to": None},
        )
        engine = BacktestEngine()
        result = engine.run(candles_df, signals_df, config)

        assert result is not None
        assert result.summary is not None
        assert "total_trades" in result.summary
        assert isinstance(result.trades, list)

    def test_engine_handles_all_zero_signals(self, tmp_path):
        """Engine should complete without error when all signals are 0 (no trades)."""
        from src.engine import BacktestEngine
        from src.models import BacktestConfig

        output_dir = tmp_path / "bridge_output" / "zero-signals"
        output_dir.mkdir(parents=True, exist_ok=True)
        (output_dir / "normalized_candles.csv").write_text(SAMPLE_CANDLES_CSV)
        # All zeros — no trades should be generated
        zero_signals = "timestamp,symbol,signal\n"
        for ts in ["2024-01-02", "2024-01-03"]:
            for sym in ["EURUSD", "EURGBP"]:
                zero_signals += f"{ts},{sym},0\n"
        (output_dir / "normalized_signals.csv").write_text(zero_signals)

        candles_df = pd.read_csv(output_dir / "normalized_candles.csv")
        signals_df = pd.read_csv(output_dir / "normalized_signals.csv")

        config = BacktestConfig(
            symbols=["EURUSD", "EURGBP"],
            date_range={"from": None, "to": None},
        )
        engine = BacktestEngine()
        result = engine.run(candles_df, signals_df, config)
        assert result.summary["total_trades"] == 0
        assert result.trades == []

    def test_job_manager_running_status_reflected(self, tmp_path):
        """read_job_status should return 'running' when pending JSON has status=running."""
        import bridge.job_manager as jm

        p_pending, p_done, pending_dir, done_dir = _patch_job_dirs(tmp_path)
        run_id = "running-status-001"

        with p_pending, p_done:
            job = _make_job(tmp_path, run_id)
            _write_pending_job(pending_dir, job)
            jm.mark_running(run_id)
            status_info = jm.read_job_status(run_id)

        assert status_info["status"] == "running"
        assert status_info["job"]["status"] == "running"
