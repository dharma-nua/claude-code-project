"""
bridge/launcher.py — Start bridge/runner.py as a detached subprocess.
Called by app.py when a bridge job is submitted.
"""
import subprocess
import sys
from pathlib import Path

_BACKTESTER_ROOT = Path(__file__).parent.parent
_LOGS_DIR = Path(__file__).parent / "jobs" / "logs"


def start_runner(job_id: str) -> int:
    """Start runner as a detached subprocess. Returns PID."""
    proc = subprocess.Popen(
        [sys.executable, "-m", "bridge.runner", "--job-id", job_id],
        cwd=str(_BACKTESTER_ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return proc.pid


def get_log_tail(job_id: str, lines: int = 40) -> str:
    """Read last N lines from the job log file. Returns empty string if not found."""
    log_path = _LOGS_DIR / f"{job_id}.log"
    if not log_path.exists():
        return ""
    try:
        with open(log_path, encoding="utf-8", errors="replace") as f:
            all_lines = f.readlines()
        return "".join(all_lines[-lines:])
    except Exception:
        return ""
