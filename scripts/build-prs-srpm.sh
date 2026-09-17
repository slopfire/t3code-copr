#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 4 || $(( ($# - 2) % 2 )) -ne 0 ]]; then
  echo "usage: $0 TAG APPIMAGE PR_NUMBER PR_SHA [PR_NUMBER PR_SHA ...]" >&2
  exit 64
fi

tag="$1"
appimage="$2"
shift 2
pairs=("$@")
version="${tag#v}"

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
install -pm0644 packaging/t3code-prs.desktop "$topdir/SOURCES/t3code.desktop"
install -pm0644 packaging/LICENSE "$topdir/SOURCES/LICENSE"

{
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
for manifest in resolutions/*/conflicts.tsv; do
  printf 'Conflict carry:   %s\n' "$manifest" \
    >> "$topdir/SOURCES/upstream-prs.txt"
done

./scripts/render-prs-spec.sh "$version" "$topdir/SPECS/t3code-prs-nightly.spec" \
  "${pr_numbers[@]}"

rpmbuild --define "_topdir $topdir" -bs "$topdir/SPECS/t3code-prs-nightly.spec"
