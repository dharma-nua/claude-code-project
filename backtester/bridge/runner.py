"""
bridge/runner.py — CLI worker that processes bridge jobs.

Usage (from backtester/ directory):
  python -m bridge.runner --job-id <id>   # single job
  python -m bridge.runner --watch         # poll pending/ continuously
"""
import argparse
import json
import logging
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

_BACKTESTER_ROOT = Path(__file__).parent.parent
if str(_BACKTESTER_ROOT) not in sys.path:
    sys.path.insert(0, str(_BACKTESTER_ROOT))

from bridge import job_manager
from bridge.mt4_runner import ea_builder
from src.validator import validate_candles, validate_signals

import pandas as pd

_CONFIG_PATH = Path(__file__).parent / "runner_config.json"
_LOGS_DIR = Path(__file__).parent / "jobs" / "logs"

_COMMON_MT4_PATHS = [
    Path("C:/Program Files (x86)/MetaTrader 4/terminal.exe"),
    Path("C:/Program Files/MetaTrader 4/terminal.exe"),
    Path("C:/Program Files (x86)/FTMO MetaTrader 4/terminal.exe"),
    Path("C:/Program Files (x86)/Soft4FX/MetaTrader 4/terminal.exe"),
]


# ─── Config ───────────────────────────────────────────────────────────────────

def _load_config() -> dict:
    defaults = {
        "mt4_terminal_path": None,
        "mt4_metaeditor_path": None,
        "job_timeout_seconds": 300,
        "poll_interval_seconds": 3,
        "watch_interval_seconds": 5,
    }
    if _CONFIG_PATH.exists():
        try:
            with open(_CONFIG_PATH, encoding="utf-8") as f:
                loaded = json.load(f)
            defaults.update(loaded)
        except Exception:
            pass
    return defaults


# ─── Logging ──────────────────────────────────────────────────────────────────

def _setup_logger(job_id: str) -> logging.Logger:
    _LOGS_DIR.mkdir(parents=True, exist_ok=True)
    log_path = _LOGS_DIR / f"{job_id}.log"
    logger = logging.getLogger(f"runner.{job_id}")
    logger.setLevel(logging.DEBUG)
    if not logger.handlers:
        fh = logging.FileHandler(log_path, encoding="utf-8")
        fh.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
        logger.addHandler(fh)
        sh = logging.StreamHandler(sys.stdout)
        sh.setFormatter(logging.Formatter("%(levelname)s %(message)s"))
        logger.addHandler(sh)
    return logger


# ─── MT4 discovery ────────────────────────────────────────────────────────────

def _find_mt4_terminal(config: dict, log: logging.Logger) -> "Path | None":
    if config.get("mt4_terminal_path"):
        p = Path(config["mt4_terminal_path"])
        if p.exists():
            log.info(f"MT4 terminal from config: {p}")
            return p
        log.warning(f"Configured mt4_terminal_path not found: {p}")

    env_val = os.environ.get("MT4_TERMINAL_PATH")
    if env_val:
        p = Path(env_val)
        if p.exists():
            log.info(f"MT4 terminal from MT4_TERMINAL_PATH env: {p}")
            return p

    for candidate in _COMMON_MT4_PATHS:
        if candidate.exists():
            log.info(f"MT4 terminal auto-discovered: {candidate}")
            return candidate

    log.error(
        "MT4 terminal not found. Set mt4_terminal_path in bridge/runner_config.json "
        "or set the MT4_TERMINAL_PATH environment variable."
    )
    return None


def _find_metaeditor(terminal_path: Path, config: dict, log: logging.Logger) -> "Path | None":
    if config.get("mt4_metaeditor_path"):
        p = Path(config["mt4_metaeditor_path"])
        if p.exists():
            return p
        log.warning(f"Configured mt4_metaeditor_path not found: {p}")

    candidate = terminal_path.parent / "metaeditor.exe"
    if candidate.exists():
        return candidate

    log.warning("metaeditor.exe not found alongside terminal.exe")
    return None


# ─── Compilation helpers ──────────────────────────────────────────────────────

