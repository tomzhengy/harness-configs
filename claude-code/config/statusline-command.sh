#!/bin/bash

# read the session snapshot from stdin
input=$(cat)

# extract built-in status fields in one pass
IFS=$'\t' read -r model_name current_dir context_pct total_tokens effort_level thinking_enabled lines_added lines_removed < <(
    jq -r '[
        (.model.display_name // "unknown"),
        (.workspace.current_dir // "~"),
        ((.context_window.used_percentage // 0) | floor | tostring),
        (((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)) | tostring),
        (.effort.level // "-"),
        ((.thinking.enabled // false) | tostring),
        ((.cost.total_lines_added // 0) | tostring),
        ((.cost.total_lines_removed // 0) | tostring)
    ] | @tsv' <<< "$input"
)

# keep large token counts compact
compact_tokens() {
    local value=$1
    local whole decimal

    if ((value >= 1000000)); then
        whole=$((value / 1000000))
        decimal=$(((value % 1000000) / 100000))
        if ((decimal == 0)); then
            printf '%dm' "$whole"
        else
            printf '%d.%dm' "$whole" "$decimal"
        fi
    elif ((value >= 1000)); then
        whole=$((value / 1000))
        decimal=$(((value % 1000) / 100))
        if ((decimal == 0)); then
            printf '%dk' "$whole"
        else
            printf '%d.%dk' "$whole" "$decimal"
        fi
    else
        printf '%d' "$value"
    fi
}

dir_basename=$(basename "$current_dir")
token_str=$(compact_tokens "$total_tokens")

thinking_symbol="T-"
if [ "$thinking_enabled" = "true" ]; then
    thinking_symbol="T+"
fi

# read the branch without optional locks or file-system monitoring
git_branch=""
if git -C "$current_dir" -c core.useBuiltinFSMonitor=false rev-parse --git-dir >/dev/null 2>&1; then
    git_branch=$(git -C "$current_dir" -c core.useBuiltinFSMonitor=false symbolic-ref --quiet --short HEAD 2>/dev/null)
    if [ -z "$git_branch" ]; then
        git_branch=$(git -C "$current_dir" -c core.useBuiltinFSMonitor=false rev-parse --short HEAD 2>/dev/null)
    fi
fi

# build plain text first so right alignment ignores ansi color sequences
left_plain="$dir_basename"
if [ -n "$git_branch" ]; then
    left_plain="$left_plain ($git_branch)"
fi
left_plain="$left_plain +$lines_added -$lines_removed"
right_plain="[$model_name · $effort_level · $thinking_symbol · $context_pct% · $token_str tok]"

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
cyan=$'\033[38;5;45m'

printf '%s%s%s' "$orange" "$dir_basename" "$reset"
if [ -n "$git_branch" ]; then
    printf ' %s(%s)%s' "$amber" "$git_branch" "$reset"
fi
printf ' %s+%s%s %s-%s%s' "$green" "$lines_added" "$reset" "$red" "$lines_removed" "$reset"
printf '%*s' "$gap" ''
printf '%s[%s%s%s · %s%s%s · %s%s%s · %s%s%%%s · %s%s tok]%s' \
    "$gray" \
    "$gray" "$model_name" "$gray" \
    "$amber" "$effort_level" "$gray" \
    "$cyan" "$thinking_symbol" "$gray" \
    "$orange" "$context_pct" "$gray" \
    "$gray" "$token_str" "$reset"
