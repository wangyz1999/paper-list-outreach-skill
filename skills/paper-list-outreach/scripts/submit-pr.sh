#!/usr/bin/env bash
# Submit ONE paper-outreach PR at a time. You stay in control: nothing runs
# unless you invoke it with a specific repo, and it prints a plan first.
#
# Usage:
#   ./submit-pr.sh list                 # show all repos with their # id + folder
#   ./submit-pr.sh <id|folder>          # DRY RUN: show exactly what would happen
#   ./submit-pr.sh <id|folder> --go     # fork (if needed), push branch, open PR
#
# <id> is the number from the SUMMARY.md table. <folder> also works.
# BRANCH env var overrides the branch (default: add-paper).
# Requirements for --go: gh CLI installed + authenticated, else manual steps printed.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
BRANCH="${BRANCH:-add-paper}"

manifest_lookup() { awk -F'\t' -v f="$1" '$1==f{print $2}' manifest.tsv; }
id_to_slug() { awk -F'|' -v want="$1" '{gsub(/^[ \t]+|[ \t]+$/,"",$2)} $2==want{gsub(/^[ \t]+|[ \t]+$/,"",$4);print $4;exit}' SUMMARY.md; }
slug_to_folder() { awk -F'\t' -v s="$1" '$2==s{print $1;exit}' manifest.tsv; }

cmd="${1:-}"
if [[ -z "$cmd" || "$cmd" == "-h" || "$cmd" == "--help" ]]; then
  grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0
fi

if [[ "$cmd" == "list" ]]; then
  printf "%-4s %-44s %s\n" "ID" "FOLDER" "UPSTREAM REPO"
  printf "%-4s %-44s %s\n" "--" "------" "-------------"
  while IFS=$'\t' read -r folder slug url; do
    id="$(awk -F'|' -v s="$slug" '{gsub(/^[ \t]+|[ \t]+$/,"",$4)} $4==s{gsub(/^[ \t]+|[ \t]+$/,"",$2);print $2;exit}' SUMMARY.md 2>/dev/null)"
    printf "%-4s %-44s %s\n" "${id:-?}" "$folder" "$slug"
  done < manifest.tsv | sort -n
  exit 0
fi

if [[ "$cmd" =~ ^[0-9]+$ ]]; then
  slug="$(id_to_slug "$cmd")"
  [[ -n "$slug" ]] || { echo "ERROR: no SUMMARY.md row with id '$cmd'. Run: $0 list"; exit 1; }
  folder="$(slug_to_folder "$slug")"
  [[ -n "$folder" ]] || { echo "ERROR: id '$cmd' ($slug) has no manifest folder."; exit 1; }
else
  folder="$cmd"
fi
go=0; [[ "${2:-}" == "--go" ]] && go=1

[[ -d "repos/$folder/.git" ]] || { echo "ERROR: 'repos/$folder' is not a cloned repo. Run: $0 list"; exit 1; }
slug="$(manifest_lookup "$folder")"
[[ -n "$slug" ]] || { echo "ERROR: no manifest entry for '$folder'"; exit 1; }
upstream="https://github.com/$slug"
msgfile="pr-messages/${folder}.md"
title="$(head -1 "$msgfile")"

echo "============================================================"
echo " Repo folder : $folder"
echo " Repo ID     : $slug"
echo " Upstream    : $upstream"
echo " Branch      : $BRANCH"
echo " PR title    : $title"
echo " PR body     : $msgfile"
echo "------------------------------------------------------------"
echo " Change preview:"
git -C "repos/$folder" --no-pager show --stat "$BRANCH" | sed -n '1,12p'
echo "============================================================"

if [[ $go -eq 0 ]]; then
  echo "DRY RUN. Re-run with --go to submit:"
  echo "   $0 \"$cmd\" --go"
  exit 0
fi

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  echo ">> gh detected & authenticated. Forking + pushing + opening PR..."
  ME="$(gh api user -q .login)"
  forkslug="$ME/$(basename "$slug")"
  if ! gh repo view "$forkslug" >/dev/null 2>&1; then
    echo "   forking $slug -> $forkslug ..."
    gh repo fork "$slug" --clone=false
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      gh repo view "$forkslug" >/dev/null 2>&1 && break; sleep 2; done
    gh repo view "$forkslug" >/dev/null 2>&1 || { echo "ERROR: fork not available yet, re-run."; exit 1; }
  fi
  git -C "repos/$folder" remote remove fork 2>/dev/null || true
  git -C "repos/$folder" remote add fork "https://github.com/$forkslug.git"
  git -C "repos/$folder" push -u fork "$BRANCH" --force-with-lease
  body="$(tail -n +2 "$msgfile")"
  gh pr create --repo "$slug" --head "$ME:$BRANCH" --title "$title" --body "$body"
  echo ">> PR opened against $slug."
else
  echo ">> gh not available/authenticated. MANUAL STEPS:"
  echo "   1) Fork on the web:  $upstream"
  echo "   2) git -C \"$ROOT/repos/$folder\" remote add fork https://github.com/<YOU>/$(basename "$slug").git"
  echo "   3) git -C \"$ROOT/repos/$folder\" push -u fork $BRANCH"
  echo "   4) Open PR (base=upstream default, compare=<YOU>:$BRANCH); paste $ROOT/$msgfile"
fi
