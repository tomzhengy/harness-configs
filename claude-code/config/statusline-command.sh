#!/bin/bash

# read the session snapshot from stdin
input=$(cat)

# extract built-in status fields in one pass
IFS=$'\t' read -r model_name current_dir context_pct effort_level lines_added lines_removed < <(
    jq -r '[
        (.model.display_name // "unknown"),
        (.workspace.current_dir // "~"),
        ((.context_window.used_percentage // 0) | floor | tostring),
        (.effort.level // "-"),
        ((.cost.total_lines_added // 0) | tostring),
        ((.cost.total_lines_removed // 0) | tostring)
    ] | @tsv' <<< "$input"
)

dir_basename=$(basename "$current_dir")

# build plain text first so right alignment ignores ansi color sequences
left_plain="$dir_basename"
left_plain="$left_plain +$lines_added -$lines_removed"
right_plain="$model_name [$effort_level] $context_pct%"

columns=${COLUMNS:-120}
available_columns=$((columns - 4))
if ((available_columns < 1)); then
    available_columns=$columns
fi
gap=$((available_columns - ${#left_plain} - ${#right_plain}))
if ((gap < 1)); then
    gap=1
fi

reset=$'\033[0m'
orange=$'\033[1;38;5;208m'
amber=$'\033[38;5;214m'
gray=$'\033[38;5;246m'
green=$'\033[38;5;114m'
red=$'\033[38;5;203m'

printf '%s%s%s' "$orange" "$dir_basename" "$reset"
printf ' %s+%s%s %s-%s%s' "$green" "$lines_added" "$reset" "$red" "$lines_removed" "$reset"
printf '%*s' "$gap" ''
printf '%s%s %s[%s]%s %s%s%%%s' \
    "$gray" "$model_name" \
    "$amber" "$effort_level" "$reset" \
    "$orange" "$context_pct" "$reset"
