#!/usr/bin/env bash
# Render the RPM spec of a layered flavor from its template.
#
#   render-layered-spec.sh FLAVOR VERSION OUTPUT_SPEC PR_NUMBER [PR_NUMBER ...]
#
# FLAVOR selects the template, t3code-<flavor>-nightly.spec.in.
set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "usage: $0 FLAVOR VERSION OUTPUT_SPEC PR_NUMBER [PR_NUMBER ...]" >&2
  exit 64
fi

flavor="$1"
version="${2#v}"
output_spec="$3"
shift 3
pr_numbers=("$@")

if [[ ! "$flavor" =~ ^[a-z0-9]+$ ]]; then
  echo "unsupported flavor: $flavor" >&2
  exit 64
fi

template="t3code-${flavor}-nightly.spec.in"
if [[ ! -f "$template" ]]; then
  echo "no spec template for flavor $flavor: $template" >&2
  exit 66
fi

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-nightly\.[0-9]{8}\.[0-9]+$ ]]; then
  echo "unsupported T3 Code nightly version: $version" >&2
  exit 64
fi

for pr_number in "${pr_numbers[@]}"; do
  if [[ ! "$pr_number" =~ ^[0-9]+$ ]]; then
    echo "unsupported pull request number: $pr_number" >&2
    exit 64
  fi
done

datestamp="${version##*-nightly.}"
datestamp="${datestamp%%.*}"
changelog_date="$(date -u -d "$datestamp" '+%a %b %d %Y')"

# `pr_set` lands in the RPM release and must stay a plain dot-separated list;
# `pr_list` lands in the summary text and description.
pr_set="$(IFS=.; echo "${pr_numbers[*]}")"
pr_list="$(IFS=', '; echo "${pr_numbers[*]}")"

mkdir -p "$(dirname "$output_spec")"
sed \
  -e "s/@FLAVOR@/$flavor/g" \
  -e "s/@UPSTREAM_VERSION@/$version/g" \
  -e "s/@PR_SET@/$pr_set/g" \
  -e "s/@PR_LIST@/$pr_list/g" \
  -e "s/@CHANGELOG_DATE@/$changelog_date/g" \
  "$template" > "$output_spec"
