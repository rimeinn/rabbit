#!/usr/bin/env bash

set -euo pipefail

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"

curl_args=(
    --fail
    --silent
    --show-error
    --location
    --retry 3
    --retry-all-errors
    --header "Accept: application/vnd.github+json"
    --header "X-GitHub-Api-Version: 2022-11-28"
    --header "User-Agent: rimeinn-rabbit-ci"
)
if [[ -n "${GH_TOKEN:-}" ]]; then
    curl_args+=(--header "Authorization: Bearer ${GH_TOKEN}")
fi

release="$(curl "${curl_args[@]}" \
    "https://api.github.com/repos/rime/librime/releases/latest")"

tag_name="$(jq -er '.tag_name' <<<"${release}")"
printf 'Resolved librime release %s\n' "${tag_name}"
printf 'tag_name=%s\n' "${tag_name}" >>"${GITHUB_OUTPUT}"

write_asset_outputs() {
    local prefix="$1"
    local pattern="$2"
    local asset
    local name
    local url
    local digest
    local sha256

    asset="$(jq -cer --arg pattern "${pattern}" '
        [.assets[] | select(.name | test($pattern))]
        | if length == 1 then .[0]
          else error("expected exactly one matching release asset")
          end
    ' <<<"${release}")"
    name="$(jq -er '.name' <<<"${asset}")"
    url="$(jq -er '.browser_download_url' <<<"${asset}")"
    digest="$(jq -er '.digest' <<<"${asset}")"
    if [[ ! "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
        printf 'Release asset %s has no usable SHA-256 digest: %s\n' "${name}" "${digest}" >&2
        return 1
    fi
    sha256="${digest#sha256:}"

    printf 'Resolved %s\n' "${name}"
    {
        printf '%s_name=%s\n' "${prefix}" "${name}"
        printf '%s_url=%s\n' "${prefix}" "${url}"
        printf '%s_sha256=%s\n' "${prefix}" "${sha256}"
    } >>"${GITHUB_OUTPUT}"
}

write_asset_outputs \
    "x86" \
    '^rime-[0-9a-f]+-Windows-msvc-x86[.]7z$'
write_asset_outputs \
    "x64" \
    '^rime-[0-9a-f]+-Windows-msvc-x64[.]7z$'
write_asset_outputs \
    "deps_x86" \
    '^rime-deps-[0-9a-f]+-Windows-msvc-x86[.]7z$'
