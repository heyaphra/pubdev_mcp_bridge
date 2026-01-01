/// A toolkit for extracting and serving Dart package documentation via MCP.
///
/// The **pubdev_mcp_bridge** library enables AI assistants to understand and
/// work with any Dart package on pub.dev by extracting API documentation and
/// exposing it through the Model Context Protocol (MCP).
///
/// ## Features
///
/// - **Zero code generation**: Single generic MCP server for any package
/// - **Smart caching**: Local cache for instant documentation reuse
/// - **11 MCP tools**: Search, browse classes, functions, enums, and more
/// - **Experimental Dart support**: Works with latest language features
///
/// ## Usage
///
/// ### As a CLI tool
///
/// ```bash
/// # Install globally
/// dart pub global activate pubdev_mcp_bridge
///
/// # Start an MCP server
/// pubdev_mcp_bridge serve dio
///
/// # Extract documentation only
/// pubdev_mcp_bridge extract riverpod
/// ```
///
/// ### As a library
///
/// ```dart
/// import 'package:pubdev_mcp_bridge/pubdev_mcp_bridge.dart';
///
/// void main() async {
///   // Extract documentation
///   final extractor = DocExtractor();
///   final package = await extractor.getPackage('dio');
///
///   // Explore the documentation
///   for (final library in package.libraries) {
///     print('Library: ${library.name}');
///     for (final cls in library.classes) {
///       print('  Class: ${cls.name}');
///     }
///   }
///
///   extractor.close();
/// }
/// ```
///
/// ## Key Components
///
/// - [DocExtractor]: Orchestrates the documentation extraction pipeline
/// - [PackageDoc]: Represents complete package documentation
/// - [PubdevClient]: HTTP client for pub.dev API
/// - [CacheManager]: Manages local documentation cache
/// - [PubdevMcpServer]: MCP server exposing documentation tools
///
/// ## Architecture
///
/// The extraction pipeline:
/// 1. [PubdevClient] downloads the package from pub.dev
/// 2. Archive is extracted to local cache
/// 3. Source code is analyzed with `package:analyzer`
/// 4. [PackageDoc] model is created and cached as JSON
/// 5. [PubdevMcpServer] loads JSON and serves via MCP
///
/// ## Cache Location
///
/// Documentation is cached in:
/// - **macOS/Linux**: `~/.pubdev_mcp_cache/`
/// - **Windows**: `%LOCALAPPDATA%\pubdev_mcp_cache\`
///
/// See also:
/// - [Model Context Protocol](https://modelcontextprotocol.io/)
/// - [pub.dev](https://pub.dev/)
library;

export 'src/cache/cache_manager.dart';
export 'src/client/pubdev_client.dart';
export 'src/extractor/extractor.dart';
export 'src/models/package_doc.dart';
export 'src/server/mcp_server.dart';
