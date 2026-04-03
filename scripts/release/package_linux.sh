#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:?}"
ARCH="${ARCH:?}"
ASSET_DIR="${ASSET_DIR:?}"
VERSION="${VERSION:-8}"
BINDIFF_JAR="${BINDIFF_JAR:?}"
GHIDRA_BINEXPORT_ZIP="${GHIDRA_BINEXPORT_ZIP:-}"
export BUILD_DIR

eval "$(python "${ROOT_DIR}/scripts/release/find_build_outputs.py" "${BUILD_DIR}" --format shell)"

if [[ -z "${bindiff}" || -z "${bindiff_config_setup}" || -z "${binexport2dump}" ]]; then
  echo "Missing required build outputs for Linux packaging" >&2
  exit 1
fi

case "${ARCH}" in
  x64) deb_arch="amd64" ;;
  arm64) deb_arch="arm64" ;;
  *)
    echo "Unsupported Linux arch: ${ARCH}" >&2
    exit 1
    ;;
esac

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

stage_dir="${work_dir}/stage"
pkg_root="${stage_dir}/opt/bindiff"
mkdir -p "${stage_dir}"
cp -R "${ROOT_DIR}/packaging/deb/bindiff/files/." "${stage_dir}/"

mkdir -p \
  "${pkg_root}/bin" \
  "${pkg_root}/libexec" \
  "${pkg_root}/extra/config" \
  "${pkg_root}/extra/ghidra" \
  "${pkg_root}/plugins/idapro" \
  "${stage_dir}/etc/opt/bindiff" \
  "${stage_dir}/DEBIAN"

cp "${bindiff}" "${pkg_root}/bin/bindiff"
cp "${binexport2dump}" "${pkg_root}/bin/binexport2dump"
cp "${bindiff_config_setup}" "${pkg_root}/libexec/bindiff_config_setup"
cp "${BINDIFF_JAR}" "${pkg_root}/bin/bindiff.jar"
cp "${ROOT_DIR}/bindiff_config.proto" "${pkg_root}/extra/config/bindiff_config.proto"
cp "${ROOT_DIR}/bindiff.json" "${stage_dir}/etc/opt/bindiff/bindiff.json"

if [[ -n "${GHIDRA_BINEXPORT_ZIP}" && -f "${GHIDRA_BINEXPORT_ZIP}" ]]; then
  rm -rf "${pkg_root}/extra/ghidra"
  mkdir -p "${pkg_root}/extra/ghidra"
  unzip -q "${GHIDRA_BINEXPORT_ZIP}" -d "${pkg_root}/extra/ghidra"
fi

for plugin in "${bindiff_ida}" "${bindiff_ida64}" "${binexport_ida}" "${binexport_ida64}"; do
  if [[ -n "${plugin}" && -f "${plugin}" ]]; then
    cp "${plugin}" "${pkg_root}/plugins/idapro/"
  fi
done

"${JAVA_HOME:?}/bin/jlink" \
  --module-path "${JAVA_HOME}/jmods" \
  --no-header-files \
  --compress=2 \
  --strip-debug \
  --add-modules java.base,java.desktop,java.prefs,java.scripting,java.sql,jdk.unsupported,jdk.xml.dom \
  --output "${pkg_root}/jre"

cat > "${stage_dir}/DEBIAN/control" <<EOF
Package: bindiff
Version: ${VERSION}
Section: devel
Priority: optional
Architecture: ${deb_arch}
Maintainer: GitHub Actions
Depends: xdg-utils
Description: Find differences and similarities in disassembled code
 BinDiff is a comparison tool for binary files that helps to quickly find
 differences and similarities in disassembled code.
EOF

install -m 0755 "${ROOT_DIR}/packaging/deb/bindiff/debian/bindiff.postinst" \
  "${stage_dir}/DEBIAN/postinst"
install -m 0755 "${ROOT_DIR}/packaging/deb/bindiff/debian/bindiff.postrm" \
  "${stage_dir}/DEBIAN/postrm"

mkdir -p "${ASSET_DIR}"
dpkg-deb --build --root-owner-group "${stage_dir}" \
  "${ASSET_DIR}/bindiff_${VERSION}_${deb_arch}.deb"
