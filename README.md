# pubdev_mcp_bridge

Generate MCP servers from pub.dev package documentation.

**pubdev_mcp_bridge** extracts API documentation from any Dart package on pub.dev and exposes it through the [Model Context Protocol (MCP)](https://modelcontextprotocol.io/), enabling AI assistants like Claude to understand and work with Dart libraries.

## Features

- **Zero code generation** - A single generic MCP server works with any package
- **Smart caching** - Extracted documentation is cached locally for instant reuse
- **11 MCP tools** - Search, browse classes, functions, enums, libraries, and more
- **Pure Dart** - No external dependencies required
- **Experimental language support** - Works with packages using dot-shorthands, macros, records, and other experimental Dart features

## Quick Start

### Prerequisites

- **Dart SDK** 3.5.0 or later

### Installation

Install globally from pub.dev:

```bash
dart pub global activate pubdev_mcp_bridge
```

Or install from source:

```bash
# Clone the repository
git clone https://github.com/aphrabehn/pubdev_to_mcp.git
cd pubdev_to_mcp

# Install dependencies
dart pub get

# Install globally from source
dart pub global activate --source path .
```

Make sure the pub cache bin directory is in your PATH:
- **macOS/Linux**: Add `export PATH="$PATH":"$HOME/.pub-cache/bin"` to your shell profile
- **Windows**: Add `%LOCALAPPDATA%\Pub\Cache\bin` to your PATH environment variable

### Basic Usage

```bash
# Start an MCP server for a package
pubdev_mcp_bridge serve dio

# Or run directly without global install
dart run bin/pubdev_mcp_bridge.dart serve dio
```

## User Guide

### Commands

#### `serve <package>` - Start MCP Server

Extracts documentation (if not cached) and starts an MCP server:

```bash
# Serve the latest version
pubdev_mcp_bridge serve riverpod

# Serve a specific version
pubdev_mcp_bridge serve riverpod --version 2.5.0

# Force re-extraction (ignore cache)
pubdev_mcp_bridge serve riverpod --refresh
```

#### `extract <package>` - Extract Documentation Only

Downloads and extracts documentation without starting a server:

```bash
pubdev_mcp_bridge extract freezed
pubdev_mcp_bridge extract freezed --version 2.4.0
pubdev_mcp_bridge extract freezed --refresh
```

#### `list` - List Cached Packages

Shows all packages with cached documentation:

```bash
pubdev_mcp_bridge list
# Output:
# Cached packages:
#   riverpod@2.6.1
#   dio@5.4.0
#   music_notes@0.24.0
```

#### `clean` - Remove Cached Data

```bash
# Remove a specific package (all versions)
pubdev_mcp_bridge clean riverpod

# Remove a specific version
pubdev_mcp_bridge clean riverpod --version 2.5.0

# Remove all cached data
pubdev_mcp_bridge clean --all
```

### Integrating with Claude Code

Use the `claude mcp add` command to register an MCP server:

```bash
# Add a server (if installed globally)
claude mcp add riverpod pubdev_mcp_bridge serve riverpod

# Or run directly from the project directory
claude mcp add riverpod dart run /path/to/pubdev_mcp_bridge/bin/pubdev_mcp_bridge.dart serve riverpod

# Add multiple packages
claude mcp add dio pubdev_mcp_bridge serve dio
claude mcp add freezed pubdev_mcp_bridge serve freezed
claude mcp add music-notes pubdev_mcp_bridge serve music_notes
```

Scope options:

```bash
# Add to current project only
claude mcp add --scope project riverpod pubdev_mcp_bridge serve riverpod

# Add globally (available in all projects)
claude mcp add --scope user riverpod pubdev_mcp_bridge serve riverpod
```

Verify registration:

```bash
claude mcp list
```

### Integrating with Claude Desktop

Add the server to your Claude Desktop configuration (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "riverpod": {
      "command": "pubdev_mcp_bridge",
      "args": ["serve", "riverpod"]
    }
  }
}
```

Or if not installed globally:

```json
{
  "mcpServers": {
    "riverpod": {
      "command": "dart",
      "args": ["run", "/path/to/pubdev_mcp_bridge/bin/pubdev_mcp_bridge.dart", "serve", "riverpod"]
    }
  }
}
```

### Available MCP Tools

| Tool | Description |
|------|-------------|
| `search` | Search documentation by keyword |
| `get_class` | Get detailed class documentation |
| `get_function` | Get function documentation |
| `get_enum` | Get enum documentation |
| `get_library` | Get library overview |
| `get_methods` | List all methods of a class |
| `list_classes` | List all classes in the package |
| `list_functions` | List all top-level functions |
| `list_enums` | List all enums |
| `list_libraries` | List all libraries |
| `get_package_info` | Get package metadata and statistics |

### Example Interaction

With the `music_notes` package server running:

**Get package info:**
```
> get_package_info()

Package: music_notes
Version: 0.24.0
Description: A comprehensive Dart library for working with music theory concepts.

Statistics:
  Libraries: 42
  Classes: 64
  Functions: 1
  Enums: 3
```

**Search for APIs:**
```
> search(query: "chord")

class: Chord - A musical chord.
class: ChordPattern - A musical chord pattern.
class: ChordPatternNotation - A notation system for ChordPattern.
```

**Get class details:**
```
> get_class(class_name: "Chord")

class Chord<T>
  extends Object
  implements Transposable<Chord<T>>

A musical chord.

Constructors:
  Chord(this._items)

Methods:
  ChordPattern pattern()
  Chord<T> transposeBy(Interval interval)
  ...
