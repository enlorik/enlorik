#!/usr/bin/env bash
# Rebuilds the "Merged upstream" table in README.md between the
# upstream-prs markers. Only lists merges into repos with > MIN_STARS stars.
set -euo pipefail

USER="enlorik"
MIN_STARS=100
README="README.md"
TABLE="$(mktemp)"
trap 'rm -f "$TABLE"' EXIT

: > "$TABLE"

found=0
while IFS=$'\t' read -r repo number title url merged; do
  stars=$(gh api "repos/$repo" --jq '.stargazers_count')
  [ "$stars" -ge "$MIN_STARS" ] || continue
  owner="${repo%%/*}"
  month=$(date -u -d "$merged" '+%b %Y')
  printf -- '- <img src="https://github.com/%s.png?size=40" width="20" align="top"> [%s](https://github.com/%s) — [%s (#%s)](%s) — %s\n' \
    "$owner" "$repo" "$repo" "$title" "$number" "$url" "$month" >> "$TABLE"
  found=$((found + 1))
done < <(gh api "search/issues?q=is%3Apr+is%3Amerged+author%3A${USER}+-user%3A${USER}&per_page=100" \
  --jq '.items | sort_by(.pull_request.merged_at) | reverse | .[]
        | [(.repository_url | sub(".*repos/"; "")), (.number | tostring), .title, .html_url, .pull_request.merged_at]
        | @tsv')

if [ "$found" -eq 0 ]; then
  printf '_Nothing yet — go break into somewhere nice._\n' > "$TABLE"
fi

awk -v tblfile="$TABLE" '
  /<!-- upstream-prs:start -->/ { print; while ((getline line < tblfile) > 0) print line; skip=1; next }
  /<!-- upstream-prs:end -->/   { skip=0 }
  !skip                         { print }
' "$README" > "$README.new"
mv "$README.new" "$README"

echo "rows: $found"
