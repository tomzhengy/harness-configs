---
name: away
description: Enable away mode so Claude can place a ringing phone call about long-running tasks while you are asleep or away. This is triggered only by you typing /away; Claude never invokes it on its own.
argument-hint: [hours]
allowed-tools: Bash(~/.claude/scripts/away-mode.sh:*)
disable-model-invocation: true
---

Turn on away mode (default 8 hours, or the whole number of hours given as an argument):

!`~/.claude/scripts/away-mode.sh enable "$1"`

The line above is the control script's actual output and is the source of truth: if it
printed an error (for example a non-integer hours value), away mode is NOT on.

While away mode is on, follow the **call-user** protocol: if a long-running task
completes after running a while, gets blocked needing my decision or input, or
fails unrecoverably, place a phone call by running:

`~/.claude/scripts/call-me.sh "<short spoken message, under 15 words>"`

Do NOT call for routine progress updates or quick tasks. The window auto-expires
after the set hours; I can also end it early by typing /back.
