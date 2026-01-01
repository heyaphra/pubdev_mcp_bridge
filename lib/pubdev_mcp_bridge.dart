/// pubdev_mcp_bridge - Generate MCP servers from pub.dev package documentation.
///
/// This library provides tools to extract API documentation from pub.dev
/// packages and expose them via the Model Context Protocol (MCP).
library;

export 'src/cache/cache_manager.dart';
export 'src/client/pubdev_client.dart';
export 'src/extractor/extractor.dart';
export 'src/models/package_doc.dart';
export 'src/server/mcp_server.dart';
