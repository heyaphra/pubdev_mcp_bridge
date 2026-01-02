# pubdev_mcp_bridge

**AI assistants hallucinate Dart APIs. This fixes it.**

```bash
pubdev_mcp_bridge serve dio
```

Extracts accurate API documentation from any pub.dev package and serves it via MCP, giving AI assistants like Claude, Cursor, and Windsurf perfect knowledge of Dart libraries.

<!-- ![Demo](demo.gif) -->

## Why This Matters

- **Any package**: Works with all public packages on pub.dev
- **Any MCP client**: Compatible with Claude Code, Claude Desktop, Cursor, Windsurf, Cline, and other MCP-enabled tools
- **Zero configuration**: One command to extract and serve documentation
- **Always accurate**: Extracts documentation directly from source code using the Dart analyzer
- **Experimental features**: Supports packages using macros, records, dot-shorthands, and other modern Dart syntax

## Installation

**Prerequisites**: Dart SDK 3.7.0 or later

Install globally from pub.dev:

```bash
dart pub global activate pubdev_mcp_bridge
```

Make sure the pub cache bin directory is in your PATH:
- **macOS/Linux**: Add `export PATH="$PATH":"$HOME/.pub-cache/bin"` to your shell profile
- **Windows**: Add `%LOCALAPPDATA%\Pub\Cache\bin` to your PATH

Or install from source:

```bash
git clone https://github.com/heyaphra/pubdev_mcp_bridge.git
cd pubdev_mcp_bridge
dart pub get
dart pub global activate --source path .
```

## Usage

### `serve <package>` - Start MCP Server

Extracts documentation (if not cached) and starts an MCP server:

```bash
# Serve the latest version
pubdev_mcp_bridge serve riverpod

# Serve a specific version
pubdev_mcp_bridge serve riverpod --version 2.5.0

# Force re-extraction (ignore cache)
pubdev_mcp_bridge serve riverpod --refresh
```

### `extract <package>` - Extract Documentation Only

Downloads and extracts documentation without starting a server:

```bash
pubdev_mcp_bridge extract freezed
pubdev_mcp_bridge extract freezed --version 2.4.0
```

### `list` - List Cached Packages

Shows all packages with cached documentation:

```bash
pubdev_mcp_bridge list
# Output:
# Cached packages:
#   riverpod@2.6.1
#   dio@5.4.0
#   music_notes@0.24.0
```

### `clean` - Remove Cached Data

```bash
# Remove a specific package (all versions)
pubdev_mcp_bridge clean riverpod

# Remove a specific version
pubdev_mcp_bridge clean riverpod --version 2.5.0

# Remove all cached data
pubdev_mcp_bridge clean --all
```

## Connecting to AI Assistants

### Claude Code

Use the `claude mcp add` command:

```bash
# Add a server (if installed globally)
claude mcp add riverpod pubdev_mcp_bridge serve riverpod

# Or run directly from the project directory
claude mcp add riverpod dart run /path/to/pubdev_mcp_bridge/bin/pubdev_mcp_bridge.dart serve riverpod
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

### Claude Desktop

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

### Cursor / Windsurf

Add to your MCP settings file (location varies by editor):

```json
{
  "mcpServers": {
    "dio": {
      "command": "pubdev_mcp_bridge",
      "args": ["serve", "dio"]
    }
  }
}
```

### Other MCP Clients

Any tool that supports the Model Context Protocol can connect to pubdev_mcp_bridge. Consult your tool's documentation for MCP server configuration.

## Available Tools

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

## Example: Accurate API Responses

With the `music_notes` package server running, AI assistants can answer questions with perfect accuracy:

**User**: "How do I create a chord in the music_notes package?"

**AI Assistant** (with pubdev_mcp_bridge):
```
You can create a Chord using its constructor:

  Chord(this._items)

The Chord class is generic (Chord<T>) and implements Transposable<Chord<T>>.

Example usage:
  final chord = Chord([Note.c, Note.e, Note.g]);
  
You can also get the chord's pattern:
  ChordPattern pattern = chord.pattern();

Or transpose it:
  Chord<T> transposed = chord.transposeBy(Interval.perfectFourth);
```

**Without pubdev_mcp_bridge**: Hallucinated APIs, outdated examples, incorrect method signatures.

## How It Works

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

pubdev_mcp_bridge downloads packages from pub.dev, extracts API documentation using the Dart analyzer, caches it locally as JSON, and serves it via an MCP server. AI assistants query the server to get accurate, up-to-date information about Dart packages.

## Limitations

- **Path dependencies**: Packages with path dependencies (e.g., `path: ../sibling_package` in monorepos) will fail during `dart pub get` because the sibling packages don't exist in the extracted directory. Try a different version or contact the package maintainer.
- **Private packages**: Only public packages on pub.dev are supported. The tool uses unauthenticated HTTP requests to the pub.dev API.
- **SDK constraints**: Packages requiring a newer Dart SDK than you have installed will fail during `dart pub get`. For example, if a package requires `sdk: ^3.8.0` but you have Dart 3.7.0, extraction will fail. Upgrade your Dart SDK or try an older package version.

## Troubleshooting

**Server starts but tools don't appear**

Restart your AI assistant or IDE. Some clients cache MCP server capabilities.

**Extraction fails for a specific package**

Try a different version:
```bash
pubdev_mcp_bridge serve package_name --version 1.2.3
```

**Cache issues**

Clear the cache and re-extract:
```bash
pubdev_mcp_bridge clean --all
pubdev_mcp_bridge serve package_name --refresh
```

**Check cached documentation**

```bash
# List cached packages
ls ~/.pubdev_mcp_cache/docs/

# View cached JSON
cat ~/.pubdev_mcp_cache/docs/dio-5.4.0.json | head -100
```

**Windows users**: Replace `~/.pubdev_mcp_cache` with `%LOCALAPPDATA%\pubdev_mcp_cache`

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, architecture details, and guidelines.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [dart_mcp](https://pub.dev/packages/dart_mcp) from the Dart team
- Extraction powered by [analyzer](https://pub.dev/packages/analyzer) from the Dart team
- Model Context Protocol by [Anthropic](https://modelcontextprotocol.io/)
