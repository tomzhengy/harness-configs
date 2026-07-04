#!/usr/bin/env bash
set -u

# play a macos sound without making cursor wait for it.

sound="${1:-Ping}"
path="/System/Library/Sounds/$sound.aiff"

if command -v afplay >/dev/null 2>&1 && [ -f "$path" ]; then
  (afplay "$path" >/dev/null 2>&1 &)
fi

exit 0
