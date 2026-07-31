#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    printf 'Usage: %s OUTPUT_DIRECTORY\n' "$0" >&2
    exit 2
fi

: "${LIBRIME_X86_URL:?LIBRIME_X86_URL must be set}"
: "${LIBRIME_X86_SHA256:?LIBRIME_X86_SHA256 must be set}"
: "${LIBRIME_X64_URL:?LIBRIME_X64_URL must be set}"
: "${LIBRIME_X64_SHA256:?LIBRIME_X64_SHA256 must be set}"
: "${LIBRIME_DEPS_X86_URL:?LIBRIME_DEPS_X86_URL must be set}"
: "${LIBRIME_DEPS_X86_SHA256:?LIBRIME_DEPS_X86_SHA256 must be set}"

output_directory="$1"
temporary_directory="$(mktemp -d)"
trap 'rm -rf -- "${temporary_directory}"' EXIT

download_and_verify() {
    local url="$1"
    local expected_sha256="$2"
    local destination="$3"

    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --retry 3 \
        --retry-all-errors \
        --output "${destination}" \
        "${url}"
    printf '%s  %s\n' "${expected_sha256}" "${destination}" | sha256sum --check -
}

x86_archive="${temporary_directory}/librime-x86.7z"
x64_archive="${temporary_directory}/librime-x64.7z"
deps_x86_archive="${temporary_directory}/librime-deps-x86.7z"

download_and_verify \
    "${LIBRIME_X86_URL}" \
    "${LIBRIME_X86_SHA256}" \
    "${x86_archive}"
download_and_verify \
    "${LIBRIME_X64_URL}" \
    "${LIBRIME_X64_SHA256}" \
    "${x64_archive}"
download_and_verify \
    "${LIBRIME_DEPS_X86_URL}" \
    "${LIBRIME_DEPS_X86_SHA256}" \
    "${deps_x86_archive}"

mkdir -p \
    "${temporary_directory}/x86" \
    "${temporary_directory}/x64" \
    "${temporary_directory}/deps"
7z x -y "-o${temporary_directory}/x86" '-i!dist/lib/rime.dll' "${x86_archive}"
7z x -y "-o${temporary_directory}/x64" '-i!dist/lib/rime.dll' "${x64_archive}"
7z x -y "-o${temporary_directory}/deps" '-i!share/opencc' "${deps_x86_archive}"

test -f "${temporary_directory}/x86/dist/lib/rime.dll"
test -f "${temporary_directory}/x64/dist/lib/rime.dll"
test -d "${temporary_directory}/deps/share/opencc"

mkdir -p "${output_directory}"
cp "${temporary_directory}/x86/dist/lib/rime.dll" "${output_directory}/rime-x86.dll"
cp "${temporary_directory}/x64/dist/lib/rime.dll" "${output_directory}/rime-x64.dll"
cp -R "${temporary_directory}/deps/share/opencc" "${output_directory}/opencc"