def compile_if_needed(
    indicator_file: str, mt4_dir: Path, metaeditor: "Path | None", log: logging.Logger
) -> bool:
    """Copy .mq4 indicator to MQL4/Indicators/ and compile if .ex4 absent."""
    from bridge.mt4_runner import _locate_indicator_src
    ind_src = _locate_indicator_src(indicator_file)
    if ind_src is None:
        log.error(f"Indicator source not found in library: {indicator_file}")
        return False

    ind_dir = mt4_dir / "MQL4" / "Indicators"
    ind_dir.mkdir(parents=True, exist_ok=True)

    ex4_dest = ind_dir / (Path(indicator_file).stem + ".ex4")
    if ex4_dest.exists():
        log.info(f"Compiled .ex4 already exists: {ex4_dest}")
        return True

    mq4_dest = ind_dir / (Path(indicator_file).stem + ".mq4")
    shutil.copy2(ind_src, mq4_dest)
    log.info(f"Copied indicator source to {mq4_dest}")

    if metaeditor is None:
        log.warning("metaeditor.exe not found — skipping compile.")
        return True

    log.info(f"Compiling: {mq4_dest}")
    result = subprocess.run(
        [str(metaeditor), f"/compile:{mq4_dest}", "/log"],
        capture_output=True, text=True, timeout=60,
    )
    if not ex4_dest.exists():
        log.error(f"Compilation failed. metaeditor output: {result.stdout} {result.stderr}")
        return False

    log.info("Compilation succeeded.")
    return True


def compile_bridge_ea_if_needed(mt4_dir: Path, metaeditor: "Path | None", log: logging.Logger) -> bool:
    """Copy NNFXBridgeRunner.mq4 to Experts/ and compile if .ex4 absent."""
    ea_src = Path(__file__).parent / "mt4_runner" / "NNFXBridgeRunner.mq4"
    experts_dir = mt4_dir / "MQL4" / "Experts"
    experts_dir.mkdir(parents=True, exist_ok=True)

    ex4_dest = experts_dir / "NNFXBridgeRunner.ex4"
    if ex4_dest.exists():
        log.info("NNFXBridgeRunner.ex4 already compiled.")
        return True

    if not ea_src.exists():
        log.error(f"NNFXBridgeRunner.mq4 not found at {ea_src}")
        return False

    mq4_dest = experts_dir / "NNFXBridgeRunner.mq4"
    shutil.copy2(ea_src, mq4_dest)

    if metaeditor is None:
        log.warning("metaeditor.exe not found — EA will run from .mq4.")
        return True

    result = subprocess.run(
        [str(metaeditor), f"/compile:{mq4_dest}", "/log"],
        capture_output=True, text=True, timeout=60,
    )
    if not ex4_dest.exists():
        log.error(f"Bridge EA compilation failed: {result.stdout} {result.stderr}")
        return False

    log.info("Bridge EA compiled.")
    return True


# ─── Output validation + copy ─────────────────────────────────────────────────

def _validate_and_copy_outputs(run_id: str, output_dir: Path, log: logging.Logger) -> "tuple[bool, str]":
    candles_src = output_dir / "normalized_candles.csv"
    signals_src = output_dir / "normalized_signals.csv"

    for p in [candles_src, signals_src]:
        if not p.exists():
            return False, f"Missing output file: {p.name}"

    try:
        candles_df = pd.read_csv(candles_src)
        ok, errors = validate_candles(candles_df)
        if not ok:
            return False, "Candles schema error: " + "; ".join(errors)

        signals_df = pd.read_csv(signals_src)
        ok, errors = validate_signals(signals_df)
        if not ok:
            return False, "Signals schema error: " + "; ".join(errors)
    except Exception as exc:
        return False, f"CSV read error: {exc}"

    done_dir = job_manager.DONE_DIR / run_id
    done_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(candles_src, done_dir / "normalized_candles.csv")
    shutil.copy2(signals_src, done_dir / "normalized_signals.csv")
    log.info(f"Outputs copied to {done_dir}")
    return True, ""


# ─── Main job processor ───────────────────────────────────────────────────────

