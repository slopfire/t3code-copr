#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 VERSION PR_NUMBER OUTPUT_SPEC" >&2
  exit 64
fi

version="${1#v}"
pr_number="$2"
output_spec="$3"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-nightly\.[0-9]{8}\.[0-9]+$ ]]; then
  echo "unsupported T3 Code nightly version: $version" >&2
  exit 64
fi

if [[ ! "$pr_number" =~ ^[0-9]+$ ]]; then
  echo "unsupported pull request number: $pr_number" >&2
  exit 64
fi

datestamp="${version##*-nightly.}"
datestamp="${datestamp%%.*}"
changelog_date="$(date -u -d "$datestamp" '+%a %b %d %Y')"

mkdir -p "$(dirname "$output_spec")"
sed \
  -e "s/@UPSTREAM_VERSION@/$version/g" \
  -e "s/@PR_NUMBER@/$pr_number/g" \
  -e "s/@CHANGELOG_DATE@/$changelog_date/g" \
  t3code-cmd-nightly.spec.in > "$output_spec"
