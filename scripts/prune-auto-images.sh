#!/usr/bin/bash
set -euo pipefail

owner=${1:?Usage: prune-auto-images.sh OWNER PACKAGE [KEEP]}
package=${2:?Usage: prune-auto-images.sh OWNER PACKAGE [KEEP]}
keep=${3:-5}

if [[ ! "$keep" =~ ^[0-9]+$ ]]; then
    printf 'KEEP must be a non-negative integer.\n' >&2
    exit 2
fi

owner_type=$(gh api "users/${owner}" --jq '.type')
case "$owner_type" in
    Organization)
        endpoint="orgs/${owner}/packages/container/${package}/versions"
        ;;
    User)
        endpoint="users/${owner}/packages/container/${package}/versions"
        ;;
    *)
        printf 'Unsupported GitHub owner type: %s\n' "$owner_type" >&2
        exit 1
        ;;
esac

versions=$(mktemp)
trap 'rm -f "$versions"' EXIT

gh api --paginate "$endpoint?per_page=100" \
    | jq --slurp 'add' >"$versions"

mapfile -t delete_ids < <(
    jq --raw-output --argjson keep "$keep" '
        [
            .[]
            | select(any(.metadata.container.tags[]?; test("^auto-v[0-9]+\\.[0-9]+\\.[0-9]+-[0-9]{8}-[0-9a-f]{12}$")))
            | select(all(.metadata.container.tags[]?; test("^v[0-9]+\\.[0-9]+\\.[0-9]+$") | not))
        ]
        | sort_by(.created_at)
        | reverse
        | .[$keep:]
        | .[].id
    ' "$versions"
)

if (( ${#delete_ids[@]} == 0 )); then
    printf 'No automatic image versions need pruning.\n'
    exit 0
fi

for id in "${delete_ids[@]}"; do
    printf 'Deleting automatic package version %s\n' "$id"
    gh api --method DELETE "${endpoint}/${id}"
done
