#!/usr/bin/env bash
# Resolve the newest upstream T3 Code nightly tag.
#
# Upstream publishes two prerelease channels: `-nightly.` (supported nightly
# builds) and `-preview.` (maintainer test builds, explicitly unsupported).
# Only nightly tags are eligible. We sort explicitly by published_at because
# the GitHub releases API does not guarantee newest-first ordering.
set -euo pipefail

repo="${T3CODE_REPO:-pingdotgg/t3code}"
api_url="https://api.github.com/repos/${repo}/releases?per_page=100"
tag_pattern='^v[0-9]+\.[0-9]+\.[0-9]+-nightly\.[0-9]{8}\.[0-9]+$'

auth_args=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  auth_args=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

response="$(curl --fail --silent --show-error --location \
  --retry 5 --retry-delay 2 --retry-all-errors \
  "${auth_args[@]}" \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "$api_url")"

tag="$(jq -r --arg pattern "$tag_pattern" '
  [ .[]
    | select(.prerelease and (.draft | not))
    | select(.tag_name | test($pattern))
  ]
  | sort_by(.published_at)
  | reverse
  | .[0].tag_name // empty
' <<<"$response")"

if [[ -z "$tag" ]]; then
  echo "No T3 Code nightly release found in ${repo}." >&2
  echo "Newest prereleases observed:" >&2
  jq -r '[ .[] | select(.prerelease and (.draft | not)) ][0:10][]
    | "  \(.published_at)  \(.tag_name)"' <<<"$response" >&2
  exit 1
fi

printf '%s\n' "$tag"
