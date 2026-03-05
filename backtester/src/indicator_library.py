import hashlib
import json
import uuid
from datetime import datetime, timezone
from pathlib import Path

_LIBRARY_ROOT = Path(__file__).parent.parent / "library" / "indicators"

ALLOWED_MODULE_TYPES = {"C1", "C2", "Vol", "Exit", "Baseline"}
ALLOWED_EXTENSIONS = {".mq4", ".ex4"}


def add_indicator(file, module_type: str, notes: str = "") -> dict:
    """Store file bytes, compute sha256, write index entry. Returns entry dict.
    Raises ValueError for bad module_type or extension."""
    if module_type not in ALLOWED_MODULE_TYPES:
        raise ValueError(f"Invalid module_type '{module_type}'. Allowed: {sorted(ALLOWED_MODULE_TYPES)}")

    raw_bytes, filename = _read_uploaded(file)
    ext = Path(filename).suffix.lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise ValueError(f"Invalid extension '{ext}'. Allowed: {sorted(ALLOWED_EXTENSIONS)}")

    _LIBRARY_ROOT.mkdir(parents=True, exist_ok=True)

    indicator_id = str(uuid.uuid4())
    stored_filename = f"{indicator_id}{ext}"
    stored_path = _LIBRARY_ROOT / stored_filename
    stored_path.write_bytes(raw_bytes)

    sha256 = hashlib.sha256(raw_bytes).hexdigest()
    entry = {
        "id": indicator_id,
        "name": Path(filename).stem,
        "file_name": stored_filename,
        "module_type": module_type,
        "uploaded_at": datetime.now(timezone.utc).isoformat(),
        "sha256": sha256,
        "notes": notes,
        "status": "active",
    }

    entries = _load_index()
    entries.append(entry)
    _save_index(entries)

    return entry


def list_indicators() -> list[dict]:
    """Read index.json. Returns [] if not found."""
    return _load_index()


def get_indicator(indicator_id: str) -> "dict | None":
    """Return single entry by id or None."""
    for entry in _load_index():
        if entry["id"] == indicator_id:
            return entry
    return None


def toggle_status(indicator_id: str, status: str) -> bool:
    """Set status to 'active' or 'inactive'. Return True if updated."""
    if status not in {"active", "inactive"}:
        raise ValueError(f"Invalid status '{status}'. Allowed: active, inactive")
    entries = _load_index()
    for entry in entries:
        if entry["id"] == indicator_id:
            entry["status"] = status
            _save_index(entries)
            return True
    return False


def _load_index() -> list[dict]:
    index_path = _LIBRARY_ROOT / "index.json"
    if not index_path.exists():
        return []
    with open(index_path, encoding="utf-8") as f:
        return json.load(f)


def _save_index(entries: list[dict]) -> None:
    _LIBRARY_ROOT.mkdir(parents=True, exist_ok=True)
    index_path = _LIBRARY_ROOT / "index.json"
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(entries, f, indent=2)


def _read_uploaded(file) -> tuple[bytes, str]:
    """Returns (bytes, filename)."""
    if hasattr(file, "read"):
        data = file.read()
        if hasattr(file, "seek"):
            file.seek(0)
        name = getattr(file, "name", "unknown.mq4")
        return data, name
    raise TypeError("Expected a file-like object with .read()")
