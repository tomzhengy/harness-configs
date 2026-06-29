---
name: back
description: Turn off away mode because you are back. Triggered only by you typing /back; Claude never invokes it on its own.
allowed-tools: Bash(~/.claude/scripts/call-me.sh:*)
disable-model-invocation: true
---

Turn off away mode:

!`~/.claude/scripts/call-me.sh disable`

Away mode is now OFF. Do not place any phone calls until I enable it again with /away.
