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

make_usage_bar() {
    local percent="$1" width=10 filled empty bar="" index
    filled=$(((percent * width + 50) / 100))
    if ((filled > width)); then filled=$width; fi
    empty=$((width - filled))
    for ((index = 0; index < filled; index++)); do bar+="█"; done
    for ((index = 0; index < empty; index++)); do bar+="░"; done
    printf '%s' "$bar"
}

format_reset_duration() {
    local reset_at="$1" now remaining total_minutes days hours minutes
    now=$(date +%s)
    remaining=$((reset_at - now))
    if ((remaining <= 0)); then
        printf 'now'
        return
    fi

    total_minutes=$(((remaining + 59) / 60))
    days=$((total_minutes / 1440))
    hours=$(((total_minutes % 1440) / 60))
    minutes=$((total_minutes % 60))
    if ((days > 0)); then
        printf '%dd %dh' "$days" "$hours"
    elif ((hours > 0)); then
        printf '%dh %dm' "$hours" "$minutes"
    else
        printf '%dm' "$minutes"
    fi
}

session_plain=""
usage_plain=""
usage_helper="$HOME/.claude/scripts/provider-usage.js"
if [ -x "$usage_helper" ]; then
    usage_json=$("$usage_helper" <<< "$input" 2>/dev/null || true)
    if [ -n "$usage_json" ]; then
        IFS=$'\034' read -r primary_pct primary_reset secondary_pct secondary_reset < <(
            jq -r '[
                ((.primary.usedPercent // "") | tostring),
                ((.primary.resetsAt // "") | tostring),
                ((.secondary.usedPercent // "") | tostring),
                ((.secondary.resetsAt // "") | tostring)
            ] | join("\u001c")' <<< "$usage_json"
        )

        if [ -n "$primary_pct" ]; then
            primary_pct=$(printf '%.0f' "$primary_pct")
            session_plain="Session: [$(make_usage_bar "$primary_pct")] $primary_pct%"
            if [ -n "$primary_reset" ]; then
                session_plain="$session_plain · $(format_reset_duration "$primary_reset")"
            fi
            usage_plain="$session_plain"
        fi

        if [ -n "$secondary_pct" ]; then
            secondary_pct=$(printf '%.0f' "$secondary_pct")
            weekly_plain="Weekly: [$(make_usage_bar "$secondary_pct")] $secondary_pct%"
            if [ -n "$secondary_reset" ]; then
                weekly_plain="$weekly_plain · $(format_reset_duration "$secondary_reset")"
            fi
            usage_plain="${usage_plain:+$usage_plain · }$weekly_plain"
        fi
    fi
fi

usage_cache_dir="$HOME/.cache/harness-statusline"
usage_cache_file="$usage_cache_dir/footer-usage.txt"
mkdir -p "$usage_cache_dir"
if [ ! -f "$usage_cache_file" ] || [ "$(<"$usage_cache_file")" != "$usage_plain" ]; then
    umask 077
    usage_cache_tmp="$usage_cache_file.$$"
    printf '%s' "$usage_plain" > "$usage_cache_tmp"
    mv "$usage_cache_tmp" "$usage_cache_file"
fi

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
