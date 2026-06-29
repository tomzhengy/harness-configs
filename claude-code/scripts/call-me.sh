#!/bin/bash
# call-me.sh — place a ringing phone call via Twilio, but only while "away mode" is on.
#
# Usage:
#   call-me.sh enable [hours]   # turn away mode ON (default 8h)
#   call-me.sh disable          # turn away mode OFF
#   call-me.sh "spoken message" # place a call IF away mode is active, else skip silently
#
# Requires env vars: TWILIO_SID, TWILIO_TOKEN, TWILIO_NUMBER, MY_PHONE

STATE="$HOME/.claude/away_until"

# --- Away mode controls ---
if [ "$1" = "enable" ]; then
  HOURS="${2:-8}"
  date -d "+$HOURS hours" +%s 2>/dev/null > "$STATE" || \
    date -v +"${HOURS}"H +%s > "$STATE"   # macOS (BSD) fallback
  echo "Away mode ON for $HOURS hours."
  exit 0
fi
if [ "$1" = "disable" ]; then
  rm -f "$STATE"; echo "Away mode OFF."; exit 0
fi

# --- Otherwise: attempt a call ---
MSG="${1:-Claude Code needs your attention.}"

# Gate 1: away mode must be set
if [ ! -f "$STATE" ]; then
  echo "Not away — no call placed."; exit 0
fi
# Gate 2: window must not be expired (auto-cleans on expiry)
if [ "$(date +%s)" -ge "$(cat "$STATE")" ]; then
  rm -f "$STATE"; echo "Away window expired — no call placed."; exit 0
fi

curl -s -X POST "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/Calls.json" \
  --data-urlencode "To=$MY_PHONE" \
  --data-urlencode "From=$TWILIO_NUMBER" \
  --data-urlencode "Twiml=<Response><Say>$MSG</Say><Pause length=\"1\"/><Say>$MSG</Say></Response>" \
  -u "$TWILIO_SID:$TWILIO_TOKEN" > /dev/null && echo "Called: $MSG"
