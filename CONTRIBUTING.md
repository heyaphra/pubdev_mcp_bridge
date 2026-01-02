# Contributing to pubdev_mcp_bridge

Thank you for your interest in contributing! This guide covers the project structure, development workflow, and how to extend the codebase.

## Table of Contents

- [Project Structure](#project-structure)
- [Key Components](#key-components)
- [Development Setup](#development-setup)
- [Adding New MCP Tools](#adding-new-mcp-tools)
- [Testing](#testing)
- [Debugging](#debugging)
- [Code Quality](#code-quality)

## Project Structure

```
pubdev_mcp_bridge/
├── bin/
│   └── pubdev_mcp_bridge.dart          # CLI entry point
├── lib/
│   ├── pubdev_mcp_bridge.dart          # Public API exports
│   └── src/
│       ├── cache/
│       │   └── cache_manager.dart      # Local cache management
│       ├── client/
│       │   └── pubdev_client.dart      # pub.dev HTTP client
│       ├── cli/
│       │   ├── runner.dart             # CLI command runner
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
│       │   └── package_doc.dart        # Data models
│       └── server/
│           └── mcp_server.dart         # MCP server implementation
└── pubspec.yaml
```

## Key Components

### Cache Manager

**Location**: `lib/src/cache/cache_manager.dart`

Manages three-level caching under `~/.pubdev_mcp_cache/` (macOS/Linux) or `%LOCALAPPDATA%/pubdev_mcp_cache/` (Windows):

- **`archives/`** - Downloaded .tar.gz files from pub.dev
- **`extracted/`** - Unpacked package source code
- **`docs/`** - Parsed documentation as JSON

The cache manager provides methods for:
- Getting cache paths for different levels
- Checking if documentation exists
- Cleaning cache by package/version
- Listing all cached packages

### Extractor Pipeline

**Location**: `lib/src/extractor/`

The extraction pipeline processes packages in four stages:

1. **PubdevClient** (`client/pubdev_client.dart`)
   - Downloads package archives from pub.dev API
   - Fetches package metadata

2. **ArchiveHandler** (`extractor/archive_handler.dart`)
   - Extracts .tar.gz archives
   - Handles nested directory structures

3. **DartMetadataExtractor** (`extractor/dart_metadata_extractor.dart`)
   - Uses `package:analyzer` to parse Dart source files
   - Extracts classes, functions, enums, libraries
   - Supports experimental Dart features (dot-shorthands, macros, records)
   - Generates `analysis_options.yaml` with experimental flags enabled

4. **DartdocParser** (`extractor/dartdoc_parser.dart`)
   - Converts extracted data to `PackageDoc` model
   - Validates and structures documentation

#### Why `package:analyzer` instead of dartdoc_json?

`dartdoc_json` fails on packages using experimental Dart features because it doesn't expose flags to enable them. We use `package:analyzer` directly and programmatically generate `analysis_options.yaml` with all experimental features enabled, ensuring compatibility with modern Dart packages.

### MCP Server

**Location**: `lib/src/server/mcp_server.dart`

The MCP server extends `MCPServer` with `ToolsSupport` from the `dart_mcp` package. It:
- Loads documentation from JSON cache
- Registers 11 tools for querying documentation
- Handles JSON-RPC 2.0 requests over stdio
- Provides search, filtering, and detailed documentation retrieval

**Why a generic server instead of code generation?**

Previous versions generated a separate Dart project per package. The current architecture uses a single server that loads JSON documentation at runtime—simpler, faster, and eliminates code generation bugs.

## Development Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/heyaphra/pubdev_mcp_bridge.git
   cd pubdev_mcp_bridge
   ```

2. **Install dependencies**:
   ```bash
   dart pub get
   ```

3. **Run during development**:
   ```bash
   dart run bin/pubdev_mcp_bridge.dart serve dio
   ```

4. **Install globally for testing**:
   ```bash
   dart pub global activate --source path .
   ```

## Adding New MCP Tools

To add a new tool to the MCP server:

### 1. Define the tool in `_registerTools()`

Edit `lib/src/server/mcp_server.dart` and add your tool definition:

```dart
void _registerTools() {
  // ... existing tools ...

  // Add your new tool
  registerTool(
    Tool(
      name: 'get_type_aliases',
      description: 'List all type aliases in the package',
      inputSchema: ObjectSchema(
        properties: {
          'library': StringSchema(
            description: 'Optional: filter by library name',
          ),
        },
      ),
    ),
    _handleGetTypeAliases,
  );
}
```

### 2. Implement the handler method

Add the handler method in the same file:

```dart
Future<CallToolResult> _handleGetTypeAliases(
  CallToolRequest request,
) async {
  final library = request.arguments?['library'] as String?;
  
  // Access documentation
  final doc = _packageDoc;
  if (doc == null) {
    return CallToolResult(
      content: [TextContent(text: 'Documentation not loaded')],
      isError: true,
    );
  }

  // Implement your logic
  final typeAliases = doc.libraries
      .where((lib) => library == null || lib.name == library)
      .expand((lib) => lib.typeAliases)
      .toList();

  // Format and return results
  final buffer = StringBuffer();
  for (final alias in typeAliases) {
    buffer.writeln('${alias.name}: ${alias.type}');
    if (alias.documentation?.isNotEmpty ?? false) {
      buffer.writeln('  ${alias.documentation}');
    }
    buffer.writeln();
  }

  return CallToolResult(
    content: [TextContent(text: buffer.toString())],
  );
}
```

### 3. Update the data model (if needed)

If your tool requires new data fields, update `lib/src/models/package_doc.dart`:

```dart
class LibraryDoc {
  final String name;
  final List<ClassDoc> classes;
  final List<FunctionDoc> functions;
  final List<TypeAliasDoc> typeAliases; // Add new field
  // ...
}
```

### 4. Update the extractor (if needed)

If you're adding support for a new Dart element type, update `lib/src/extractor/dart_metadata_extractor.dart` to extract it from the AST.

## Testing

### Manual MCP Testing

The server communicates via JSON-RPC 2.0 over stdio. Test manually using:

```bash
(
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test"}}}'
  sleep 3
  echo '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
  sleep 2
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_package_info","arguments":{}}}'
  sleep 1
  echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"search","arguments":{"query":"http"}}}'
  sleep 1
) | dart run bin/pubdev_mcp_bridge.dart serve dio 2>/dev/null
```

### Integration Testing with MCP Clients

Test with actual MCP clients:

**Claude Code**:
```bash
claude mcp add test-package pubdev_mcp_bridge serve dio
```

**Claude Desktop**: Add to `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "test-dio": {
      "command": "dart",
      "args": ["run", "/path/to/pubdev_mcp_bridge/bin/pubdev_mcp_bridge.dart", "serve", "dio"]
    }
  }
}
```

## Debugging

### Inspecting Cache

```bash
# List cached packages
ls ~/.pubdev_mcp_cache/docs/

# View cached JSON documentation
cat ~/.pubdev_mcp_cache/docs/dio-5.4.0.json | head -100

# Check extracted source code
ls ~/.pubdev_mcp_cache/extracted/dio-5.4.0/

# View archived packages
ls ~/.pubdev_mcp_cache/archives/
```

### Common Issues

**"dart pub get failed" with path dependencies**

When a package is downloaded from pub.dev, its `pubspec.yaml` may contain path dependencies like `path: ../sibling_package` that reference other packages in the original monorepo. When the package is extracted locally, these sibling directories don't exist, causing `dart pub get` to fail.

**Workaround**: Try a different version of the package (some versions may have fewer path dependencies), or contact the package maintainer to publish the dependencies separately on pub.dev.

**Empty tools list in MCP client**

The MCP protocol requires a proper handshake sequence. Ensure `notifications/initialized` is sent after `initialize` with adequate delays between messages. Some clients may cache server capabilities—restart the client if tools don't appear.

**Analysis errors during extraction**

The extractor runs `dart pub get` to resolve dependencies. If a package requires a newer SDK than you have installed (e.g., package requires `sdk: ^3.8.0` but you have Dart 3.7.0), pub get will fail.

**Solution**: Upgrade your Dart SDK to match the package requirements, or try an older version of the package that has compatible SDK constraints.

**Note**: The extractor automatically enables experimental features (macros, records, etc.) via `analysis_options.yaml`, so most modern Dart syntax is supported.

**Server not responding**

Check stderr output for errors:
```bash
dart run bin/pubdev_mcp_bridge.dart serve dio 2>error.log
cat error.log
```

## Code Quality

Before submitting a PR:

```bash
# Format code
dart format .

# Run static analysis
dart analyze

# Ensure no warnings or errors
```

### Code Style Guidelines

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use meaningful variable and function names
- Add documentation comments for public APIs
- Keep methods focused and single-purpose
- Prefer composition over inheritance

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run `dart format .` and `dart analyze`
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to your fork (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Architecture Decisions

### Why These Technologies?

- **`analyzer` ^9.0.0**: Direct AST access, supports experimental features, no external tools required
- **`dart_mcp` ^0.4.0**: Official MCP implementation from Dart team
- **Generic server approach**: Simpler than code generation, no build steps, instant updates

### Design Principles

1. **Simplicity**: Prefer straightforward solutions over clever abstractions
2. **Caching**: Cache aggressively at multiple levels for performance
3. **Error handling**: Fail fast with clear error messages
4. **Extensibility**: Make it easy to add new tools and features

## Questions or Need Help?

- Open an issue on GitHub
- Check existing issues for similar problems
- Review the code examples in this guide

Thank you for contributing!
