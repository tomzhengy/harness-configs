---
name: clip
description: Fetch the current clipboard image from the local mac via clipaste and read it. Use when the user says /clip, "check my clipboard", "look at my clipboard", or "what did i copy".
allowed-tools: Bash(clipaste-paste)
---

run `clipaste-paste` to pull the current clipboard image from my local machine into a file on this host, then Read the printed path so you can see it.

if it reports no image on the clipboard, tell me to copy or screenshot something first. do not guess or reuse a stale path.
