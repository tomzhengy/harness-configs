#!/usr/bin/env bash
set -u

# format edited files after codex edit tools run.
# failures are ignored so a missing formatter never blocks the agent loop.

input=""
[ -t 0 ] || input=$(cat)

files_from_json() {
  printf '%s' "$input" | jq -r '
    [
      .tool_input.file_path?,
      .tool_input.path?,
      .tool_input.paths[]?,
      .tool_input.files[]?,
      .tool_input.edits[]?.file_path?,
      .file_path?,
      .path?
    ]
    | flatten
    | .[]?
    | select(type == "string" and length > 0)
  ' 2>/dev/null
}

files_from_patch() {
  patch=$(printf '%s' "$input" | jq -r '
    if (.tool_input | type) == "string" then
      .tool_input
    else
      .tool_input.patch? // .tool_input.input? // ""
    end
  ' 2>/dev/null)

  printf '%s\n' "$patch" | awk '
    /^\*\*\* (Add|Update) File: / {
      sub(/^\*\*\* (Add|Update) File: /, "")
      print
    }
  '
}

format_file() {
  file="$1"
  case "$file" in
    /*) abs="$file" ;;
    *) abs="$PWD/$file" ;;
  esac
  [ -f "$abs" ] || return 0

  dir=$(dirname "$abs")
  while [ "$dir" != "/" ] && [ "$dir" != "." ]; do
    if [ -f "$dir/biome.json" ] || [ -f "$dir/biome.jsonc" ]; then
      (cd "$dir" && bunx @biomejs/biome format --write --no-errors-on-unmatched "$abs") >/dev/null 2>&1 || true
      return 0
    fi
    next=$(dirname "$dir")
    [ "$next" = "$dir" ] && break
    dir="$next"
  done

  bunx prettier --write --ignore-unknown "$abs" >/dev/null 2>&1 || true
}

run_lint() {
  [ -f package.json ] || return 0
  [ -f bun.lock ] || [ -f bun.lockb ] || return 0
  grep -q '"lint"' package.json 2>/dev/null || return 0
  bun run lint >/dev/null 2>&1 || true
}

tmp="${TMPDIR:-/tmp}/codex-edited-files.$$"
{
  files_from_json
  files_from_patch
} | awk 'NF && !seen[$0]++' > "$tmp"

while IFS= read -r file; do
  format_file "$file"
done < "$tmp"
rm -f "$tmp"

run_lint

exit 0
