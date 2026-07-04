#!/bin/bash

# cursor cli status line: dir, git branch, model, context usage.
# the stdin payload is aligned with claude code's statusline spec, but cursor
# provides context_window.used_percentage directly instead of raw token counts.

# read JSON input from stdin
input=$(cat)

# extract data
model_name=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "~"')
dir_basename=$(basename "$current_dir")

# context usage percentage (may be null early in the session)
pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
[ -n "$pct" ] || pct=0
context_str=$(printf '%d%%' "$pct")

# get git branch (skip optional locks to avoid hangs)
cd "$current_dir" 2>/dev/null
git_branch=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -c core.useBuiltinFSMonitor=false rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        git_branch=$(printf ' \033[38;5;39m(\033[38;5;45m%s\033[38;5;39m)\033[0m' "$branch")
    fi
fi

# cursor-themed format with cool blue/cyan tones (claude's uses warm orange)
# 39 = blue, 45 = cyan, 33 = darker blue
printf '\033[1;38;5;39m%s\033[0m%s \033[38;5;246m[%s]\033[0m \033[38;5;33m[%s]\033[0m' \
    "$dir_basename" \
    "$git_branch" \
    "$model_name" \
    "$context_str"
