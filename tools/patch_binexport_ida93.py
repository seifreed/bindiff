#!/usr/bin/env python3
"""Patch older BinExport checkouts for IDA 9.3 PySide6 compatibility."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys


OLD = (
    "\"from PyQt5 import Qt; cb = Qt.QApplication.clipboard(); \"\n"
    "              \"cb.setText('\""
)

NEW = (
    "\"try:\\n\"\n"
    "              \"    from PySide6.QtWidgets import QApplication\\n\"\n"
    "              \"except ImportError:\\n\"\n"
    "              \"    from PyQt5.QtWidgets import QApplication\\n\"\n"
    "              \"cb = QApplication.clipboard(); \"\n"
    "              \"cb.setText('\""
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("binexport", help="Path to the BinExport source tree")
    args = parser.parse_args()

    root = Path(args.binexport)
    ui_cc = root / "ida" / "ui.cc"
    if not ui_cc.is_file():
        print(f"error: {ui_cc} not found", file=sys.stderr)
        return 1

    content = ui_cc.read_text(encoding="utf-8")
    if NEW in content:
        print(f"already patched: {ui_cc}")
        return 0
    if OLD not in content:
        print("error: expected PyQt5 clipboard snippet was not found", file=sys.stderr)
        return 1

    ui_cc.write_text(content.replace(OLD, NEW), encoding="utf-8")
    print(f"patched: {ui_cc}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
