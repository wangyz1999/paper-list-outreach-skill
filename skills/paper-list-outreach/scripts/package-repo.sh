#!/usr/bin/env bash
# Commit the in-place edit on a branch, export a patch, append a manifest line.
# Run from the workspace root (the dir containing repos/, patches/, manifest.tsv).
# Usage: ./package-repo.sh <folder-under-repos/> [branch]
set -euo pipefail
folder="${1:?usage: package-repo.sh <folder> [branch]}"
branch="${2:-add-paper}"
root="$(pwd)"
d="repos/${folder}"
[[ -d "$d/.git" ]] || { echo "ERROR: $d is not a git clone"; exit 1; }
mkdir -p patches

git -C "$d" config user.email "paper-outreach@local"
git -C "$d" config user.name  "Paper Outreach"
if git -C "$d" diff --quiet && git -C "$d" diff --cached --quiet; then
  echo "ERROR: no changes in $d — edit it first"; exit 1
fi
git -C "$d" checkout -B "$branch" >/dev/null 2>&1
git -C "$d" add -A
git -C "$d" commit -q -m "Add paper to the list" || true
git -C "$d" format-patch -1 --stdout > "patches/${folder}.patch"

url="$(git -C "$d" config --get remote.origin.url)"
slug="$(printf '%s' "$url" | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
printf "%s\t%s\t%s\n" "$folder" "$slug" "$url" >> "${root}/manifest.tsv"
echo "packaged ${folder} -> ${slug} (branch ${branch}, patch patches/${folder}.patch)"
