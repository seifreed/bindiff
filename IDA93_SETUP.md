# BinDiff + IDA Pro 9.3

This tree is now prepared to build against the IDA SDK 9.x layout used by
IDA Pro 9.2 and 9.3.

## What changed

* `cmake/FindIdaSdk.cmake` now understands the SDK 9.x library layout.
* `cmake/BinDiffCompat.cmake` warns when `IdaSdk_ROOT_DIR` points to an IDA
  installation directory instead of the standalone SDK.
* `CMakeLists.txt` now prefers `build/binexport` when present, which matches
  the repository build instructions.
* `build_ida93.bat` provides a Windows helper for IDA 9.3 builds.

## Important distinction: IDA install vs. IDA SDK

An updated installation like:

`C:\Program Files\IDA Professional 9.0`

can contain IDA 9.3 binaries and Qt6 runtime files, but it is still not enough
to compile plugins unless it also contains the full SDK files:

* `include/pro.h`
* `lib/x64_win_vc_64/ida.lib`

If those files are missing, use the extracted IDA SDK 9.3 package from
Hex-Rays.

## Windows build

1. Clone or unpack BinExport into `build/binexport`, or keep it elsewhere.
2. Extract the IDA SDK 9.3 somewhere like `C:\idasdk93`.
3. Run:

```bat
build_ida93.bat C:\idasdk93
```

Or, with an explicit BinExport path:

```bat
build_ida93.bat C:\idasdk93 C:\src\binexport
```

## BinExport PySide6 note

BinDiff itself is a native C++ IDA plugin, so the main 9.3 migration is about
the SDK layout, not Qt widget code in this repository.

However, older BinExport checkouts contain an IDAPython clipboard helper in
`ida/ui.cc` that imports `PyQt5`. On IDA 9.3 that should be migrated to
`PySide6` or guarded with a fallback.

This repository includes an optional helper script for patching an older
BinExport checkout in place:

```bat
python tools\patch_binexport_ida93.py C:\src\binexport
```
