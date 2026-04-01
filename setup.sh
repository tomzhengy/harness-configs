#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/claude-code"
CLAUDE_DIR="$HOME/.claude"
MARKER="<!-- harness-configs -->"
END_MARKER="<!-- /harness-configs -->"
MODE="copy"
BACKUP_DIR=""

# parse args
for arg in "$@"; do
    case "$arg" in
        --link) MODE="link" ;;
        --help|-h)
            echo "usage: ./setup.sh [--link]"
            echo ""
            echo "  --link    symlink files instead of copying (for repo authors)"
            echo ""
            echo "installs claude code configs into ~/.claude/"
            exit 0
            ;;
        *)
            echo "unknown option: $arg"
            exit 1
            ;;
    esac
done

# check dependencies
if ! command -v jq &>/dev/null; then
    echo "error: jq is required but not installed."
    echo "  macOS:  brew install jq"
    echo "  linux:  sudo apt-get install jq"
    exit 1
fi

backup_file() {
    local path="$1"
    [ -f "$path" ] || return 0
    [ -L "$path" ] && return 0  # skip symlinks
    if [ -z "$BACKUP_DIR" ]; then
        BACKUP_DIR="$CLAUDE_DIR/backups/harness-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
    fi
    cp "$path" "$BACKUP_DIR/$(basename "$path")"
    echo "  backed up $(basename "$path") -> $BACKUP_DIR/"
}

install_file() {
    local src="$1" dest="$2"
    if [ "$MODE" = "link" ]; then
        ln -sf "$src" "$dest"
        echo "  linked $(basename "$dest")"
    else
        cp -f "$src" "$dest"
        echo "  copied $(basename "$dest")"
    fi
}

echo "harness-configs setup ($MODE mode)"
echo "=================================="
echo ""

# create target directories
mkdir -p "$CLAUDE_DIR" "$CLAUDE_DIR/rules" "$CLAUDE_DIR/skills"

# --- settings.json ---
echo "settings.json:"
TARGET_SETTINGS="$CLAUDE_DIR/settings.json"
SOURCE_SETTINGS="$SRC_DIR/config/settings.json"

if [ "$MODE" = "link" ]; then
    backup_file "$TARGET_SETTINGS"
    rm -f "$TARGET_SETTINGS"
    ln -sf "$SOURCE_SETTINGS" "$TARGET_SETTINGS"
    echo "  linked settings.json"
elif [ ! -f "$TARGET_SETTINGS" ]; then
    cp "$SOURCE_SETTINGS" "$TARGET_SETTINGS"
    echo "  copied settings.json (new install)"
