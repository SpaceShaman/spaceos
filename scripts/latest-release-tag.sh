#!/usr/bin/bash
set -euo pipefail

tag=$(git tag --list 'v*' --sort=-version:refname \
    | grep --extended-regexp --max-count=1 '^v[0-9]+\.[0-9]+\.[0-9]+$' || true)

if [[ -z "$tag" ]]; then
    printf 'No release tag matching vMAJOR.MINOR.PATCH was found.\n' >&2
    exit 1
fi

printf '%s\n' "$tag"
