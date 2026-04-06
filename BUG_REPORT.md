# Bug: computer-use MCP fails in Claude Code CLI — native binary not included in npm package

## Environment

- Claude Code: 2.1.92 (npm `@anthropic-ai/claude-code`)
- macOS: 14.6.1 (Sonoma)
- Node: v25.5.0
- Architecture: arm64 + x86_64 (universal)

## Problem

The computer-use MCP tools are advertised as available in the CLI (`/mcp` shows the server, tools appear in the deferred tool list), but every call fails with:

```
Cannot read properties of undefined (reading 'checkAccessibility')
```

## Root Cause

The CLI bundles `@ant/computer-use-swift` JS bindings but **does not ship the required native binary** (`computer_use.node`).

The loader at `cli.js` (minified) resolves the native module like this:

```js
// ef4 (deobfuscated)
var __dirname = "/home/runner/code/tmp/claude-cli-external-build-2201/node_modules/@ant/computer-use-swift/js";
var resolved = process.env.COMPUTER_USE_SWIFT_NODE_PATH
  ?? path.resolve(__dirname, "../prebuilds/computer_use.node");
var native = require(resolved);
exports = native.computerUse;
```

The hardcoded `__dirname` points to a CI build path that doesn't exist on user machines, and no `prebuilds/` directory is included in the npm package. So `require()` fails, the module returns `undefined`, and `jh().tcc` is `undefined` when `checkAccessibility()` is called.

Meanwhile, the Claude **desktop app** ships the binary at:

```
/Applications/Claude.app/Contents/Resources/app.asar.unpacked/
  node_modules/@ant/claude-swift/build/Release/computer_use.node
```

This binary loads fine in Node and exports `{ computerUse }` as expected.

## Workaround

Set the env var the loader already checks:

```bash
export COMPUTER_USE_SWIFT_NODE_PATH="/Applications/Claude.app/Contents/Resources/app.asar.unpacked/node_modules/@ant/claude-swift/build/Release/computer_use.node"
```

This requires the Claude desktop app to be installed. Restart Claude Code after setting this.

## Suggested Fix

Include the `computer_use.node` prebuild in the npm package. The binary is already universal (x86_64 + arm64), so a single file covers all Mac users. Specifically:

1. **Ship the binary**: Add `prebuilds/computer_use.node` (or platform-specific variants under `vendor/`) to the `@anthropic-ai/claude-code` npm package, alongside the existing `vendor/audio-capture/` and `vendor/ripgrep/` directories that already follow this pattern.

2. **Fix the __dirname**: The hardcoded `/home/runner/code/tmp/claude-cli-external-build-2201/...` path in the bundled JS is a CI artifact. It should resolve relative to the actual installed package location, not the build machine path.

3. **Fail gracefully**: When the native module can't be loaded, the MCP server should return a clear error ("computer-use requires the native macOS binary — install the Claude desktop app or set COMPUTER_USE_SWIFT_NODE_PATH") instead of the cryptic `Cannot read properties of undefined` crash.

## Steps to Reproduce

1. Install Claude Code via npm: `npx @anthropic-ai/claude-code`
2. Start a conversation
3. Call any computer-use tool (e.g. `request_access` or `list_granted_applications`)
4. Observe: `Cannot read properties of undefined (reading 'checkAccessibility')`
