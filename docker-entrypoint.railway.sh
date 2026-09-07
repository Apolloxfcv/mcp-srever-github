#!/bin/sh
# Railway assigns its own $PORT at runtime and expects the container to listen
# on it; the server itself only understands --port/GITHUB_PORT. This bridges
# the two so the same image works unmodified on Railway.
set -e

PORT="${PORT:-8082}"

exec /server/github-mcp-server http \
  --listen-host "0.0.0.0" \
  --port "${PORT}" \
  --trust-proxy-headers \
  "$@"
