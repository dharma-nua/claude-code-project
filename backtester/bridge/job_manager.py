import json
import os
from datetime import datetime, timezone
from pathlib import Path

JOB_DIR = Path(__file__).parent / "jobs"
PENDING_DIR = JOB_DIR / "pending"
DONE_DIR = JOB_DIR / "done"


def write_job(
    run_id: str,
    indicator_id: str,
    indicator_file: str,
    candle_source_type: str,
    candle_file: "str | None",
    config_dict: dict,
) -> Path:
    """Write <run_id>.json to bridge/jobs/pending/. Returns path."""
    PENDING_DIR.mkdir(parents=True, exist_ok=True)

    job = {
        "job_id": run_id,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "indicator_id": indicator_id,
        "indicator_file": indicator_file,
        "candle_source_type": candle_source_type,
        "candle_file": candle_file,
        "config": config_dict,
        "status": "pending",
    }

    path = PENDING_DIR / f"{run_id}.json"
    with open(path, "w", encoding="utf-8") as f:
        json.dump(job, f, indent=2)

    return path


def read_job_status(run_id: str) -> dict:
    """Check pending/ and done/ dirs.
    Returns {"status": "pending"|"done"|"failed"|"not_found", "job": dict|None}"""
    done_result_path = DONE_DIR / run_id / "job_result.json"
    if done_result_path.exists():
        with open(done_result_path, encoding="utf-8") as f:
            result = json.load(f)
        status = result.get("status", "done")
        return {"status": status, "job": result}

    pending_path = PENDING_DIR / f"{run_id}.json"
    if pending_path.exists():
        with open(pending_path, encoding="utf-8") as f:
            job = json.load(f)
        # If runner updated status field to "running", reflect that
        actual_status = job.get("status", "pending")
        if actual_status == "running":
            return {"status": "running", "job": job}
        return {"status": "pending", "job": job}

    return {"status": "not_found", "job": None}


def get_done_outputs(run_id: str) -> dict:
    """Return paths for normalized_candles.csv and normalized_signals.csv
    from bridge/jobs/done/<run_id>/. Returns {} if not found."""
    done_dir = DONE_DIR / run_id
    if not done_dir.exists():
        return {}

    result = {}
    candles_path = done_dir / "normalized_candles.csv"
    signals_path = done_dir / "normalized_signals.csv"

    if candles_path.exists():
        result["normalized_candles"] = candles_path
    if signals_path.exists():
        result["normalized_signals"] = signals_path

    return result


def mark_running(run_id: str) -> None:
    """Update status field in pending JSON to 'running'."""
    _update_pending_status(run_id, "running")


def mark_failed(run_id: str, error: str) -> None:
    """Write job_result.json to done/<run_id>/ with status=failed."""
    DONE_DIR.mkdir(parents=True, exist_ok=True)
    done_dir = DONE_DIR / run_id
    done_dir.mkdir(parents=True, exist_ok=True)

    # Load original job if present
    pending_path = PENDING_DIR / f"{run_id}.json"
    job: dict = {}
    if pending_path.exists():
        try:
            with open(pending_path, encoding="utf-8") as f:
                job = json.load(f)
        except Exception:
            pass
        try:
            pending_path.unlink()
        except Exception:
            pass

    result = {**job, "status": "failed", "error": error,
              "completed_at": datetime.now(timezone.utc).isoformat()}
    with open(done_dir / "job_result.json", "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2)


def mark_done(run_id: str) -> None:
    """Write job_result.json to done/<run_id>/ with status=done."""
    DONE_DIR.mkdir(parents=True, exist_ok=True)
    done_dir = DONE_DIR / run_id
    done_dir.mkdir(parents=True, exist_ok=True)

    pending_path = PENDING_DIR / f"{run_id}.json"
    job: dict = {}
    if pending_path.exists():
        try:
            with open(pending_path, encoding="utf-8") as f:
                job = json.load(f)
        except Exception:
            pass
        try:
            pending_path.unlink()
        except Exception:
            pass

    result = {**job, "status": "done", "error": None,
              "completed_at": datetime.now(timezone.utc).isoformat()}
    with open(done_dir / "job_result.json", "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2)


def _update_pending_status(run_id: str, status: str) -> None:
    pending_path = PENDING_DIR / f"{run_id}.json"
    if not pending_path.exists():
        return
    try:
        with open(pending_path, encoding="utf-8") as f:
            job = json.load(f)
        job["status"] = status
        with open(pending_path, "w", encoding="utf-8") as f:
            json.dump(job, f, indent=2)
    except Exception:
        pass


def is_bridge_available() -> bool:
    """Return True if bridge/jobs dirs exist and are writable."""
    try:
        PENDING_DIR.mkdir(parents=True, exist_ok=True)
        DONE_DIR.mkdir(parents=True, exist_ok=True)
        test_file = PENDING_DIR / ".write_test"
        test_file.write_text("test")
        test_file.unlink()
        return True
    except (OSError, PermissionError):
        return False


def list_pending_jobs() -> list[dict]:
    if not PENDING_DIR.exists():
        return []
    jobs = []
    for p in PENDING_DIR.glob("*.json"):
        try:
            with open(p, encoding="utf-8") as f:
                jobs.append(json.load(f))
        except Exception:
            pass
    return jobs


def list_done_jobs() -> list[dict]:
    if not DONE_DIR.exists():
        return []
    jobs = []
    for result_path in DONE_DIR.glob("*/job_result.json"):
        try:
            with open(result_path, encoding="utf-8") as f:
                jobs.append(json.load(f))
        except Exception:
            pass
    return jobs
