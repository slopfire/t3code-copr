#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 TAG" >&2
  exit 64
fi

topdir="$PWD/rpmbuild"
mkdir -p "$topdir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

./scripts/prepare-source.sh "$1" "$topdir/SOURCES"
install -pm0755 packaging/t3code "$topdir/SOURCES/t3code"
install -pm0644 packaging/t3code.desktop "$topdir/SOURCES/t3code.desktop"
install -pm0644 packaging/LICENSE "$topdir/SOURCES/LICENSE"
./scripts/render-spec.sh "$1" "$topdir/SPECS/t3code-nightly.spec"

rpmbuild --define "_topdir $topdir" -bs "$topdir/SPECS/t3code-nightly.spec"
