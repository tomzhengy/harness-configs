#!/bin/bash
# call-me.sh — place a ringing phone call via Twilio, but only while away mode is on.
# dial plane only: it has no enable/disable verbs, so granting it to the model-invocable
# call-user skill can never open the away-mode gate. away mode is toggled solely by the
# type-only /away and /back skills via away-mode.sh.
#
# usage: call-me.sh "spoken message"   # rings only if away mode is active and unexpired
#
# requires env vars: TWILIO_SID, TWILIO_TOKEN, TWILIO_NUMBER, MY_PHONE

STATE="$HOME/.claude/away_until"
MSG="${1:-Claude Code needs your attention.}"

# gate 1: away mode must be set
if [ ! -f "$STATE" ]; then
  echo "Not away — no call placed."; exit 0
fi

# gate 2: state must be a single, all-digit future epoch. fail closed: empty / non-numeric /
# multiline / expired all skip the call and clean up. grep -Eq matched line-by-line, so a
# file like "0\nx" slipped through (first line numeric), then crashed the -ge compare into
# the dial path. the case glob rejects any non-digit char, the newline included.
UNTIL="$(cat "$STATE" 2>/dev/null)"
case "$UNTIL" in
  ''|*[!0-9]*) rm -f "$STATE"; echo "Away state invalid — no call placed."; exit 0 ;;
esac
if [ "$(date +%s)" -ge "$UNTIL" ]; then
  rm -f "$STATE"; echo "Away window expired — no call placed."; exit 0
fi

# xml-escape the spoken message via sed so it cannot break the TwiML or inject verbs such as
# </Say><Dial>...; order matters, escape & first. use sed, not bash ${//}: with
# patsub_replacement (bash 5.2+) an unescaped & in a ${var//</&lt;} replacement expands to
# the matched char, turning < into <lt; instead of &lt;. in sed, \& is a literal ampersand.
ESC="$(printf '%s' "$MSG" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"

# keep the long-lived auth token and the phone numbers off the process argv (they would
# otherwise be visible via ps); pass them to curl through a config read from stdin (-K -).
HTTP="$(printf 'user = "%s:%s"\ndata-urlencode = "To=%s"\ndata-urlencode = "From=%s"\n' \
  "$TWILIO_SID" "$TWILIO_TOKEN" "$MY_PHONE" "$TWILIO_NUMBER" \
  | curl -s -K - -o /dev/null -w '%{http_code}' \
    -X POST "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/Calls.json" \
    --data-urlencode "Twiml=<Response><Say>$ESC</Say><Pause length=\"1\"/><Say>$ESC</Say></Response>")"

# report truthfully: only a 2xx means twilio accepted the call. the old script printed
# "Called:" even on a 401/400 because curl -s without status checking exits 0 on http errors.
case "$HTTP" in
  2*) echo "Called: $MSG" ;;
  *)  echo "Call FAILED (HTTP ${HTTP:-000}) — phone did not ring. Check Twilio creds, a verified number, and E.164 format." >&2; exit 1 ;;
esac
