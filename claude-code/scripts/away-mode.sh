#!/bin/bash
# away-mode.sh — turn away mode on/off. control plane only; this script never places calls.
# only the type-only /away and /back skills invoke it; the model-invocable call-user skill
# has no grant to it, so the model cannot open the gate on its own.
#
# usage:
#   away-mode.sh enable [hours]   # hours defaults to 8; must be a whole number
#   away-mode.sh disable

STATE="$HOME/.claude/away_until"

case "$1" in
  enable)
    HOURS="${2:-8}"
    # fail closed: a non-integer never arms away mode. the old script left a 0-byte state
    # file here and still reported ON, which then rang on every later call and never expired.
    if ! printf '%s' "$HOURS" | grep -Eq '^[0-9]+$'; then
      echo "error: hours must be a whole number (got: $HOURS). away mode NOT enabled." >&2
      exit 1
    fi
    # compute expiry epoch: gnu date first, then bsd (macos) fallback
    UNTIL="$(date -d "+$HOURS hours" +%s 2>/dev/null || date -v +"${HOURS}"H +%s 2>/dev/null)"
    # never write a malformed state file
    if ! printf '%s' "$UNTIL" | grep -Eq '^[0-9]+$'; then
      echo "error: could not compute expiry time. away mode NOT enabled." >&2
      exit 1
    fi
    # write atomically so a reader never sees a half-written file. fail closed: if mktemp, the
    # write, or the rename fails (missing/unwritable ~/.claude, full disk), report it and exit
    # nonzero. the old && chain fell through to "Away mode ON" on a failed write, so /away
    # claimed the window was armed while no state file existed and later calls were suppressed.
    if ! tmp="$(mktemp "${STATE}.XXXXXX" 2>/dev/null)"; then
      echo "error: could not create state file in $HOME/.claude. away mode NOT enabled." >&2
      exit 1
    fi
    if ! printf '%s\n' "$UNTIL" > "$tmp" 2>/dev/null || ! mv -f "$tmp" "$STATE" 2>/dev/null; then
      rm -f "$tmp" 2>/dev/null || true
      echo "error: could not write away state. away mode NOT enabled." >&2
      exit 1
    fi
    # fail closed if $STATE is not a regular file. if away_until already exists as a directory,
    # mv -f moves the temp file *inside* it (SOURCE... DIRECTORY form) and exits 0, so /away would
    # claim "Away mode ON" while call-me.sh's [ -f "$STATE" ] check sees no state and never rings.
    # mv -T would prevent this but is gnu-only, so verify the result for bsd/macos portability.
    if [ ! -f "$STATE" ]; then
      rm -f "$STATE/$(basename "$tmp")" 2>/dev/null || true
      echo "error: $STATE is not a regular file (is it a directory?). away mode NOT enabled." >&2
      exit 1
    fi
    echo "Away mode ON for $HOURS hours."
    ;;
  disable)
    rm -f "$STATE" 2>/dev/null || true
    # verify the gate is actually gone. rm -f exits 0 even when it cannot remove the file
    # (unwritable ~/.claude, wrong ownership, immutable flag), so confirm before reporting OFF.
    # otherwise /back would claim away mode is off while call-me.sh still sees a future
    # away_until and keeps ringing the phone.
    if [ -e "$STATE" ]; then
      echo "error: could not remove away state ($STATE). away mode is STILL ON." >&2
      exit 1
    fi
    echo "Away mode OFF."
    ;;
  *)
    echo "usage: away-mode.sh enable [hours] | disable" >&2
    exit 2
    ;;
esac
