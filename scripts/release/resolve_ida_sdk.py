#!/usr/bin/env python3

import argparse
import json
from pathlib import Path


ARCHIVE_SUFFIXES = (".zip", ".tar.gz", ".tgz")
EXPECTED_LIBRARIES = {
    ("windows", "x64"): ("lib/x64_win_vc_64/ida.lib",),
    ("windows", "arm64"): ("lib/arm64_win_vc_64/ida.lib",),
    ("linux", "x64"): ("lib/x64_linux_gcc_64/libida.so",),
    ("linux", "arm64"): ("lib/arm64_linux_gcc_64/libida.so",),
    ("macos", "x64"): ("lib/x64_mac_clang_64/libida.dylib",),
    ("macos", "arm64"): ("lib/arm64_mac_clang_64/libida.dylib",),
}


def supports_target(sdk_root: Path, os_name: str, arch: str) -> bool:
    expected = EXPECTED_LIBRARIES.get((os_name, arch), ())
    if not expected:
        return False
    return any((sdk_root / relative_path).exists() for relative_path in expected)


def sdk_root_from_tree(root: Path, os_name: str, arch: str) -> str:
    for header in root.rglob("pro.h"):
        if header.parent.name != "include":
            continue
        candidate = header.parent.parent
        if candidate.is_dir() and supports_target(candidate, os_name, arch):
            return str(candidate.resolve())
    return ""


def archive_candidates(root: Path, os_name: str, arch: str) -> list[Path]:
    tokens = {
        os_name.lower(),
        arch.lower(),
        f"{os_name.lower()}-{arch.lower()}",
        f"{os_name.lower()}_{arch.lower()}",
        f"idasdk-{os_name.lower()}-{arch.lower()}",
        f"idasdk_{os_name.lower()}_{arch.lower()}",
    }
    matches: list[Path] = []
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        path_name = path.name.lower()
        if not any(
            path_name.endswith(suffix)
            for suffix in ARCHIVE_SUFFIXES
        ):
            continue
        if any(token in path_name for token in tokens):
            matches.append(path.resolve())
    matches.sort(key=lambda item: (len(item.parts), str(item).lower()))
    return matches


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("repo_root")
    parser.add_argument("--os", required=True, dest="os_name")
    parser.add_argument("--arch", required=True)
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    os_name = args.os_name.lower()
    arch = args.arch.lower()

    search_roots = [
        repo_root / os_name / arch,
        repo_root / "sdk" / os_name / arch,
        repo_root / "idasdk" / os_name / arch,
        repo_root / f"{os_name}-{arch}",
        repo_root / f"{os_name}_{arch}",
        repo_root,
    ]

    sdk_root = ""
    for search_root in search_roots:
        if not search_root.exists():
            continue
        sdk_root = sdk_root_from_tree(search_root, os_name, arch)
        if sdk_root:
            break

    archive = ""
    if not sdk_root:
        archives = archive_candidates(repo_root, os_name, arch)
        if archives:
            archive = str(archives[0])

    print(json.dumps({"sdk_root": sdk_root, "archive": archive}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
