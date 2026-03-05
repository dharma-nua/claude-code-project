import io
import json
from pathlib import Path
from unittest import mock

import pytest

import src.indicator_library as lib


def _make_fake_file(content: bytes = b"void OnInit(){}", name: str = "test_ea.mq4"):
    buf = io.BytesIO(content)
    buf.name = name
    return buf


def _patch_library_root(tmp_path):
    """Patch the library root to use tmp_path."""
    root = tmp_path / "indicators"
    return mock.patch.object(lib, "_LIBRARY_ROOT", root)


class TestIndicatorLibrary:
    def test_add_indicator_writes_file_and_index(self, tmp_path):
        with _patch_library_root(tmp_path):
            f = _make_fake_file()
            entry = lib.add_indicator(f, "C1", notes="test note")

        root = tmp_path / "indicators"
        assert entry["module_type"] == "C1"
        assert entry["status"] == "active"
        assert entry["name"] == "test_ea"
        assert (root / entry["file_name"]).exists()
        index = json.loads((root / "index.json").read_text())
        assert len(index) == 1
        assert index[0]["id"] == entry["id"]

    def test_add_indicator_invalid_extension_raises(self, tmp_path):
        with _patch_library_root(tmp_path):
            f = _make_fake_file(name="bad_script.py")
            with pytest.raises(ValueError, match="extension"):
                lib.add_indicator(f, "C1")

    def test_add_indicator_invalid_module_type_raises(self, tmp_path):
        with _patch_library_root(tmp_path):
            f = _make_fake_file()
            with pytest.raises(ValueError, match="module_type"):
                lib.add_indicator(f, "Foo")

    def test_list_indicators_empty_when_no_index(self, tmp_path):
        with _patch_library_root(tmp_path):
            result = lib.list_indicators()
        assert result == []

    def test_toggle_status_changes_status(self, tmp_path):
        with _patch_library_root(tmp_path):
            f = _make_fake_file()
            entry = lib.add_indicator(f, "C1")
            assert entry["status"] == "active"

            updated = lib.toggle_status(entry["id"], "inactive")
            assert updated is True

            retrieved = lib.get_indicator(entry["id"])
            assert retrieved["status"] == "inactive"
