#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
patch_script="$script_dir/hide-bypass-permissions-label.js"
claude_command="$(command -v claude)"
claude_binary="$(realpath "$claude_command")"
version_output="$($claude_binary --version)"
version="${version_output%% *}"
backup_dir="$HOME/.claude/backups/claude-code"
backup_path="$backup_dir/$version"

if ! command -v bunx >/dev/null 2>&1; then
    echo "error: bunx is required to patch the native claude code executable."
    exit 1
fi

if [ ! -f "$patch_script" ]; then
    echo "error: patch script not found: $patch_script"
    exit 1
fi

mkdir -p "$backup_dir"
if [ ! -f "$backup_path" ]; then
    cp -p "$claude_binary" "$backup_path"
    echo "backed up claude code $version to $backup_path"
fi

bunx -y tweakcc@4.3.1 adhoc-patch \
    --script "@$patch_script" \
    --path "$claude_binary" \
    --confirm-possible-dangerous-patch

"$claude_binary" --version
