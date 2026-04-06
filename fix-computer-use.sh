#!/usr/bin/env bash
#
# fix-computer-use.sh
# Fixes the Claude Code CLI computer-use MCP by pointing it at the native
# binary shipped with the Claude desktop app.
#

set -euo pipefail

BINARY="/Applications/Claude.app/Contents/Resources/app.asar.unpacked/node_modules/@ant/claude-swift/build/Release/computer_use.node"
ENV_VAR="COMPUTER_USE_SWIFT_NODE_PATH"
EXPORT_LINE="export ${ENV_VAR}=\"${BINARY}\""

# --- Checks ---

if [[ "$(uname)" != "Darwin" ]]; then
  echo "Error: This fix is macOS-only." >&2
  exit 1
fi

if [[ ! -f "$BINARY" ]]; then
  echo "Error: Native binary not found at:" >&2
  echo "  $BINARY" >&2
  echo "" >&2
  echo "Make sure the Claude desktop app is installed." >&2
  exit 1
fi

# Verify the binary loads
if node -e "require('${BINARY}')" 2>/dev/null; then
  echo "Native binary found and loads successfully."
else
  echo "Warning: Binary exists but failed to load in Node. Your Node version may be incompatible." >&2
fi

# --- Detect shell config ---

SHELL_NAME="$(basename "$SHELL")"
case "$SHELL_NAME" in
  zsh)  RC_FILE="$HOME/.zshrc" ;;
  bash) RC_FILE="$HOME/.bashrc" ;;
  *)    RC_FILE="$HOME/.profile" ;;
esac

# --- Apply ---

if grep -q "$ENV_VAR" "$RC_FILE" 2>/dev/null; then
  echo "Already configured in $RC_FILE — nothing to do."
else
  echo "" >> "$RC_FILE"
  echo "# Claude Code computer-use MCP fix (native binary not shipped with npm package)" >> "$RC_FILE"
  echo "$EXPORT_LINE" >> "$RC_FILE"
  echo "Added to $RC_FILE:"
  echo "  $EXPORT_LINE"
  echo ""
  echo "Restart your shell or run:"
  echo "  source $RC_FILE"
fi

echo ""
echo "Done. Restart Claude Code and computer-use should work."
