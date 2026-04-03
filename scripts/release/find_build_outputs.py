#!/usr/bin/env python3

import argparse
import json
import shlex
from pathlib import Path


PREFERRED_SUBSTRINGS = {
    "bindiff": ("bindiff-prefix",),
    "bindiff_config_setup": ("bindiff-prefix",),
    "bindiff_launcher_macos": ("bindiff-prefix",),
    "bindiff_ida64": ("bindiff-prefix", "ida"),
    "bindiff_ida": ("bindiff-prefix", "ida"),
    "binexport_ida64": ("binexport-build", "ida"),
    "binexport_ida": ("binexport-build", "ida"),
    "binexport2dump": ("binexport-build", "tools"),
}


def score_candidate(key: str, path: Path) -> tuple[int, int, int, str]:
    normalized = str(path).replace("\\", "/").lower()
    preferred_hits = sum(
        1 for part in PREFERRED_SUBSTRINGS.get(key, ()) if part in normalized
    )
    return (
        preferred_hits,
        -len(path.parts),
        -len(path.name),
        normalized,
    )


def pick_first(root: Path, patterns: tuple[str, ...], key: str) -> str:
    matches: list[Path] = []
    for pattern in patterns:
        matches.extend(root.rglob(pattern))
    files = [path for path in matches if path.is_file()]
    if not files:
        return ""
    files.sort(key=lambda path: score_candidate(key, path), reverse=True)
    return str(files[0].resolve())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("build_dir")
    parser.add_argument("--format", choices=("json", "shell"), default="json")
    args = parser.parse_args()

    build_dir = Path(args.build_dir).resolve()
    outputs = {
        "bindiff": pick_first(build_dir, ("bindiff.exe", "bindiff"), "bindiff"),
        "bindiff_config_setup": pick_first(
            build_dir,
            ("bindiff_config_setup.exe", "bindiff_config_setup"),
            "bindiff_config_setup",
        ),
        "bindiff_launcher_macos": pick_first(
            build_dir, ("bindiff_launcher_macos",), "bindiff_launcher_macos"
        ),
        "bindiff_ida64": pick_first(
            build_dir,
            ("bindiff8_ida64.dll", "bindiff8_ida64.so", "bindiff8_ida64.dylib"),
            "bindiff_ida64",
        ),
        "bindiff_ida": pick_first(
            build_dir,
            ("bindiff8_ida.dll", "bindiff8_ida.so", "bindiff8_ida.dylib"),
            "bindiff_ida",
        ),
        "binexport_ida64": pick_first(
            build_dir,
            (
                "binexport12_ida64.dll",
                "binexport12_ida64.so",
                "binexport12_ida64.dylib",
            ),
            "binexport_ida64",
        ),
        "binexport_ida": pick_first(
            build_dir,
            ("binexport12_ida.dll", "binexport12_ida.so", "binexport12_ida.dylib"),
            "binexport_ida",
        ),
        "binexport2dump": pick_first(
            build_dir, ("binexport2dump.exe", "binexport2dump"), "binexport2dump"
        ),
    }

    if args.format == "json":
        print(json.dumps(outputs, indent=2, sort_keys=True))
    else:
        for key, value in outputs.items():
            print(f"{key}={shlex.quote(value)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
