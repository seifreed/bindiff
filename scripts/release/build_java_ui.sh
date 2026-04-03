#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_JAR="${1:?usage: build_java_ui.sh <output-jar>}"
YFILES_ARCHIVE="${YFILES_ARCHIVE:-}"
YFILES_DIR_INPUT="${YFILES_DIR:-}"

extract_yfiles_dir() {
  local work_dir="$1"
  local archive="$2"
  mkdir -p "${work_dir}"
  case "${archive}" in
    *.zip)
      unzip -q "${archive}" -d "${work_dir}"
      ;;
    *.tar.gz|*.tgz)
      tar -xzf "${archive}" -C "${work_dir}"
      ;;
    *)
      echo "Unsupported YFiles archive format: ${archive}" >&2
      exit 1
      ;;
  esac
  find "${work_dir}" -type f \( -name 'y.jar' -o -name 'ysvg.jar' \) -print -quit \
    | xargs -r dirname
}

if [[ -n "${YFILES_DIR_INPUT}" ]]; then
  export YFILES_DIR="${YFILES_DIR_INPUT}"
elif [[ -n "${YFILES_ARCHIVE}" ]]; then
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "${temp_dir}"' EXIT
  export YFILES_DIR
  YFILES_DIR="$(extract_yfiles_dir "${temp_dir}" "${YFILES_ARCHIVE}")"
else
  echo "Set YFILES_DIR or YFILES_ARCHIVE to build bindiff.jar" >&2
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT_JAR}")"
(cd "${ROOT_DIR}/java" && gradle --no-daemon ui:obfuscatedJar)
cp "${ROOT_DIR}/java/ui/build/libs/bindiff-ui-all.out.jar" "${OUTPUT_JAR}"
