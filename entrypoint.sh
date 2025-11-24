#!/bin/sh
set -e

# Entrypoint script for Pipedrive MCP Server
# Handles three transport modes: stdio, sse, and mcpo

TRANSPORT_TYPE="${MCP_TRANSPORT:-stdio}"

case "$TRANSPORT_TYPE" in
  stdio)
    echo "Starting Pipedrive MCP Server with stdio transport..." >&2
    exec node build/index.js
    ;;

  sse)
    echo "Starting Pipedrive MCP Server with SSE transport..." >&2
    exec node build/index.js
    ;;

  mcpo)
    echo "Starting Pipedrive MCP Server with mcpo transport (SSE -> Streaming HTTP)..." >&2
    echo "mcpo will translate SSE to streaming HTTP for OpenWebUI compatibility" >&2

    # Set SSE transport for the Node.js server
    export MCP_TRANSPORT=sse

    # Start the MCP server in the background
    node build/index.js &
    MCP_PID=$!

    # Wait for the SSE server to be ready
    echo "Waiting for SSE server to start on port ${MCP_PORT:-3000}..." >&2
    MAX_ATTEMPTS=30
    ATTEMPT=0
    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
      if wget --spider -q "http://localhost:${MCP_PORT:-3000}/health" 2>/dev/null; then
        echo "SSE server is ready!" >&2
        break
      fi
      ATTEMPT=$((ATTEMPT + 1))
      sleep 1
    done

    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
      echo "ERROR: SSE server failed to start within ${MAX_ATTEMPTS} seconds" >&2
      kill $MCP_PID 2>/dev/null || true
      exit 1
    fi

    # Start mcpo proxy
    echo "Starting mcpo proxy on port ${MCPO_PORT:-8080}..." >&2
    echo "mcpo will proxy requests from http://localhost:${MCPO_PORT:-8080} to http://localhost:${MCP_PORT:-3000}/sse" >&2

    # Function to handle cleanup
    cleanup() {
      echo "Shutting down..." >&2
      kill $MCP_PID 2>/dev/null || true
      exit 0
    }
    trap cleanup TERM INT

    # Start mcpo and wait
    exec npx -y @modelcontextprotocol/inspector \
      --listen "0.0.0.0:${MCPO_PORT:-8080}" \
      --url "http://localhost:${MCP_PORT:-3000}/sse"
    ;;

  *)
    echo "ERROR: Unknown transport type: $TRANSPORT_TYPE" >&2
    echo "Valid options: stdio, sse, mcpo" >&2
    exit 1
    ;;
esac