else
    backup_file "$TARGET_SETTINGS"
    jq -s '
        .[0] as $base | .[1] as $patch |

        # merge permissions.allow: union
        (($base.permissions.allow // []) + (($patch.permissions.allow // []) - ($base.permissions.allow // []))) as $merged_allow |

        # merge permissions.deny: union
        (($base.permissions.deny // []) + (($patch.permissions.deny // []) - ($base.permissions.deny // []))) as $merged_deny |

        # merge hooks by event type, deduplicate by matcher
        (($base.hooks // {}) | keys) as $bk |
        (($patch.hooks // {}) | keys) as $pk |
        (($bk + $pk) | unique) as $all_keys |
        (reduce $all_keys[] as $key (
            {};
            .[$key] = (
                (($base.hooks // {})[$key] // []) as $bh |
                (($patch.hooks // {})[$key] // []) as $ph |
                $bh + [$ph[] | select(. as $p | ($bh | map(select(.matcher == $p.matcher)) | length) == 0)]
            )
        )) as $merged_hooks |

        # merge objects additively
        (($base.enabledPlugins // {}) * ($patch.enabledPlugins // {})) as $merged_plugins |
        (($base.extraKnownMarketplaces // {}) * ($patch.extraKnownMarketplaces // {})) as $merged_markets |

        # base * patch for scalars, then overlay merged collections
        $base * $patch |
        .permissions.allow = $merged_allow |
        .permissions.deny = $merged_deny |
        .hooks = $merged_hooks |
        .enabledPlugins = $merged_plugins |
        .extraKnownMarketplaces = $merged_markets
    ' "$TARGET_SETTINGS" "$SOURCE_SETTINGS" > "$TARGET_SETTINGS.tmp" \
        && mv "$TARGET_SETTINGS.tmp" "$TARGET_SETTINGS"
    echo "  merged into existing settings.json"
fi
echo ""

# --- CLAUDE.md ---
echo "CLAUDE.md:"
TARGET_CLAUDE="$CLAUDE_DIR/CLAUDE.md"
SOURCE_CLAUDE="$SRC_DIR/config/CLAUDE.md"

if [ "$MODE" = "link" ]; then
    backup_file "$TARGET_CLAUDE"
    rm -f "$TARGET_CLAUDE"
    ln -sf "$SOURCE_CLAUDE" "$TARGET_CLAUDE"
    echo "  linked CLAUDE.md"
elif [ ! -f "$TARGET_CLAUDE" ]; then
    {
        echo "$MARKER"
        cat "$SOURCE_CLAUDE"
        echo ""
        echo "$END_MARKER"
    } > "$TARGET_CLAUDE"
    echo "  created CLAUDE.md"
else
    backup_file "$TARGET_CLAUDE"
    # strip existing harness-configs block if present
    if grep -qF "$MARKER" "$TARGET_CLAUDE"; then
        sed -i.bak "/$MARKER/,/$END_MARKER/d" "$TARGET_CLAUDE"
        rm -f "$TARGET_CLAUDE.bak"
        echo "  replaced existing harness-configs block"
    else
        echo "  appended harness-configs block"
    fi
    {
        echo ""
        echo "$MARKER"
        cat "$SOURCE_CLAUDE"
        echo ""
        echo "$END_MARKER"
    } >> "$TARGET_CLAUDE"
fi
echo ""

# --- statusline-command.sh ---
echo "statusline-command.sh:"
install_file "$SRC_DIR/config/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"
chmod +x "$CLAUDE_DIR/statusline-command.sh"
echo ""

# --- rules ---
echo "rules:"
if [ "$MODE" = "link" ]; then
    rm -f "$CLAUDE_DIR/rules" 2>/dev/null || true
    rmdir "$CLAUDE_DIR/rules" 2>/dev/null || true
    ln -sfn "$SRC_DIR/rules" "$CLAUDE_DIR/rules"
    echo "  linked rules/"
else
    for file in "$SRC_DIR/rules/"*; do
        [ -f "$file" ] || continue
        install_file "$file" "$CLAUDE_DIR/rules/$(basename "$file")"
    done
fi
echo ""

# --- skills ---
echo "skills:"
if [ "$MODE" = "link" ]; then
    rm -f "$CLAUDE_DIR/skills" 2>/dev/null || true
    rmdir "$CLAUDE_DIR/skills" 2>/dev/null || true
    ln -sfn "$SRC_DIR/skills" "$CLAUDE_DIR/skills"
    echo "  linked skills/"
else
    for skill_dir in "$SRC_DIR/skills/"*/; do
        [ -d "$skill_dir" ] || continue
        skill_name="$(basename "$skill_dir")"
        mkdir -p "$CLAUDE_DIR/skills/$skill_name"
        for file in "$skill_dir"*; do
            [ -f "$file" ] || continue
            install_file "$file" "$CLAUDE_DIR/skills/$skill_name/$(basename "$file")"
        done
    done
fi
echo ""

# --- summary ---
echo "=================================="
echo "done!"
if [ -n "$BACKUP_DIR" ]; then
    echo "backups: $BACKUP_DIR"
fi
echo ""
echo "note: for MCP servers (github, nia), merge claude-code/config/mcp.json"
echo "entries into ~/.claude.json manually with your API keys."
