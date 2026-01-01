# CLAUDE.md

## Project Overview

**pubdev_mcp_bridge** is a Dart CLI that generates MCP (Model Context Protocol) servers from pub.dev package documentation. It extracts API documentation from any Dart package and serves it via MCP, enabling AI assistants like Claude to query accurate, up-to-date package APIs.

## Quick Reference

```bash
# Extract and serve a package
pubdev_mcp_bridge serve <package>

# Extract only (no server)
pubdev_mcp_bridge extract <package>

# List cached packages
pubdev_mcp_bridge list

# Clear cache
pubdev_mcp_bridge clean <package>
pubdev_mcp_bridge clean --all
```

## Architecture

```
pub.dev → PubdevClient → ArchiveHandler → DartMetadataExtractor → Cache → MCP Server
```

**Key components:**
- `lib/src/client/pubdev_client.dart` — Downloads packages from pub.dev
- `lib/src/extractor/dart_metadata_extractor.dart` — Uses `package:analyzer` to extract API docs
- `lib/src/extractor/extractor.dart` — Orchestrates the extraction pipeline
- `lib/src/server/mcp_server.dart` — MCP server with 11 tools
- `lib/src/cache/cache_manager.dart` — Three-level caching (archives, extracted, docs)

## Key Design Decisions

**Why `package:analyzer` instead of dartdoc_json?**

`dartdoc_json` fails on packages using experimental Dart features (dot-shorthands, macros, etc.) because it doesn't expose flags to enable them. We use `package:analyzer` directly and programmatically generate `analysis_options.yaml` with all experimental features enabled.

**Why a generic server instead of code generation?**

Previous versions generated a separate Dart project per package. The current architecture uses a single server that loads JSON documentation at runtime—simpler, faster, no code generation bugs.

## Cache Location

- macOS/Linux: `~/.pubdev_mcp_cache/`
- Windows: `%LOCALAPPDATA%/pubdev_mcp_cache/`

Subdirectories:
- `archives/` — Downloaded .tar.gz files
- `extracted/` — Unpacked source code
- `docs/` — Parsed JSON documentation

## MCP Tools

The server exposes 11 tools:
- `search` — Search by keyword
- `get_class`, `get_function`, `get_enum`, `get_library` — Get detailed docs
- `get_methods` — List methods of a class
- `list_classes`, `list_functions`, `list_enums`, `list_libraries` — List all items
- `get_package_info` — Package metadata and statistics

## Development

```bash
# Run locally
dart run bin/pubdev_mcp_bridge.dart serve <package>

# Format and analyze
dart format .
dart analyze

# Test MCP server manually
(
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test"}}}'
  sleep 3
  echo '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
  sleep 2
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_package_info","arguments":{}}}'
) | dart run bin/pubdev_mcp_bridge.dart serve music_notes 2>/dev/null
```

## Dependencies

- `analyzer` ^9.0.0 — Dart source analysis
- `dart_mcp` ^0.2.0 — MCP server implementation
- `archive` ^4.0.0 — .tar.gz extraction
- `http` ^1.1.0 — HTTP client
- `args` ^2.4.0 — CLI parsing
- `path` ^1.8.0 — Path handling
- `stream_channel` ^2.1.0 — Stdio streams

## Common Tasks

**Add a new MCP tool:**
1. Add tool definition in `mcp_server.dart` `_registerTools()`
2. Implement handler method `_handleNewTool()`

**Support a new Dart element type:**
1. Add extraction in `dart_metadata_extractor.dart`
2. Add model in `package_doc.dart`
3. Update parser in `dartdoc_parser.dart`

**Debug extraction issues:**
```bash
ls ~/.pubdev_mcp_cache/docs/
cat ~/.pubdev_mcp_cache/docs/<package>-<version>.json | head -100
```
