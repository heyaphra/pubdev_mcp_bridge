# pubdev_mcp_bridge Examples

This directory contains examples of using pubdev_mcp_bridge.

## Basic Usage

### Example 1: Starting an MCP Server

```bash
# Install globally
dart pub global activate pubdev_mcp_bridge

# Start a server for the 'dio' package
pubdev_mcp_bridge serve dio
```

### Example 2: Extracting Documentation

```bash
# Extract documentation without starting a server
pubdev_mcp_bridge extract riverpod

# Extract a specific version
pubdev_mcp_bridge extract riverpod --version 2.5.0

# Force refresh (ignore cache)
pubdev_mcp_bridge extract riverpod --refresh
```

### Example 3: Managing Cache

```bash
# List cached packages
pubdev_mcp_bridge list

# Clean a specific package
pubdev_mcp_bridge clean dio

# Clean a specific version
pubdev_mcp_bridge clean dio --version 5.4.0

# Clean all cached data
pubdev_mcp_bridge clean --all
```

## Integration Examples

### Example 4: Claude Code Integration

```bash
# Add an MCP server for a package
claude mcp add dio pubdev_mcp_bridge serve dio

# Add with project scope
claude mcp add --scope project freezed pubdev_mcp_bridge serve freezed

# Add with user scope (available globally)
claude mcp add --scope user riverpod pubdev_mcp_bridge serve riverpod

# List registered servers
claude mcp list
```

### Example 5: Claude Desktop Integration

Add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "dio": {
      "command": "pubdev_mcp_bridge",
      "args": ["serve", "dio"]
    },
    "riverpod": {
      "command": "pubdev_mcp_bridge",
      "args": ["serve", "riverpod"]
    }
  }
}
```

### Example 6: Manual MCP Testing

Test the MCP server using JSON-RPC over stdio:

```bash
(
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test"}}}'
  sleep 3
  echo '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
  sleep 2
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_package_info","arguments":{}}}'
  sleep 1
) | pubdev_mcp_bridge serve dio 2>/dev/null
```

## MCP Tool Usage Examples

Once the server is running and connected to an AI assistant, you can use the following tools:

### Example 7: Get Package Information

```
Tool: get_package_info
Arguments: {}

Response:
Package: dio
Version: 5.4.0
Description: A powerful HTTP client for Dart
Libraries: 12
Classes: 45
Functions: 8
Enums: 6
```

### Example 8: Search Documentation

```
Tool: search
Arguments: { "query": "interceptor" }

Response:
class: Interceptor - Base class for interceptors
class: InterceptorError - Exception thrown by interceptors
function: addInterceptor - Add an interceptor to the client
```

### Example 9: Get Class Details

```
Tool: get_class
Arguments: { "class_name": "Dio" }

Response:
class Dio extends Object

A powerful HTTP client for Dart.

Constructors:
  Dio([BaseOptions? options])

Methods:
  Future<Response> get(String path)
  Future<Response> post(String path)
  ...
```

### Example 10: List All Classes

```
Tool: list_classes
Arguments: {}

Response:
Classes in dio:
- Dio
- Response
- RequestOptions
- BaseOptions
- Interceptor
- ...
```

## Advanced Usage

### Example 11: Working with Multiple Packages

```bash
# Start servers for multiple packages (in separate terminals or as background processes)
pubdev_mcp_bridge serve dio &
pubdev_mcp_bridge serve http &
pubdev_mcp_bridge serve riverpod &

# Or register them all with Claude Code
claude mcp add dio pubdev_mcp_bridge serve dio
claude mcp add http pubdev_mcp_bridge serve http
claude mcp add riverpod pubdev_mcp_bridge serve riverpod
```

### Example 12: Development Workflow

```bash
# Install from local source during development
cd /path/to/pubdev_mcp_bridge
dart pub global activate --source path .

# Test changes
pubdev_mcp_bridge serve test_package

# Run directly without global install
dart run bin/pubdev_mcp_bridge.dart serve test_package
```

## Troubleshooting Examples

### Example 13: Debugging Cache Issues

```bash
# Check cache location
ls ~/.pubdev_mcp_cache/

# View cached documentation
cat ~/.pubdev_mcp_cache/docs/dio-5.4.0.json | head -100

# Check extracted source
ls ~/.pubdev_mcp_cache/extracted/dio-5.4.0/

# Clear and re-extract if needed
pubdev_mcp_bridge clean dio
pubdev_mcp_bridge extract dio --refresh
```

### Example 14: Handling Analysis Errors

If extraction fails due to analysis errors:

```bash
# Try a different version
pubdev_mcp_bridge serve dio --version 5.3.0

# Check the error logs (stderr is shown during extraction)
pubdev_mcp_bridge extract problematic_package 2>&1 | tee error.log

# Some packages with path dependencies may not work
# Try alternative packages with similar functionality
```

## Platform-Specific Examples

### Windows

```cmd
REM Cache location
dir %LOCALAPPDATA%\pubdev_mcp_cache

REM Install globally
dart pub global activate pubdev_mcp_bridge

REM Run server
pubdev_mcp_bridge serve dio
```

### macOS/Linux

```bash
# Cache location
ls ~/.pubdev_mcp_cache/

# Install globally
dart pub global activate pubdev_mcp_bridge

# Run server
pubdev_mcp_bridge serve dio
```
