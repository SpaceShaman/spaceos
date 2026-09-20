#!/usr/bin/bash
set -euo pipefail

image=${1:?Usage: resolve-base-image.sh IMAGE}

if ! command -v skopeo >/dev/null 2>&1; then
    printf 'skopeo is required to resolve %s\n' "$image" >&2
    exit 1
fi

digest=$(skopeo inspect --format '{{.Digest}}' "docker://${image}")
if [[ ! "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    printf 'Registry returned an invalid digest for %s: %s\n' "$image" "$digest" >&2
    exit 1
fi

printf '%s@%s\n' "${image%%@*}" "$digest"
