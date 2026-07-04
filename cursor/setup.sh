#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CURSOR_DIR="${CURSOR_HOME:-$HOME/.cursor}"
MODE="copy"
BACKUP_DIR=""

usage() {
    echo "usage: cursor/setup.sh [--link]"
    echo ""
    echo "  --link    symlink files instead of copying"
    echo ""
    echo "installs cursor configs into CURSOR_HOME, defaulting to ~/.cursor"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --link)
            MODE="link"
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "unknown option: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

if ! command -v jq &>/dev/null; then
    echo "error: jq is required but not installed."
    echo "  macOS:  brew install jq"
    echo "  linux:  sudo apt-get install jq"
    exit 1
fi

backup_file() {
    local path="$1"
    [ -f "$path" ] || return 0
    [ -L "$path" ] && return 0
    if [ -z "$BACKUP_DIR" ]; then
        BACKUP_DIR="$CURSOR_DIR/backups/harness-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
    fi
    cp "$path" "$BACKUP_DIR/$(basename "$path")"
    echo "  backed up $(basename "$path") -> $BACKUP_DIR/"
}

backup_path_for_link() {
    local path="$1"
    [ -e "$path" ] || [ -L "$path" ] || return 0

    if [ -L "$path" ]; then
        rm -f "$path"
        return 0
    fi

    if [ -z "$BACKUP_DIR" ]; then
        BACKUP_DIR="$CURSOR_DIR/backups/harness-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
    fi

    mv "$path" "$BACKUP_DIR/$(basename "$path")"
    echo "  backed up $(basename "$path") -> $BACKUP_DIR/"
}

install_file() {
    local src="$1"
    local dest="$2"
    backup_file "$dest"
    if [ "$MODE" = "link" ]; then
        ln -sf "$src" "$dest"
        echo "  linked $(basename "$dest")"
    else
        cp -f "$src" "$dest"
        echo "  copied $(basename "$dest")"
    fi
}

install_dir_files() {
    local src_dir="$1"
    local dest_dir="$2"
    if [ "$MODE" = "link" ]; then
        backup_path_for_link "$dest_dir"
        ln -sfn "$src_dir" "$dest_dir"
        echo "  linked $(basename "$dest_dir")/"
        return 0
    fi

    mkdir -p "$dest_dir"
    for file in "$src_dir"/*; do
        [ -f "$file" ] || continue
        install_file "$file" "$dest_dir/$(basename "$file")"
    done
}

echo "cursor harness setup ($MODE mode)"
echo "================================="
echo ""
echo "cursor home: $CURSOR_DIR"
echo ""

mkdir -p "$CURSOR_DIR"

echo "rules:"
install_dir_files "$SCRIPT_DIR/rules" "$CURSOR_DIR/rules"
echo ""

echo "commands:"
install_dir_files "$SCRIPT_DIR/commands" "$CURSOR_DIR/commands"
echo ""

echo "hooks:"
install_file "$SCRIPT_DIR/hooks.json" "$CURSOR_DIR/hooks.json"
install_dir_files "$SCRIPT_DIR/hooks" "$CURSOR_DIR/hooks"
if [ "$MODE" != "link" ]; then
    chmod +x "$CURSOR_DIR"/hooks/*.sh 2>/dev/null || true
fi
echo ""

echo "statusline:"
install_file "$SCRIPT_DIR/statusline.sh" "$CURSOR_DIR/statusline.sh"
if [ "$MODE" != "link" ]; then
    chmod +x "$CURSOR_DIR/statusline.sh"
fi
echo ""

# cli-config.json is always merged as a real file, never linked: the cursor cli
# rewrites it at runtime (editor prefs), which would leak machine state back
# into the repo if it were a symlink.
echo "cli-config.json:"
TARGET_CLI="$CURSOR_DIR/cli-config.json"
SOURCE_CLI="$SCRIPT_DIR/cli-config.json"
if [ -L "$TARGET_CLI" ]; then
    rm -f "$TARGET_CLI"
fi
if [ ! -f "$TARGET_CLI" ]; then
    cp "$SOURCE_CLI" "$TARGET_CLI"
    echo "  copied cli-config.json (new install)"
else
    backup_file "$TARGET_CLI"
    jq -s '.[0] * .[1]' "$TARGET_CLI" "$SOURCE_CLI" > "$TARGET_CLI.tmp" \
        && mv "$TARGET_CLI.tmp" "$TARGET_CLI"
    echo "  merged into existing cli-config.json"
fi
echo ""

echo "================================="
echo "done!"
if [ -n "$BACKUP_DIR" ]; then
    echo "backups: $BACKUP_DIR"
fi
echo ""
echo "notes:"
echo "- mcp servers: merge cursor/mcp.json entries into $CURSOR_DIR/mcp.json with"
echo "  real api keys (cursor does not expand \${VAR} placeholders)."
echo "- restart cursor (or reload hooks in settings) so hooks, rules, and commands"
echo "  are picked up."
