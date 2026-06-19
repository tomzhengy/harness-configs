#!/usr/bin/env bash
# expose-worktrees: surface claude code worktrees as flat siblings of the repo.
#
# claude creates worktrees under <repo>/.claude/worktrees/<name>. for each one
# (except throwaway agent-* worktrees) this makes a symlink in the repo's parent
# dir named <repo>-<name>, so it shows in the editor sidebar next to the repo
# like a normal sibling folder. dead symlinks (worktree already cleaned up by
# claude) are pruned. the real worktree stays in .claude/worktrees, so claude's
# own auto-cleanup keeps working. runs on SessionStart; must print nothing to
# stdout (SessionStart stdout is injected into the session context).

# read cwd from the hook's stdin json if present, else fall back to $PWD
input=""
[ -t 0 ] || input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$cwd" ] && cwd="$PWD"

# resolve the MAIN repo path (works from the main checkout or any linked worktree)
gitdir=$(git -C "$cwd" rev-parse --absolute-git-dir 2>/dev/null) || exit 0
[ -z "$gitdir" ] && exit 0
case "$gitdir" in
  */.git/worktrees/*) mainrepo="${gitdir%%/.git/worktrees/*}" ;;
  */.git)             mainrepo="${gitdir%/.git}" ;;
  *)                  mainrepo=$(dirname "$gitdir") ;;
esac
[ -d "$mainrepo" ] || exit 0

parent=$(dirname "$mainrepo")
reponame=$(basename "$mainrepo")
wtdir="$mainrepo/.claude/worktrees"
[ "$parent" = "$mainrepo" ] && exit 0
[ -d "$parent" ] || exit 0

# 1) create a sibling symlink for each real worktree (skip throwaway agent-* ones)
if [ -d "$wtdir" ]; then
  for path in "$wtdir"/*/; do
    [ -d "$path" ] || continue
    name=$(basename "$path")
    case "$name" in agent-*) continue ;; esac
    link="$parent/$reponame-$name"
    if [ ! -e "$link" ] && [ ! -L "$link" ]; then
      ln -s "$reponame/.claude/worktrees/$name" "$link" 2>/dev/null
    fi
  done
fi

# 2) prune sibling symlinks whose worktree is gone. only ever touches symlinks
#    that point into <repo>/.claude/worktrees (never real dirs like the repo's
#    other sibling projects or manually-made worktrees)
for link in "$parent/$reponame-"*; do
  [ -L "$link" ] || continue
  target=$(readlink "$link" 2>/dev/null)
  case "$target" in
    */.claude/worktrees/*) ;;
    *) continue ;;
  esac
  [ -e "$link" ] || rm "$link" 2>/dev/null
done

exit 0
