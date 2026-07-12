#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 VERSION OUTPUT_SPEC" >&2
  exit 64
fi

version="${1#v}"
output_spec="$2"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-nightly\.[0-9]{8}\.[0-9]+$ ]]; then
  echo "unsupported T3 Code nightly version: $version" >&2
  exit 64
fi

mkdir -p "$(dirname "$output_spec")"
sed "s/@UPSTREAM_VERSION@/$version/g" t3code-nightly.spec.in > "$output_spec"
