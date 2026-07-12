#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 TAG SOURCES_DIR" >&2
  exit 64
fi

tag="$1"
sources_dir="$2"
version="${tag#v}"

if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-nightly\.[0-9]{8}\.[0-9]+$ ]]; then
  echo "unsupported T3 Code nightly tag: $tag" >&2
  exit 64
fi

asset="T3-Code-${version}-x86_64.AppImage"
url="https://github.com/pingdotgg/t3code/releases/download/${tag}/${asset}"

mkdir -p "$sources_dir"
curl --fail --location --retry 3 --output "$sources_dir/$asset" "$url"
chmod 0755 "$sources_dir/$asset"
