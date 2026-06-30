---
name: call-user
description: Place a literal ringing phone call to alert the user only when Claude is blocked and cannot make progress. Use ONLY when (1) Claude is blocked and needs the user's decision or input to proceed, or (2) something failed unrecoverably and work cannot continue. Do NOT call just because a long task finished or completed successfully, and never for routine progress updates or quick tasks. The call is automatically suppressed by the script unless the user has enabled away mode with /away, so invoking this is always safe.
allowed-tools: Bash(~/.claude/scripts/call-me.sh:*)
---

# Calling the user

Only call to surface a blocker: Claude is stuck and cannot proceed without the
user, or work has failed unrecoverably. Do NOT call when a long task simply
finishes or succeeds; completion does not need a call.

Place the call by running:

`~/.claude/scripts/call-me.sh "<short spoken message describing what happened, under 15 words>"`

Examples:

- "Deploy failed at the build step, need your input."
- "Migration hit a conflict, need you to pick a resolution."
- "Tests are failing and I cannot fix it on my own."

The script only rings the user if away mode is active (set via /away); otherwise it
exits silently without calling. After running it, tell the user in your response whether
a call was actually placed — the script prints `Called: ...` on success, or a skip
message (`Not away...` / `Away window expired...`) otherwise.
