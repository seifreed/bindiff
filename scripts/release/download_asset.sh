#!/usr/bin/env bash

set -euo pipefail

URL="${1:?usage: download_asset.sh <url> <output> [sha256]}"
OUTPUT="${2:?usage: download_asset.sh <url> <output> [sha256]}"
SHA256_EXPECTED="${3:-}"

mkdir -p "$(dirname "${OUTPUT}")"

curl_args=(-L --fail --show-error --output "${OUTPUT}")
if [[ -n "${DOWNLOAD_AUTH_HEADER:-}" ]]; then
  curl_args=(-H "${DOWNLOAD_AUTH_HEADER}" "${curl_args[@]}")
fi

curl "${curl_args[@]}" "${URL}"

if [[ -n "${SHA256_EXPECTED}" ]]; then
  actual="$(sha256sum "${OUTPUT}" | awk '{print $1}')"
  if [[ "${actual}" != "${SHA256_EXPECTED}" ]]; then
    echo "SHA256 mismatch for ${OUTPUT}" >&2
    echo "expected: ${SHA256_EXPECTED}" >&2
    echo "actual:   ${actual}" >&2
    exit 1
  fi
fi
