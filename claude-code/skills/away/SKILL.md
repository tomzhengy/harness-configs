---
name: away
description: Enable away mode so Claude can place a ringing phone call about long-running tasks while you are asleep or away. This is triggered only by you typing /away; Claude never invokes it on its own.
argument-hint: [hours]
allowed-tools: Bash(~/.claude/scripts/call-me.sh:*)
disable-model-invocation: true
---

Turn on away mode (default 8 hours, or the number of hours given as an argument):

!`~/.claude/scripts/call-me.sh enable $1`

Away mode is now ON.

While it is on, follow the **call-user** protocol: if a long-running task
completes after running a while, gets blocked needing my decision or input, or
fails unrecoverably, place a phone call by running:

`~/.claude/scripts/call-me.sh "<short spoken message, under 15 words>"`

Do NOT call for routine progress updates or quick tasks. The window auto-expires
after the set hours; I can also end it early by typing /back.
