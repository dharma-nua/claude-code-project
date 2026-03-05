from pathlib import Path

_LIBRARY_ROOT = Path(__file__).parent.parent.parent / "library" / "indicators"


def _locate_indicator_src(indicator_file: str) -> "Path | None":
    """Locate indicator file in the library. Returns Path or None."""
    if not indicator_file:
        return None
    path = _LIBRARY_ROOT / indicator_file
    if path.exists():
        return path
    # Try swapping extension .mq4 <-> .ex4
    alt_ext = ".ex4" if path.suffix.lower() == ".mq4" else ".mq4"
    alt_path = path.with_suffix(alt_ext)
    if alt_path.exists():
        return alt_path
    return None
