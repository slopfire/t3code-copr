#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <flavor> <key>" >&2
  exit 2
fi

flavor=$1
key=$2

case "$flavor" in
  nightly)
    record_path=packaging/last-built-tag
    commit_label='T3 Code nightly'
    already_message="Nightly ${key} is already recorded"
    ;;
  prs|v2)
    record_path="packaging/${flavor}/last-built-key"
    if [[ "$flavor" == prs ]]; then
      commit_label='T3 Code prs nightly'
      already_message="prs nightly ${key} is already recorded"
    else
      commit_label='T3 Code v2 nightly'
      already_message="v2 nightly ${key} is already recorded"
    fi
    ;;
  v2-prs)
    record_path=packaging/v2-prs/last-built-key
    commit_label='T3 Code v2-prs nightly'
    already_message="v2-prs nightly ${key} is already recorded"
    ;;
  *)
    echo "unsupported flavor: $flavor" >&2
    exit 2
    ;;
esac

if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
  git config --global --add safe.directory "$GITHUB_WORKSPACE"
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  : "${GITHUB_TOKEN:?GITHUB_TOKEN is required without a checkout}"
  : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required without a checkout}"
  git init
  git remote add origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
  git fetch --depth=1 origin main
  git reset --hard FETCH_HEAD
  git branch -M main
fi

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'

mkdir -p "${record_path%/*}"
printf '%s\n' "$key" > "$record_path"
git add "$record_path"
if git diff --cached --quiet; then
  echo "$already_message"
  exit 0
fi
git commit -m "chore: record ${commit_label} ${key}"

max_attempts=5
for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  if push_output=$(git push origin HEAD:main 2>&1); then
    printf '%s\n' "$push_output"
    exit 0
  fi

  if [[ "$push_output" != *'(fetch first)'* && "$push_output" != *'(non-fast-forward)'* ]]; then
    printf '%s\n' "$push_output" >&2
    exit 1
  fi

  if (( attempt == max_attempts )); then
    printf '%s\n' "$push_output" >&2
    echo "record push failed after ${max_attempts} attempts" >&2
    exit 1
  fi

  echo "Record push raced with another workflow; retrying (${attempt}/${max_attempts})"
  git fetch origin main
  git reset --hard origin/main
  printf '%s\n' "$key" > "$record_path"
  git add "$record_path"
  if git diff --cached --quiet; then
    echo "$already_message"
    exit 0
  fi
  git commit -m "chore: record ${commit_label} ${key}"
done
