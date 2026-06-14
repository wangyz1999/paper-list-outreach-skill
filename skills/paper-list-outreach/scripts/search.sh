#!/usr/bin/env bash
# GitHub repo search -> TSV (full_name, stars, last-push date, description).
# Usage: ./search.sh "<query>" [stars|updated]
# Default sort is stars (updated surfaces bot "awesome-stars" noise).
# Honors GITHUB_TOKEN if set (much higher rate limit).
set -euo pipefail
q="${1:?usage: search.sh \"<query>\" [stars|updated]}"
sort="${2:-stars}"
authargs=()
[[ -n "${GITHUB_TOKEN:-}" ]] && authargs=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
curl -s -G "https://api.github.com/search/repositories" \
  --data-urlencode "q=${q}" \
  --data-urlencode "sort=${sort}" \
  --data-urlencode "order=desc" \
  --data-urlencode "per_page=30" \
  -H "Accept: application/vnd.github+json" \
  ${authargs[@]+"${authargs[@]}"} \
| jq -r '.items[]? | [.full_name, (.stargazers_count|tostring), (.pushed_at|split("T")[0]), (.description // "")] | @tsv'
