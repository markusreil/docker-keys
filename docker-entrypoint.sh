#!/bin/bash
set -e
export GPG_TTY=$(tty 2>/dev/null || echo /dev/console)
if command -v pcscd >/dev/null 2>&1 && [ ! -S /run/pcscd/pcscd.comm ]; then
  mkdir -p /run/pcscd
  if ! pidof pcscd >/dev/null 2>&1; then
    pcscd 2>/dev/null || true
  fi
fi
exec "$@"
