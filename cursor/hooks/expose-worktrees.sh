#!/usr/bin/env bash
set -u

# expose cursor-managed git worktrees as readable sibling symlinks.
# cursor stores managed worktrees under ~/.cursor/worktrees/<repo>/<name>, which
# is easy to miss from an editor sidebar. this mirrors the claude/codex setup by
# creating sibling links named <repo>-cursor-<name> without moving the real
# worktree. dead links are pruned. runs on sessionStart; user hooks run from
# ~/.cursor, so the project comes from the payload's workspace_roots. must print
# nothing to stdout (hook stdout is parsed as json).

expose_repo() {
  repo="$1"
  repo_parent=$(dirname "$repo")
  repo_name=$(basename "$repo")
  cursor_worktrees="$HOME/.cursor/worktrees"

  [ "$repo_parent" = "$repo" ] && return 0
  [ -d "$repo_parent" ] || return 0

  # 1) create a sibling symlink for each cursor-managed worktree of this repo
  git -C "$repo" worktree list --porcelain 2>/dev/null |
    while IFS= read -r line; do
      case "$line" in
        worktree\ *)
          path=${line#worktree }
          [ "$path" = "$repo" ] && continue
          case "$path" in
            "$cursor_worktrees"/*|*/.cursor/worktrees/*) ;;
            *) continue ;;
          esac
          name=$(basename "$path")
          case "$name" in agent-*) continue ;; esac
          link="$repo_parent/$repo_name-cursor-$name"
          if [ ! -e "$link" ] && [ ! -L "$link" ]; then
            ln -s "$path" "$link" 2>/dev/null || true
          fi
          ;;
      esac
    done

  # 2) prune sibling symlinks whose worktree is gone. only ever touches symlinks
  #    that point into a cursor worktrees dir (never real dirs or other links)
  for link in "$repo_parent/$repo_name-cursor-"*; do
    [ -L "$link" ] || continue
    target=$(readlink "$link" 2>/dev/null || true)
    case "$target" in
      "$cursor_worktrees"/*|*/.cursor/worktrees/*) ;;
      *) continue ;;
    esac
    [ -e "$link" ] || rm "$link" 2>/dev/null || true
  done
}

expose_root() {
  root="$1"
  [ -n "$root" ] || return 0

  # resolve the MAIN repo path (works from the main checkout or any linked worktree)
  gitdir=$(git -C "$root" rev-parse --absolute-git-dir 2>/dev/null) || return 0
  [ -z "$gitdir" ] && return 0
  case "$gitdir" in
    */.git/worktrees/*) mainrepo="${gitdir%%/.git/worktrees/*}" ;;
    */.git) mainrepo="${gitdir%/.git}" ;;
    *) mainrepo=$(dirname "$gitdir") ;;
  esac
  [ -d "$mainrepo" ] || return 0

  expose_repo "$mainrepo"

  # umbrella workspaces: also expose worktrees of immediate child repos
  for child in "$mainrepo"/*/; do
    [ -d "${child}.git" ] || [ -f "${child}.git" ] || continue
    expose_repo "${child%/}"
  done
}

input=""
[ -t 0 ] || input=$(cat)

roots=$(printf '%s' "$input" | jq -r '.workspace_roots[]?' 2>/dev/null)
[ -z "$roots" ] && roots="${CURSOR_PROJECT_DIR:-$PWD}"

printf '%s\n' "$roots" | while IFS= read -r root; do
  [ -n "$root" ] && expose_root "$root"
done

exit 0
