#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 TAG PR_NUMBER PR_SHA APPIMAGE" >&2
  exit 64
fi

tag="$1"
pr_number="$2"
pr_sha="$3"
appimage="$4"
version="${tag#v}"

if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-nightly\.[0-9]{8}\.[0-9]+$ ]]; then
  echo "unsupported T3 Code nightly tag: $tag" >&2
  exit 64
fi

if [[ ! "$pr_number" =~ ^[0-9]+$ ]]; then
  echo "unsupported pull request number: $pr_number" >&2
  exit 64
fi

if [[ ! -f "$appimage" ]]; then
  echo "AppImage not found: $appimage" >&2
  exit 66
fi

topdir="$PWD/rpmbuild"
mkdir -p "$topdir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

install -pm0755 "$appimage" "$topdir/SOURCES/T3-Code-${version}-x86_64.AppImage"
install -pm0755 packaging/t3code "$topdir/SOURCES/t3code"
install -pm0644 packaging/t3code-cmd.desktop "$topdir/SOURCES/t3code.desktop"
install -pm0644 packaging/LICENSE "$topdir/SOURCES/LICENSE"

cat > "$topdir/SOURCES/upstream-pr-${pr_number}.txt" <<EOF
Upstream project: https://github.com/pingdotgg/t3code
Base nightly tag: ${tag}
Pull request:     https://github.com/pingdotgg/t3code/pull/${pr_number}
PR head commit:   ${pr_sha}
AppImage built:   $(date -u '+%Y-%m-%dT%H:%M:%SZ')
EOF

# The AppImage also carries the local patches from patches/, so the provenance
# file has to name them; otherwise it claims a pure pull-request build.
for patch in patches/*.patch; do
  [[ -e "$patch" ]] || continue
  printf 'Local patch:      %s (sha256 %s)\n' \
    "$(basename "$patch")" "$(sha256sum "$patch" | cut -d' ' -f1)" \
    >> "$topdir/SOURCES/upstream-pr-${pr_number}.txt"
done

./scripts/render-cmd-spec.sh "$version" "$pr_number" \
  "$topdir/SPECS/t3code-cmd-nightly.spec"

rpmbuild --define "_topdir $topdir" -bs "$topdir/SPECS/t3code-cmd-nightly.spec"
