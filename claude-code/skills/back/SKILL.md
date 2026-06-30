---
name: back
description: Turn off away mode because you are back. Triggered only by you typing /back; Claude never invokes it on its own.
allowed-tools: Bash(~/.claude/scripts/away-mode.sh:*)
disable-model-invocation: true
---

Turn off away mode:

!`~/.claude/scripts/away-mode.sh disable`

The line above is the control script's actual output. Away mode is off once it prints
"Away mode OFF." Do not place any phone calls until I enable it again with /away.
