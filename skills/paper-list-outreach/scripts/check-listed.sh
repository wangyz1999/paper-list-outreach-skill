#!/usr/bin/env bash
# Dedup probe: does <owner/repo> already list this paper?
# Usage: ./check-listed.sh <owner/repo> "<paper title>" "<arxiv_id>" [extra_url ...]
#   arxiv_id is just the number, e.g. 2603.24329 (with or without version).
# Prints one of:
#   ALREADY_LISTED <signal>: <evidence line>
#   NOT_LISTED
# Strategy: pull the repo's markdown/list files (README + common data files) via the
# GitHub API tree, then grep for: arXiv id, any provided URL, and a distinctive
# lowercased n-gram from the title. Resilient to default-branch naming.
set -euo pipefail
repo="${1:?usage: check-listed.sh <owner/repo> \"<title>\" \"<arxiv_id>\" [url...]}"
title="${2:?need title}"
arxiv="${3:-}"
shift $(( $# >= 3 ? 3 : $# ))
urls=("$@")

authhdr=""
[[ -n "${GITHUB_TOKEN:-}" ]] && authhdr="Authorization: Bearer ${GITHUB_TOKEN}"
api() {
  if [[ -n "$authhdr" ]]; then curl -s -H "Accept: application/vnd.github+json" -H "$authhdr" "$@"
  else curl -s -H "Accept: application/vnd.github+json" "$@"; fi
}

# default branch
branch="$(api "https://api.github.com/repos/${repo}" | jq -r '.default_branch // "main"')"

# list candidate text files in the tree (md / json / yaml / csv / bib)
files=()
while IFS= read -r p; do
  [[ -n "$p" ]] && files+=("$p")
done < <(
  api "https://api.github.com/repos/${repo}/git/trees/${branch}?recursive=1" \
  | jq -r '.tree[]? | select(.type=="blob") | .path' \
  | grep -iE '\.(md|markdown|json|ya?ml|csv|bib|txt)$' \
  | grep -ivE '(license|contributing|code_of_conduct|changelog)\.' \
  | head -40
)
# always include README even if tree call was rate-limited/empty
[[ ${#files[@]} -eq 0 ]] && files=("README.md" "readme.md" "README.MD")

raw="https://raw.githubusercontent.com/${repo}/${branch}"
# distinctive lowercase title n-gram: first 6 significant words
ngram="$(printf '%s' "$title" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9 ' ' ' \
        | awk '{for(i=1;i<=6 && i<=NF;i++) printf "%s%s", $i, (i<6&&i<NF?" ":"")}')"

# NOTE: use grep with here-strings (not `printf | grep -q`). With `set -o pipefail`,
# grep -q exits early on a match and SIGPIPEs the upstream printf, making the pipeline
# return non-zero — which would flip a real MATCH into a false "miss". `contains` avoids that.
contains() { grep -qF -- "$2" <<<"$1"; }

hit=""
for f in "${files[@]}"; do
  body="$(curl -s "${raw}/${f}" 2>/dev/null || true)"
  [[ -z "$body" ]] && continue
  low="$(printf '%s' "$body" | tr 'A-Z' 'a-z')"
  if [[ -n "$arxiv" ]] && contains "$low" "$arxiv"; then
    hit="arxiv_id in ${f}"; break; fi
  for u in ${urls[@]+"${urls[@]}"}; do
    [[ -n "$u" ]] || continue
    # compare on a normalized form (strip scheme/trailing slash)
    nu="$(printf '%s' "$u" | sed -E 's#^https?://##; s#/$##' | tr 'A-Z' 'a-z')"
    if contains "$low" "$nu"; then hit="url ($u) in ${f}"; break 2; fi
  done
  # title n-gram: normalize BOTH the body and the n-gram to alnum+single-space
  # so punctuation/hyphens (e.g. "Video-MME:") don't defeat the match.
  if [[ -n "$ngram" ]]; then
    lown="$(printf '%s' "$low" | tr -cs 'a-z0-9 ' ' ' | tr -s ' ')"
    contains "$lown" "$ngram" && { hit="title-ngram in ${f}"; break; }
  fi
done

if [[ -n "$hit" ]]; then
  echo "ALREADY_LISTED ${hit}"
else
  echo "NOT_LISTED"
fi
