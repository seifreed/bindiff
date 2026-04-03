#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:?}"
ARCH="${ARCH:?}"
ASSET_DIR="${ASSET_DIR:?}"
VERSION="${VERSION:-8}"
BINDIFF_JAR="${BINDIFF_JAR:?}"
GHIDRA_BINEXPORT_ZIP="${GHIDRA_BINEXPORT_ZIP:-}"

eval "$(python "${ROOT_DIR}/scripts/release/find_build_outputs.py" "${BUILD_DIR}" --format shell)"

if [[ -z "${bindiff}" || -z "${bindiff_config_setup}" || -z "${binexport2dump}" || -z "${bindiff_launcher_macos}" ]]; then
  echo "Missing required build outputs for macOS packaging" >&2
  exit 1
fi

case "${ARCH}" in
  x64) mac_arch="x86_64" ;;
  arm64) mac_arch="arm64" ;;
  *)
    echo "Unsupported macOS arch: ${ARCH}" >&2
    exit 1
    ;;
esac

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

pkg_stage="${work_dir}/Package"
app_dir="${pkg_stage}/Applications/BinDiff"
mkdir -p "${work_dir}/jar" "${app_dir}"
cp -R "${ROOT_DIR}/packaging/dmg/Package/." "${pkg_stage}/"
cp "${BINDIFF_JAR}" "${work_dir}/jar/bindiff.jar"

"${JAVA_HOME:?}/bin/jpackage" \
  --type app-image \
  --app-version "${VERSION}" \
  --copyright '(c)2004-2011 zynamics GmbH, (c)2011-2025 Google LLC' \
  --description 'Find similarities and differences in disassembled code' \
  --name BinDiff \
  --dest "${app_dir}" \
  --vendor 'Google LLC' \
  --add-modules java.base,java.desktop,java.prefs,java.scripting,java.sql,jdk.unsupported,jdk.xml.dom \
  --module-path "${JAVA_HOME}/jmods" \
  --icon "${ROOT_DIR}/packaging/dmg/bindiff-appicon-macos.icns" \
  --input "${work_dir}/jar" \
  --main-jar bindiff.jar \
  --mac-package-name BinDiff

mkdir -p \
  "${app_dir}/BinDiff.app/Contents/MacOS/bin" \
  "${app_dir}/Extra/Config" \
  "${app_dir}/Extra/Ghidra" \
  "${app_dir}/Plugins/IDA Pro"

cp "${bindiff}" "${app_dir}/BinDiff.app/Contents/MacOS/bin/"
cp "${bindiff_config_setup}" "${app_dir}/BinDiff.app/Contents/MacOS/bin/"
cp "${binexport2dump}" "${app_dir}/BinDiff.app/Contents/MacOS/bin/"
cp "${bindiff_launcher_macos}" "${app_dir}/BinDiff.app/Contents/MacOS/BinDiff"
cp "${ROOT_DIR}/bindiff_config.proto" "${app_dir}/Extra/Config/bindiff_config.proto"
cp "${ROOT_DIR}/bindiff.json" "${pkg_stage}/Library/Application Support/BinDiff/bindiff.json"

if [[ -n "${GHIDRA_BINEXPORT_ZIP}" && -f "${GHIDRA_BINEXPORT_ZIP}" ]]; then
  rm -rf "${app_dir}/Extra/Ghidra"
  mkdir -p "${app_dir}/Extra/Ghidra"
  unzip -q "${GHIDRA_BINEXPORT_ZIP}" -d "${app_dir}/Extra/Ghidra"
fi

for plugin in "${bindiff_ida}" "${bindiff_ida64}" "${binexport_ida}" "${binexport_ida64}"; do
  if [[ -n "${plugin}" && -f "${plugin}" ]]; then
    cp "${plugin}" "${app_dir}/Plugins/IDA Pro/"
  fi
done

pkg_path="${work_dir}/bindiff-${ARCH}.pkg"
pkgbuild \
  --root "${pkg_stage}" \
  --install-location / \
  --component-plist "${ROOT_DIR}/packaging/dmg/BinDiff.plist" \
  --scripts "${ROOT_DIR}/packaging/dmg/Scripts" \
  "${work_dir}/BinDiff.pkg"
productbuild \
  --distribution "${ROOT_DIR}/packaging/dmg/Distribution.xml" \
  --package-path "${work_dir}" \
  --resources "${ROOT_DIR}/packaging/dmg/Resources" \
  "${pkg_path}"

dmg_root="${work_dir}/dmg-root"
mkdir -p "${dmg_root}"
cp "${pkg_path}" "${dmg_root}/Install BinDiff.pkg"

mkdir -p "${ASSET_DIR}"
hdiutil create \
  -volname "BinDiff" \
  -srcfolder "${dmg_root}" \
  -ov \
  -format UDZO \
  "${ASSET_DIR}/BinDiff${VERSION}-macos-${ARCH}.dmg"
