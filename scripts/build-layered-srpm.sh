#!/usr/bin/env bash
# Build the source RPM of a layered flavor.
#
#   build-layered-srpm.sh FLAVOR TAG APPIMAGE PR_NUMBER PR_SHA [PR_NUMBER PR_SHA ...]
#
# FLAVOR selects the spec template (t3code-<flavor>-nightly.spec.in) and the
# desktop entry (packaging/t3code-<flavor>.desktop).
set -euo pipefail

if [[ $# -lt 5 || $(( ($# - 3) % 2 )) -ne 0 ]]; then
  echo "usage: $0 FLAVOR TAG APPIMAGE PR_NUMBER PR_SHA [PR_NUMBER PR_SHA ...]" >&2
  exit 64
fi

flavor="$1"
tag="$2"
appimage="$3"
shift 3
pairs=("$@")
version="${tag#v}"

if [[ ! "$flavor" =~ ^[a-z0-9]+$ ]]; then
  echo "unsupported flavor: $flavor" >&2
  exit 64
fi

template="t3code-${flavor}-nightly.spec.in"
desktop="packaging/t3code-${flavor}.desktop"
for file in "$template" "$desktop"; do
  if [[ ! -f "$file" ]]; then
    echo "no $flavor flavor file: $file" >&2
    exit 66
  fi
done

if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-nightly\.[0-9]{8}\.[0-9]+$ ]]; then
  echo "unsupported T3 Code nightly tag: $tag" >&2
  exit 64
fi

if [[ ! -f "$appimage" ]]; then
  echo "AppImage not found: $appimage" >&2
  exit 66
fi

pr_numbers=()
pr_shas=()
for ((index = 0; index < ${#pairs[@]}; index += 2)); do
  number="${pairs[index]}"
  sha="${pairs[index + 1]}"
  if [[ ! "$number" =~ ^[0-9]+$ ]]; then
    echo "unsupported pull request number: $number" >&2
    exit 64
  fi
  if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
    echo "unsupported pull request commit: $sha" >&2
    exit 64
  fi
  pr_numbers+=("$number")
  pr_shas+=("$sha")
done

topdir="$PWD/rpmbuild"
mkdir -p "$topdir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

install -pm0755 "$appimage" "$topdir/SOURCES/T3-Code-${version}-x86_64.AppImage"
install -pm0755 packaging/t3code "$topdir/SOURCES/t3code"
install -pm0644 "$desktop" "$topdir/SOURCES/t3code.desktop"
install -pm0644 packaging/LICENSE "$topdir/SOURCES/LICENSE"

{
  echo "Flavor:           ${flavor}"
  echo "Upstream project: https://github.com/pingdotgg/t3code"
  echo "Base nightly tag: ${tag}"
  echo "AppImage built:   $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo
  echo "Layered upstream pull requests, in merge order:"
  for ((index = 0; index < ${#pr_numbers[@]}; index++)); do
    printf '  #%s https://github.com/pingdotgg/t3code/pull/%s\n' \
      "${pr_numbers[index]}" "${pr_numbers[index]}"
    printf '     head commit %s\n' "${pr_shas[index]}"
  done
} > "$topdir/SOURCES/upstream-prs.txt"

# The AppImage also carries the local patches from patches/ and, for pull
# requests that do not merge onto the nightly tag, the resolved files from
# resolutions/. The provenance file has to name them; otherwise it claims a
# pure pull-request build.
shopt -s nullglob
for patch in patches/*.patch; do
  printf 'Local patch:      %s (sha256 %s)\n' \
    "$(basename "$patch")" "$(sha256sum "$patch" | cut -d' ' -f1)" \
    >> "$topdir/SOURCES/upstream-prs.txt"
done
for ((index = 0; index < ${#pr_numbers[@]}; index++)); do
  manifest="resolutions/${pr_numbers[index]}/conflicts.tsv"
  if [[ -f "$manifest" ]]; then
    printf 'Conflict carry:   %s\n' "$manifest" \
      >> "$topdir/SOURCES/upstream-prs.txt"
  fi
done

./scripts/render-layered-spec.sh "$flavor" "$version" \
  "$topdir/SPECS/t3code-${flavor}-nightly.spec" "${pr_numbers[@]}"

rpmbuild --define "_topdir $topdir" -bs "$topdir/SPECS/t3code-${flavor}-nightly.spec"
