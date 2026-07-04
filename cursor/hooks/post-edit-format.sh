#!/usr/bin/env bash
set -u

# format edited files after cursor agent edits (afterFileEdit hook).
# failures are ignored so a missing formatter never blocks the agent loop.
# user hooks run from ~/.cursor, so the project dir comes from the payload's
# workspace_roots, not from $PWD.

input=""
[ -t 0 ] || input=$(cat)

file=$(printf '%s' "$input" | jq -r '.file_path // empty' 2>/dev/null)
root=$(printf '%s' "$input" | jq -r '.workspace_roots[0]? // empty' 2>/dev/null)
[ -z "$root" ] && root="${CURSOR_PROJECT_DIR:-}"

[ -n "$file" ] || exit 0
case "$file" in
  /*) abs="$file" ;;
  *) abs="${root:-$PWD}/$file" ;;
esac
[ -f "$abs" ] || exit 0

# prefer biome when a config exists in an ancestor dir, else prettier
formatted=0
dir=$(dirname "$abs")
while [ "$dir" != "/" ] && [ "$dir" != "." ]; do
  if [ -f "$dir/biome.json" ] || [ -f "$dir/biome.jsonc" ]; then
    (cd "$dir" && bunx @biomejs/biome format --write --no-errors-on-unmatched "$abs") >/dev/null 2>&1 || true
    formatted=1
    break
  fi
  next=$(dirname "$dir")
  [ "$next" = "$dir" ] && break
  dir="$next"
done
if [ "$formatted" = "0" ]; then
  bunx prettier --write --ignore-unknown "$abs" >/dev/null 2>&1 || true
fi

# best-effort lint from the workspace root when it is a bun project with a lint script
if [ -n "$root" ] && [ -f "$root/package.json" ]; then
  if [ -f "$root/bun.lock" ] || [ -f "$root/bun.lockb" ]; then
    if grep -q '"lint"' "$root/package.json" 2>/dev/null; then
      (cd "$root" && bun run lint) >/dev/null 2>&1 || true
    fi
  fi
fi

exit 0