def process_job(job_id: str) -> None:
    log = _setup_logger(job_id)
    log.info(f"Starting job: {job_id}")

    config = _load_config()

    status_info = job_manager.read_job_status(job_id)
    if status_info["status"] == "not_found":
        log.error(f"Job not found: {job_id}")
        return
    job = status_info["job"]

    try:
        job_manager.mark_running(job_id)
        log.info("Marked running.")

        # ── Find MT4 terminal ────────────────────────────────────────────
        terminal = _find_mt4_terminal(config, log)
        if terminal is None:
            job_manager.mark_failed(
                job_id,
                "MT4 terminal not found. Set mt4_terminal_path in bridge/runner_config.json "
                "or the MT4_TERMINAL_PATH environment variable.",
            )
            return

        mt4_dir = terminal.parent
        metaeditor = _find_metaeditor(terminal, config, log)

        # ── Compile indicator ─────────────────────────────────────────────
        indicator_file = job.get("indicator_file", "")
        ok = compile_if_needed(indicator_file, mt4_dir, metaeditor, log)
        if not ok:
            job_manager.mark_failed(job_id, f"Indicator compilation failed: {indicator_file}")
            return

        # ── Compile bridge EA ─────────────────────────────────────────────
        ok = compile_bridge_ea_if_needed(mt4_dir, metaeditor, log)
        if not ok:
            job_manager.mark_failed(job_id, "NNFXBridgeRunner EA compilation failed.")
            return

        # ── Build launch files ────────────────────────────────────────────
        paths = ea_builder.build_launch_files(job, job_id, mt4_dir)
        tester_ini = paths["tester_ini"]
        log.info(f"Tester ini: {tester_ini}")

        # ── Launch MT4 terminal ───────────────────────────────────────────
        log.info(f"Launching: {terminal} /config:{tester_ini}")
        proc = subprocess.Popen(
            [str(terminal), f"/config:{tester_ini}"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

        # ── Poll for done marker ──────────────────────────────────────────
        done_marker = ea_builder.get_done_marker_path(job_id)
        output_dir = ea_builder.get_output_dir(job_id)
        timeout = config.get("job_timeout_seconds", 300)
        poll_interval = config.get("poll_interval_seconds", 3)
        elapsed = 0.0

        while elapsed < timeout:
            if done_marker.exists():
                log.info("Done marker found.")
                break
            ret = proc.poll()
            if ret is not None:
                log.info(f"MT4 exited with code {ret}.")
                if done_marker.exists():
                    log.info("Done marker found after process exit.")
                else:
                    job_manager.mark_failed(
                        job_id,
                        f"MT4 exited (code {ret}) without writing done marker."
                    )
                    return
                break
            time.sleep(poll_interval)
            elapsed += poll_interval
        else:
            log.error("Timeout waiting for MT4.")
            try:
                proc.terminate()
            except Exception:
                pass
            job_manager.mark_failed(job_id, f"Timeout after {timeout}s waiting for MT4 output.")
            return

        # Check done marker content
        try:
            marker_content = done_marker.read_text(encoding="utf-8").strip()
        except Exception as exc:
            job_manager.mark_failed(job_id, f"Cannot read done marker: {exc}")
            return

        if not marker_content.startswith("done"):
            reason = marker_content.replace("failed\n", "", 1).strip()
            job_manager.mark_failed(job_id, f"EA reported failure: {reason}")
            return

        # ── Validate + copy outputs ───────────────────────────────────────
        ok, err = _validate_and_copy_outputs(job_id, output_dir, log)
        if not ok:
            job_manager.mark_failed(job_id, err)
            return

        job_manager.mark_done(job_id)
        log.info("Job completed successfully.")

    except Exception as exc:
        log.exception(f"Unhandled exception in job {job_id}")
        job_manager.mark_failed(job_id, str(exc))


# ─── Watch mode ───────────────────────────────────────────────────────────────

def watch_loop() -> None:
    config = _load_config()
    interval = config.get("watch_interval_seconds", 5)
    print(f"Runner watching for pending jobs (interval={interval}s). Ctrl-C to stop.")
    while True:
        pending = job_manager.list_pending_jobs()
        for job in pending:
            if job.get("status") == "pending":
                process_job(job["job_id"])
        time.sleep(interval)


# ─── Entry point ──────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Bridge runner — processes MT4 backtest jobs")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--job-id", help="Process a single job by ID")
    group.add_argument("--watch", action="store_true", help="Watch pending/ and process jobs continuously")
    args = parser.parse_args()

    if args.job_id:
        process_job(args.job_id)
    else:
        watch_loop()


if __name__ == "__main__":
    main()
