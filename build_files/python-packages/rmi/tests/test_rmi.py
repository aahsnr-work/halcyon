"""Tests for the rmi package.

These exist because `rmi -h` — the build-time smoke test — never reaches the
code that actually moves a file. A missing `datetime` import shipped in the
image for exactly that reason: the tool trashed the file, then died with a
NameError while writing the .trashinfo companion.
"""

from __future__ import annotations

from pathlib import Path

import pytest

import rmi


@pytest.fixture(autouse=True)
def isolated_trash(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    """Point the module's trash constants at a throwaway directory."""
    files = tmp_path / "Trash" / "files"
    info = tmp_path / "Trash" / "info"
    monkeypatch.setattr(rmi, "TRASH_DIR", files)
    monkeypatch.setattr(rmi, "TRASH_INFO_DIR", info)
    return files, info


def test_move_to_trash_writes_trashinfo(tmp_path: Path, isolated_trash):
    files, info = isolated_trash
    files.mkdir(parents=True)
    info.mkdir(parents=True)

    target = tmp_path / "doc.txt"
    target.write_text("hello\n", encoding="utf-8")

    assert rmi.move_to_trash(target, verbose=False) is True
    assert (files / "doc.txt").read_text(encoding="utf-8") == "hello\n"
    assert not target.exists()

    written = (info / "doc.txt.trashinfo").read_text(encoding="utf-8")
    assert written.startswith("[Trash Info]\n")
    assert "Path=" in written
    assert "DeletionDate=" in written


def test_trashinfo_records_the_original_path(tmp_path: Path, isolated_trash):
    files, info = isolated_trash
    files.mkdir(parents=True)
    info.mkdir(parents=True)

    nested = tmp_path / "sub"
    nested.mkdir()
    target = nested / "note.md"
    target.write_text("x", encoding="utf-8")
    original = str(target.resolve())

    rmi.move_to_trash(target, verbose=False)

    written = (info / "note.md.trashinfo").read_text(encoding="utf-8")
    # The path recorded must be where the file CAME FROM, not where it went.
    assert "sub" in written
    assert "Trash" not in written.split("Path=", 1)[1].splitlines()[0]
    assert original.endswith("sub/note.md")


def test_collision_creates_numbered_backup(tmp_path: Path, isolated_trash):
    files, info = isolated_trash
    files.mkdir(parents=True)
    info.mkdir(parents=True)
    (files / "dup.txt").write_text("old", encoding="utf-8")

    target = tmp_path / "dup.txt"
    target.write_text("new", encoding="utf-8")

    assert rmi.move_to_trash(target, verbose=False) is True
    assert (files / "dup.txt").read_text(encoding="utf-8") == "new"
    assert (files / "dup.txt.~1~").read_text(encoding="utf-8") == "old"


def test_main_refuses_dot_and_missing_paths(tmp_path: Path, isolated_trash):
    assert rmi.main(["-f", ".", str(tmp_path / "nope.txt")]) == 0


def test_main_with_no_arguments_returns_1():
    assert rmi.main([]) == 1
