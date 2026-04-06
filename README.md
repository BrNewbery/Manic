# Claude Code CLI — computer-use MCP Fix

Computer-use not working on Mac - enable the terminal in accessability / screen sharing before attempting fix

The computer-use MCP tools are advertised as available in Claude Code CLI (`/mcp` shows the server, tools appear in the deferred tool list), but every call fails with:

```
Cannot read properties of undefined (reading 'checkAccessibility')
```

## Root Cause

The CLI npm package (`@anthropic-ai/claude-code`) bundles `@ant/computer-use-swift` JS bindings but **does not ship the required native binary** (`computer_use.node`).

The loader resolves the native module like this:

```js
var __dirname = "/home/runner/code/tmp/claude-cli-external-build-2201/node_modules/@ant/computer-use-swift/js";
var resolved = process.env.COMPUTER_USE_SWIFT_NODE_PATH
  ?? path.resolve(__dirname, "../prebuilds/computer_use.node");
var native = require(resolved);
exports = native.computerUse;
```

The hardcoded `__dirname` points to a CI build path that doesn't exist on user machines, and no `prebuilds/` directory is included in the npm package. So `require()` fails, the module returns `undefined`, and `jh().tcc` is `undefined` when `checkAccessibility()` is called.

The Claude **desktop app** ships the binary at:

```
/Applications/Claude.app/Contents/Resources/app.asar.unpacked/
  node_modules/@ant/claude-swift/build/Release/computer_use.node
```

This binary loads fine in Node and exports `{ computerUse }` as expected.

## Fix

Run the setup script or manually add this to your `~/.zshrc` (or `~/.bashrc`):

```bash
export COMPUTER_USE_SWIFT_NODE_PATH="/Applications/Claude.app/Contents/Resources/app.asar.unpacked/node_modules/@ant/claude-swift/build/Release/computer_use.node"
```

Then restart Claude Code.

### Automated Setup

```bash
./fix-computer-use.sh
```

## Requirements

- macOS (the native binary is macOS-only)
- Claude desktop app installed (the binary is sourced from it)
- Claude Code CLI (`@anthropic-ai/claude-code` via npm)

## What Anthropic Should Fix

1. **Ship the binary**: Add `prebuilds/computer_use.node` to the npm package, alongside the existing `vendor/audio-capture/` and `vendor/ripgrep/` directories.
2. **Fix the __dirname**: The hardcoded CI build path should resolve relative to the actual installed package location.
3. **Fail gracefully**: Return a clear error message instead of the cryptic `Cannot read properties of undefined` crash.

## Environment Tested

- Claude Code: 2.1.92
- macOS: 14.6.1 (Sonoma)
- Node: v25.5.0
- Architecture: arm64 + x86_64 (universal binary)
