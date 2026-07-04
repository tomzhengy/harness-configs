Enable away mode so the agent can place a ringing phone call when it hits a blocker while I am asleep or away. Only I trigger this by typing /away; never enable it on your own.

1. run `~/.claude/scripts/away-mode.sh enable <hours>` - if my message included a whole number after /away, pass it as the hours argument; otherwise run `~/.claude/scripts/away-mode.sh enable` for the default 8 hours.
2. report the script's output verbatim. it is the source of truth: if it printed an error, away mode is NOT on.

While away mode is on, follow the call-user skill protocol: if a task gets blocked needing my decision or input, or fails unrecoverably so work cannot continue, place a phone call by running:

`~/.claude/scripts/call-me.sh "<short spoken message, under 15 words>"`

Do NOT call just because a long task finished or succeeded, and not for routine progress updates or quick tasks. The window auto-expires after the set hours; I can also end it early by typing /back.
