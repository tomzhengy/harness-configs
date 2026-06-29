#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
SKILLS_DIR="${CODEX_SKILLS_DIR:-$HOME/.agents/skills}"
MODE="copy"
BACKUP_DIR=""

usage() {
    echo "usage: codex/setup.sh [--link] [--skills-dir PATH]"
    echo ""
    echo "  --link             symlink files instead of copying"
    echo "  --skills-dir PATH  install skills to PATH"
    echo ""
    echo "installs codex configs into CODEX_HOME, defaulting to ~/.codex"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --link)
            MODE="link"
            ;;
        --skills-dir)
            shift
            [ "$#" -gt 0 ] || {
                echo "error: --skills-dir requires a path"
                exit 1
            }
            SKILLS_DIR="$1"
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

backup_file() {
    local path="$1"
    [ -f "$path" ] || return 0
    [ -L "$path" ] && return 0
    if [ -z "$BACKUP_DIR" ]; then
        BACKUP_DIR="$CODEX_DIR/backups/harness-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
    fi
    cp "$path" "$BACKUP_DIR/$(basename "$path")"
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
    mkdir -p "$dest_dir"
    if [ "$MODE" = "link" ]; then
        rm -f "$dest_dir" 2>/dev/null || true
        rmdir "$dest_dir" 2>/dev/null || true
        ln -sfn "$src_dir" "$dest_dir"
        echo "  linked $(basename "$dest_dir")/"
        return 0
    fi

    for file in "$src_dir"/*; do
        [ -f "$file" ] || continue
        install_file "$file" "$dest_dir/$(basename "$file")"
    done
}

install_skills() {
    mkdir -p "$SKILLS_DIR"
    for skill_dir in "$SCRIPT_DIR/skills/"*/; do
        [ -d "$skill_dir" ] || continue
        skill_name="$(basename "$skill_dir")"
        dest="$SKILLS_DIR/$skill_name"
        if [ "$MODE" = "link" ]; then
            ln -sfn "$skill_dir" "$dest"
            echo "  linked $skill_name"
        else
            mkdir -p "$dest"
            cp -R "$skill_dir/." "$dest/"
            echo "  copied $skill_name"
        fi
    done
}

echo "codex harness setup ($MODE mode)"
echo "================================"
echo ""
echo "codex home: $CODEX_DIR"
echo "skills dir: $SKILLS_DIR"
echo ""

mkdir -p "$CODEX_DIR"

echo "config files:"
install_file "$SCRIPT_DIR/config.toml" "$CODEX_DIR/config.toml"
install_file "$SCRIPT_DIR/AGENTS.md" "$CODEX_DIR/AGENTS.md"
install_file "$SCRIPT_DIR/instructions.md" "$CODEX_DIR/instructions.md"
install_file "$SCRIPT_DIR/hooks.json" "$CODEX_DIR/hooks.json"
echo ""

echo "rules:"
install_dir_files "$SCRIPT_DIR/rules" "$CODEX_DIR/rules"
echo ""

echo "hooks:"
install_dir_files "$SCRIPT_DIR/hooks" "$CODEX_DIR/hooks"
if [ "$MODE" != "link" ]; then
    chmod +x "$CODEX_DIR"/hooks/*.sh 2>/dev/null || true
fi
echo ""

echo "skills:"
install_skills
echo ""

echo "================================"
echo "done!"
if [ -n "$BACKUP_DIR" ]; then
    echo "backups: $BACKUP_DIR"
fi
echo ""
echo "restart codex so config, hooks, rules, and skills are reloaded."
