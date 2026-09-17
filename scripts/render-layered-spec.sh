#!/usr/bin/env bash
# Render the RPM spec of a layered flavor from the shared template.
#
#   render-layered-spec.sh FLAVOR VERSION OUTPUT_SPEC PR_NUMBER [PR_NUMBER ...]
#
# FLAVOR only selects the packaging notes: the spec template itself is shared
# (t3code-layered-nightly.spec.in), because the flavors differ in what they
# carry, not in how the package is laid out. Adding a flavor means adding a case
# arm below, not copying a spec.
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

# Hyphens are allowed inside a flavor name: the package is
# t3code-<flavor>-nightly, so `v2-prs` becomes t3code-v2-prs-nightly.
if [[ ! "$flavor" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "unsupported flavor: $flavor" >&2
  exit 64
fi

case "$flavor" in
  prs)
    flavor_note="with upstream pull requests layered"
    flavor_detail=" The pull request set leads with the Command Code provider."
    ;;
  v2)
    flavor_note="with the new orchestrator and the Pi provider"
    flavor_detail=" The pull request set is the unmerged orchestrator rewrite, which carries the Pi coding agent driver and the generic ACP provider registry, and no local patches are applied."
    ;;
  v2-prs)
    flavor_note="with the new orchestrator, the Pi provider, and the Command Code and Oh My Pi integrations"
    flavor_detail=" The pull request set is the unmerged orchestrator rewrite, and the local patches add the Command Code provider and the bundled Oh My Pi ACP registry entry, which main-side pull requests cannot supply because those drivers target main's adapter interface."
    ;;
  *)
    echo "unknown flavor: $flavor" >&2
    exit 64
    ;;
esac

template="t3code-layered-nightly.spec.in"
if [[ ! -f "$template" ]]; then
  echo "missing shared spec template: $template" >&2
  exit 66
fi

# The stamp is upstream's `<date>.<time>`, or `<date>.<short commit>` for a
# flavor that pins a commit instead of tracking a nightly tag.
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-nightly\.[0-9]{8}\.([0-9]+|[0-9a-f]{4,})$ ]]; then
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

# sed replacements, with the characters that would be special in a sed
# replacement escaped: a flavor note is prose, not a pattern.
escape() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }

mkdir -p "$(dirname "$output_spec")"
sed \
  -e "s|@FLAVOR@|$(escape "$flavor")|g" \
  -e "s|@UPSTREAM_VERSION@|$(escape "$version")|g" \
  -e "s|@PR_SET@|$(escape "$pr_set")|g" \
  -e "s|@PR_LIST@|$(escape "$pr_list")|g" \
  -e "s|@FLAVOR_NOTE@|$(escape "$flavor_note")|g" \
  -e "s|@FLAVOR_DETAIL@|$(escape "$flavor_detail")|g" \
  -e "s|@CHANGELOG_DATE@|$(escape "$changelog_date")|g" \
  "$template" > "$output_spec"
