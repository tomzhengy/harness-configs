#!/usr/bin/env bash
set -u

# expose codex-managed git worktrees as readable sibling symlinks.
# codex stores managed worktrees under $CODEX_HOME/worktrees, which is easy to
# miss from an editor sidebar. this mirrors the claude setup by creating sibling
# links named <repo>-codex-<worktree-name> without moving the real worktree.

expose_repo() {
  repo="$1"
  repo_parent=$(dirname "$repo")
  repo_name=$(basename "$repo")
  codex_home="${CODEX_HOME:-$HOME/.codex}"
  codex_worktrees="$codex_home/worktrees"

  [ "$repo_parent" = "$repo" ] && return 0
  [ -d "$repo_parent" ] || return 0

  git -C "$repo" worktree list --porcelain 2>/dev/null |
    while IFS= read -r line; do
      case "$line" in
        worktree\ *)
          path=${line#worktree }
          [ "$path" = "$repo" ] && continue
          case "$path" in
            "$codex_worktrees"/*|*/.codex/worktrees/*|*/.claude/worktrees/*) ;;
            *) continue ;;
          esac
          name=$(basename "$path")
          case "$name" in agent-*) continue ;; esac
          link="$repo_parent/$repo_name-codex-$name"
          if [ ! -e "$link" ] && [ ! -L "$link" ]; then
            ln -s "$path" "$link" 2>/dev/null || true
          fi
          ;;
      esac
    done

  for link in "$repo_parent/$repo_name-codex-"*; do
    [ -L "$link" ] || continue
    target=$(readlink "$link" 2>/dev/null || true)
    case "$target" in
      "$codex_worktrees"/*|*/.codex/worktrees/*|*/.claude/worktrees/*) ;;
      *) continue ;;
    esac
    [ -e "$link" ] || rm "$link" 2>/dev/null || true
  done
}

input=""
[ -t 0 ] || input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$cwd" ] && cwd="$PWD"

gitdir=$(git -C "$cwd" rev-parse --absolute-git-dir 2>/dev/null) || exit 0
[ -z "$gitdir" ] && exit 0
case "$gitdir" in
  */.git/worktrees/*) mainrepo="${gitdir%%/.git/worktrees/*}" ;;
  */.git) mainrepo="${gitdir%/.git}" ;;
  *) mainrepo=$(dirname "$gitdir") ;;
esac
[ -d "$mainrepo" ] || exit 0

expose_repo "$mainrepo"

for child in "$mainrepo"/*/; do
  [ -d "${child}.git" ] || [ -f "${child}.git" ] || continue
  expose_repo "${child%/}"
done

exit 0
