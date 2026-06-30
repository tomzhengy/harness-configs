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
    # write atomically so a reader never sees a half-written file
    tmp="$(mktemp "${STATE}.XXXXXX")" && printf '%s\n' "$UNTIL" > "$tmp" && mv -f "$tmp" "$STATE"
    echo "Away mode ON for $HOURS hours."
    ;;
  disable)
    rm -f "$STATE"
    echo "Away mode OFF."
    ;;
  *)
    echo "usage: away-mode.sh enable [hours] | disable" >&2
    exit 2
    ;;
esac
