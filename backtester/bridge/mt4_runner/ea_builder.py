"""
ea_builder.py — Prepare all files MT4 needs before launch.

Writes:
  - bridge_config_<run_id>.ini  → MT4 Common/Files/ (EA reads via FILE_COMMON)
  - ea_params_<run_id>.ini      → MT4 Common/Files/ (tester .set file)
  - tester_<run_id>.ini         → local temp dir (passed to terminal.exe /config:)
"""
import os
import shutil
from pathlib import Path

COMMON_FILES_DIR = (
    Path(os.environ.get("APPDATA", ""))
    / "MetaQuotes" / "Terminal" / "Common" / "Files"
)

BRIDGE_EA_NAME = "NNFXBridgeRunner"


def build_launch_files(job: dict, run_id: str, mt4_dir: Path) -> dict:
    """
    Prepare all files required for MT4 strategy tester launch.

    Steps:
      1. Copy indicator .ex4 (or .mq4) to mt4_dir/MQL4/Indicators/
      2. Copy NNFXBridgeRunner.mq4 to mt4_dir/MQL4/Experts/
      3. Write bridge_config_<run_id>.ini to Common/Files/
      4. Write ea_params_<run_id>.ini to Common/Files/
      5. Write tester_<run_id>.ini to Common/Files/

    Returns dict of created paths:
      {
        "indicator_dest": Path,
        "bridge_ea_src": Path,
        "bridge_config": Path,
        "ea_params": Path,
        "tester_ini": Path,
        "output_dir": str,   # relative to Common/Files
      }
    """
    config = job.get("config", {})
    symbols = config.get("symbols", ["EURUSD", "EURGBP", "AUDNZD", "AUDCAD", "CHFJPY"])
    date_range = config.get("date_range", {})
    from_date = _fmt_date(date_range.get("from")) or "2020.01.01"
    to_date = _fmt_date(date_range.get("to")) or "2024.12.31"
    indicator_file = job.get("indicator_file", "")
    indicator_name = Path(indicator_file).stem

    # ── 1. Locate indicator source file ───────────────────────────────
    from bridge.mt4_runner import _locate_indicator_src
    ind_src = _locate_indicator_src(indicator_file)

    # ── 2. Copy indicator to MT4 Indicators/ ──────────────────────────
    ind_dest_dir = mt4_dir / "MQL4" / "Indicators"
    ind_dest_dir.mkdir(parents=True, exist_ok=True)
    ind_dest = ind_dest_dir / Path(indicator_file).name
    if ind_src and ind_src.exists():
        shutil.copy2(ind_src, ind_dest)

    # ── 3. Copy NNFXBridgeRunner.mq4 to MT4 Experts/ ─────────────────
    ea_src = Path(__file__).parent / "NNFXBridgeRunner.mq4"
    experts_dir = mt4_dir / "MQL4" / "Experts"
    experts_dir.mkdir(parents=True, exist_ok=True)
    ea_dest = experts_dir / "NNFXBridgeRunner.mq4"
    if ea_src.exists():
        shutil.copy2(ea_src, ea_dest)

    # ── 4. Write bridge_config_<run_id>.ini to Common/Files/ ──────────
    COMMON_FILES_DIR.mkdir(parents=True, exist_ok=True)
    output_subdir = f"bridge_output/{run_id}"
    bridge_config_path = COMMON_FILES_DIR / f"bridge_config_{run_id}.ini"
    bridge_config_content = (
        f"run_id={run_id}\n"
        f"indicator_name={indicator_name}\n"
        f"symbols={','.join(symbols)}\n"
        f"from_date={from_date}\n"
        f"to_date={to_date}\n"
        f"output_subdir={output_subdir}\n"
    )
    bridge_config_path.write_text(bridge_config_content, encoding="utf-8")

    # ── 5. Write ea_params_<run_id>.ini (.set file) ───────────────────
    ea_params_path = COMMON_FILES_DIR / f"ea_params_{run_id}.ini"
    ea_params_content = f"BridgeRunId={run_id}\n"
    ea_params_path.write_text(ea_params_content, encoding="utf-8")

    # ── 6. Write tester_<run_id>.ini ──────────────────────────────────
    tester_ini_path = COMMON_FILES_DIR / f"tester_{run_id}.ini"
    tester_ini_content = (
        "[Tester]\n"
        f"Expert={BRIDGE_EA_NAME}\n"
        f"ExpertParameters={ea_params_path}\n"
        f"Symbol={symbols[0]}\n"
        "Period=1440\n"
        "Deposit=10000\n"
        "Currency=USD\n"
        "Leverage=100\n"
        "Model=2\n"
        f"FromDate={from_date}\n"
        f"ToDate={to_date}\n"
        "Optimization=0\n"
        "Visual=0\n"
    )
    tester_ini_path.write_text(tester_ini_content, encoding="utf-8")

    return {
        "indicator_dest": ind_dest,
        "bridge_ea_src": ea_src,
        "bridge_config": bridge_config_path,
        "ea_params": ea_params_path,
        "tester_ini": tester_ini_path,
        "output_dir": output_subdir,
    }


def get_done_marker_path(run_id: str) -> Path:
    """Return path to bridge_done_<run_id>.txt in Common/Files output dir."""
    return COMMON_FILES_DIR / f"bridge_output/{run_id}/bridge_done_{run_id}.txt"


def get_output_dir(run_id: str) -> Path:
    """Return path to Common/Files/bridge_output/<run_id>/."""
    return COMMON_FILES_DIR / "bridge_output" / run_id


def _fmt_date(d) -> str:
    """Convert date string or None to MT4 format YYYY.MM.DD."""
    if not d:
        return ""
    s = str(d).strip()
    # Accept YYYY-MM-DD or YYYY.MM.DD
    return s.replace("-", ".")
