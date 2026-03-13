#!/usr/bin/env bash
# bootstrap.sh - idempotent setup for claude code on GPU instances
# usage: curl -fsSL <raw-url>/bootstrap.sh | bash
set -euo pipefail

echo "=== claude code gpu bootstrap ==="

# ---- detect persistent storage ----
if [ -d "/workspace" ]; then
    PERSIST_DIR="/workspace"
    echo "detected runpod (/workspace)"
else
    PERSIST_DIR="$HOME"
    echo "using home dir ($HOME)"
fi

# ---- system deps ----
echo "--- system deps ---"
NEED_APT=false
for cmd in git curl jq; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
        NEED_APT=true
        break
    fi
done
# also check build-essential via dpkg
if ! dpkg -s build-essential > /dev/null 2>&1; then
    NEED_APT=true
fi

if [ "$NEED_APT" = true ]; then
    echo "installing system deps..."
    apt-get update -qq
    apt-get install -y -qq git curl jq build-essential > /dev/null
else
    echo "system deps already installed"
fi

# ---- node 22.x ----
echo "--- node ---"
if ! command -v node > /dev/null 2>&1; then
    echo "installing node 22.x..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - > /dev/null 2>&1
    apt-get install -y -qq nodejs > /dev/null
    echo "node $(node --version) installed"
else
    echo "node $(node --version) already installed"
fi

# ---- bun ----
echo "--- bun ---"
if ! command -v bun > /dev/null 2>&1; then
    echo "installing bun..."
    curl -fsSL https://bun.sh/install | bash > /dev/null 2>&1
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    echo "bun installed"
else
    echo "bun already installed"
fi

# ---- uv ----
echo "--- uv ---"
if ! command -v uv > /dev/null 2>&1; then
    echo "installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh > /dev/null 2>&1
    export PATH="$HOME/.local/bin:$PATH"
    echo "uv installed"
else
    echo "uv already installed"
fi

# ---- pipx ----
echo "--- pipx ---"
if ! command -v pipx > /dev/null 2>&1; then
    echo "installing pipx..."
    apt-get install -y -qq pipx > /dev/null 2>&1 || pip install --user pipx > /dev/null 2>&1
    pipx ensurepath > /dev/null 2>&1
    export PATH="$HOME/.local/bin:$PATH"
    echo "pipx installed"
else
    echo "pipx already installed"
fi

# ---- claude code ----
echo "--- claude code ---"
if ! command -v claude > /dev/null 2>&1; then
    echo "installing claude code..."
    curl -fsSL https://claude.ai/install.sh | sh > /dev/null 2>&1
    export PATH="$HOME/.local/bin:$PATH"
    echo "claude code installed"
else
    echo "claude code already installed"
fi

# ---- clone config repo ----
echo "--- config repo ---"
LEGACY_CONFIG_DIR="$PERSIST_DIR/claude-code-config"
OLD_CONFIG_DIR="$PERSIST_DIR/coding-config"
CONFIG_DIR="$PERSIST_DIR/harness-configs"
REPO_URL="https://github.com/tomzhengy/harness-configs.git"

# migrate older persisted checkouts to the new repo directory name
if [ ! -e "$CONFIG_DIR" ] && [ -d "$OLD_CONFIG_DIR" ]; then
    mv "$OLD_CONFIG_DIR" "$CONFIG_DIR"
elif [ ! -e "$CONFIG_DIR" ] && [ -d "$LEGACY_CONFIG_DIR" ]; then
    mv "$LEGACY_CONFIG_DIR" "$CONFIG_DIR"
fi

if [ -d "$CONFIG_DIR/.git" ]; then
    echo "config repo exists, pulling latest..."
    git -C "$CONFIG_DIR" pull --ff-only -q 2>/dev/null || echo "pull failed (maybe dirty), continuing with existing"
