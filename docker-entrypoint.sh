#!/bin/bash
set -e
export GPG_TTY=$(tty 2>/dev/null || echo /dev/console)
exec "$@"
