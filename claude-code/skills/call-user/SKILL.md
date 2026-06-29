---
name: call-user
description: Place a literal ringing phone call to alert the user about a long-running task. Use ONLY when (1) a long task completes after running a while, (2) Claude is blocked and needs the user's decision or input to proceed, or (3) something failed unrecoverably. The call is automatically suppressed by the script unless the user has enabled away mode with /away, so invoking this is always safe. Do NOT use for routine progress updates or quick tasks.
allowed-tools: Bash(~/.claude/scripts/call-me.sh:*)
---

# Calling the user

Place the call by running:

`~/.claude/scripts/call-me.sh "<short spoken message describing what happened, under 15 words>"`

Examples:

- "Database migration finished successfully."
- "Deploy failed at the build step, need your input."
- "Tests are green, ready to merge when you are."

The script only rings the user if away mode is active (set via /away); otherwise it
exits silently without calling. After running it, tell the user in your response whether
a call was actually placed — the script prints `Called: ...` on success, or a skip
message (`Not away...` / `Away window expired...`) otherwise.