else
    echo "cloning config repo..."
    # try plain https first (works for public repos even if token is set),
    # then https with token, then ssh
    if git clone -q "$REPO_URL" "$CONFIG_DIR" 2>/dev/null; then
        true
    elif [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
        git -c "http.https://github.com/.extraheader=Authorization: token ${GITHUB_PERSONAL_ACCESS_TOKEN}" \
            clone -q "$REPO_URL" "$CONFIG_DIR"
    else
        git clone -q "git@github.com:tomzhengy/harness-configs.git" "$CONFIG_DIR"
    fi
    echo "config repo cloned"
fi

# ---- symlinks ----
echo "--- symlinks ---"
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"

CONF_BASE="$CONFIG_DIR/claude-code"

# symlink directories
for dir in agents commands rules; do
    target="$CONF_BASE/$dir"
    link="$CLAUDE_DIR/$dir"
    if [ -e "$link" ] && [ ! -L "$link" ]; then
        echo "warning: $link exists and is not a symlink, backing up"
        mv "$link" "${link}.bak"
    fi
    ln -sfn "$target" "$link"
    echo "  $link -> $target"
done

# symlink individual files
ln -sf "$CONF_BASE/config/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
echo "  $CLAUDE_DIR/CLAUDE.md -> $CONF_BASE/config/CLAUDE.md"

ln -sf "$CONF_BASE/config/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"
chmod +x "$CONF_BASE/config/statusline-command.sh"
echo "  $CLAUDE_DIR/statusline-command.sh -> $CONF_BASE/config/statusline-command.sh"

# ---- generate settings.json (strip macOS-only hooks) ----
echo "--- settings.json ---"
SOURCE_SETTINGS="$CONF_BASE/config/settings.json"
TARGET_SETTINGS="$CLAUDE_DIR/settings.json"

# strip macOS-only entries: afplay hooks (Notification, PermissionRequest, Stop) and swift-lsp plugin
# denylist approach so new top-level keys are preserved automatically
jq 'del(.hooks.Notification, .hooks.PermissionRequest, .hooks.Stop, .enabledPlugins)' \
    "$SOURCE_SETTINGS" > "$TARGET_SETTINGS"
echo "  settings.json generated (macOS hooks stripped)"

# ---- persist ~/.claude.json to workspace ----
echo "--- claude state ---"
CLAUDE_STATE="$PERSIST_DIR/.claude.json"
MCP_FILE="$HOME/.claude.json"

# restore from persistent storage if it exists (preserves oauth session)
if [ -f "$CLAUDE_STATE" ] && [ ! -L "$MCP_FILE" ]; then
    echo "  restoring claude state from $CLAUDE_STATE"
fi

# ensure the persistent file exists
if [ ! -f "$CLAUDE_STATE" ]; then
    echo '{}' > "$CLAUDE_STATE"
fi

# symlink ~/.claude.json -> /workspace/.claude.json
ln -sf "$CLAUDE_STATE" "$MCP_FILE"
echo "  $MCP_FILE -> $CLAUDE_STATE"

# merge MCP servers into existing state (preserves auth, preferences, etc.)
echo "--- mcp config ---"
MCP_PATCH='{"mcpServers":{}}'

if [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
    MCP_PATCH=$(echo "$MCP_PATCH" | GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" \
        jq '.mcpServers.Github = {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-github"],
            "env": {
                "GITHUB_PERSONAL_ACCESS_TOKEN": env.GITHUB_PERSONAL_ACCESS_TOKEN
            }
        }')
    echo "  github MCP configured"
else
    echo "  github MCP skipped (no GITHUB_PERSONAL_ACCESS_TOKEN)"
fi

if [ -n "${NIA_API_KEY:-}" ]; then
    MCP_PATCH=$(echo "$MCP_PATCH" | NIA_API_KEY="$NIA_API_KEY" \
        jq '.mcpServers.nia = {
            "command": "pipx",
            "args": ["run", "--no-cache", "nia-mcp-server"],
            "env": {
                "NIA_API_KEY": env.NIA_API_KEY,
                "NIA_API_URL": "https://apigcp.trynia.ai/"
            }
        }')
    echo "  nia MCP configured"
else
    echo "  nia MCP skipped (no NIA_API_KEY)"
fi

# merge patch into existing state (existing keys preserved, mcpServers updated)
jq -s '.[0] * .[1]' "$CLAUDE_STATE" <(echo "$MCP_PATCH") > "$CLAUDE_STATE.tmp" \
    && mv "$CLAUDE_STATE.tmp" "$CLAUDE_STATE"
chmod 600 "$CLAUDE_STATE"
echo "  merged mcp config into $CLAUDE_STATE"

# ---- persist PATH to .bashrc ----
echo "--- bashrc ---"
BASHRC="$HOME/.bashrc"
touch "$BASHRC"

add_to_bashrc() {
    local line="$1"
    if ! grep -qF "$line" "$BASHRC"; then
        echo "$line" >> "$BASHRC"
        echo "  added: $line"
    fi
}

add_to_bashrc 'export PATH="$HOME/.bun/bin:$PATH"'
add_to_bashrc 'export PATH="$HOME/.local/bin:$PATH"'
add_to_bashrc 'export BUN_INSTALL="$HOME/.bun"'

# ---- global gitignore ----
echo "--- gitignore ---"
GLOBAL_GITIGNORE="$HOME/.gitignore_global"
touch "$GLOBAL_GITIGNORE"
git config --global core.excludesfile "$GLOBAL_GITIGNORE"

add_to_gitignore() {
    local line="$1"
    if ! grep -qF "$line" "$GLOBAL_GITIGNORE"; then
        echo "$line" >> "$GLOBAL_GITIGNORE"
        echo "  added to global gitignore: $line"
    fi
}

add_to_gitignore ".claude.json"

echo ""
echo "=== bootstrap complete ==="
echo "run: claude"