```

## Development Guide

### Project Structure

```
pubdev_mcp_bridge/
├── bin/
│   └── pubdev_mcp_bridge.dart          # CLI entry point
├── lib/
│   ├── pubdev_mcp_bridge.dart          # Public API exports
│   └── src/
│       ├── cache/
│       │   └── cache_manager.dart  # Local cache management
│       ├── client/
│       │   └── pubdev_client.dart  # pub.dev HTTP client
│       ├── cli/
│       │   ├── runner.dart         # CLI command runner
│       │   └── commands/
│       │       ├── serve_command.dart
│       │       ├── extract_command.dart
│       │       ├── list_command.dart
│       │       └── clean_command.dart
│       ├── extractor/
│       │   ├── archive_handler.dart        # .tar.gz extraction
│       │   ├── dart_metadata_extractor.dart # Analyzer-based extraction
│       │   ├── dartdoc_parser.dart         # JSON to model conversion
│       │   └── extractor.dart              # Pipeline orchestrator
│       ├── models/
│       │   └── package_doc.dart    # Data models
│       └── server/
│           └── mcp_server.dart     # MCP server implementation
└── pubspec.yaml
```

### Development Workflow

```bash
# Setup
git clone https://github.com/aphrabehn/pubdev_to_mcp.git
cd pubdev_to_mcp
dart pub get

# Run during development
dart run bin/pubdev_mcp_bridge.dart serve dio

# Code quality
dart format .
dart analyze
```

### Testing the MCP Server Manually

The server communicates via JSON-RPC 2.0 over stdio:

```bash
(
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test"}}}'
  sleep 3
  echo '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
  sleep 2
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_package_info","arguments":{}}}'
  sleep 1
) | dart run bin/pubdev_mcp_bridge.dart serve dio 2>/dev/null
```

### Key Components

#### Cache Manager

Manages three directories under `~/.pubdev_mcp_cache/` (or `%LOCALAPPDATA%/pubdev_mcp_cache/` on Windows):
- `archives/` - Downloaded .tar.gz files
- `extracted/` - Extracted package source code
- `docs/` - Parsed documentation as JSON

#### Extractor Pipeline

1. **PubdevClient** downloads the package archive
2. **ArchiveHandler** extracts the .tar.gz
3. **DartMetadataExtractor** uses `package:analyzer` to parse source files
4. **DartdocParser** converts output to `PackageDoc` model

The extractor uses `package:analyzer` v9.x directly, which:
- Supports experimental Dart features
- Requires no external tools
- Provides fine-grained extraction control

#### MCP Server

Extends `MCPServer` with `ToolsSupport` from `dart_mcp`. Tools are registered during initialization and handle requests asynchronously via stdio.

### Adding a New Tool

1. Define the tool in `_registerTools()`:

```dart
registerTool(
  Tool(
    name: 'my_tool',
    description: 'What it does',
    inputSchema: ObjectSchema(
      properties: {
        'param': StringSchema(description: 'Parameter'),
      },
      required: ['param'],
    ),
  ),
  _handleMyTool,
);
```

2. Implement the handler:

```dart
Future<CallToolResult> _handleMyTool(CallToolRequest request) async {
  final param = request.arguments?['param'] as String;
  // Logic here
  return CallToolResult(content: [TextContent(text: 'Result')]);
}
```

### Debugging

```bash
# List cached packages
ls ~/.pubdev_mcp_cache/docs/

# View cached JSON
cat ~/.pubdev_mcp_cache/docs/dio-5.4.0.json | head -100

# Check extracted source
ls ~/.pubdev_mcp_cache/extracted/dio-5.4.0/
```

### Common Issues

**"dart pub get failed" with path dependencies**

Some packages have path dependencies to sibling packages in a monorepo. Try a different version or package.

**Empty tools list**

Ensure `notifications/initialized` is sent after `initialize` with adequate delays.

**Analysis errors**

Ensure Dart SDK 3.5.0+ is installed. The extractor enables common experimental features automatically.

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   pub.dev   │────▶│  Extractor  │────▶│    Cache    │
│   (HTTP)    │     │  Pipeline   │     │   (JSON)    │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                               ▼
                    ┌─────────────┐     ┌─────────────┐
                    │     AI      │◀────│ MCP Server  │
                    │  Assistant  │     │  (stdio)    │
                    └─────────────┘     └─────────────┘
```

### Design Decisions

**Generic server**: Loads documentation from JSON at runtime rather than generating code per package. This eliminates code generation bugs and allows instant updates.

**Analyzer-based extraction**: Uses `package:analyzer` directly instead of external tools. Supports experimental Dart features and works offline after initial download.

**Three-level caching**: Archives, extracted sources, and parsed JSON are cached separately for efficient incremental updates.

## Dependencies

| Package | Purpose |
|---------|---------|
| `analyzer` ^9.0.0 | Dart source code analysis |
| `args` ^2.4.0 | CLI argument parsing |
| `archive` ^4.0.0 | .tar.gz extraction |
| `dart_mcp` ^0.2.0 | MCP server implementation |
| `http` ^1.1.0 | HTTP client for pub.dev |
| `path` ^1.8.0 | Cross-platform path handling |
| `stream_channel` ^2.1.0 | Stdio stream handling |

## Limitations

- **Path dependencies** - Packages with path dependencies to sibling packages may fail extraction
- **Private packages** - Only public pub.dev packages are supported
- **SDK constraints** - Packages requiring newer SDK versions than installed will fail

## Contributing

1. Fork the repository
2. Create a feature branch
3. Run `dart format .` and `dart analyze`
4. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- Built with [dart_mcp](https://pub.dev/packages/dart_mcp) from the Dart team
- Extraction powered by [analyzer](https://pub.dev/packages/analyzer) from the Dart team
