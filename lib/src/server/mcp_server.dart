/// MCP server that exposes package documentation.
///
/// Uses the official dart_mcp package from the Dart team.
library;

import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:stream_channel/stream_channel.dart';

import '../models/package_doc.dart';

/// MCP server for pub.dev package documentation.
///
/// Exposes tools for searching and retrieving API documentation.
final class PubdevMcpServer extends MCPServer with ToolsSupport {
  // Search scoring constants
  /// Score awarded for exact name match in search.
  static const int _exactMatchScore = 100;

  /// Score awarded when name starts with the query.
  static const int _startsWithScore = 50;

  /// Score awarded when name contains the query.
  static const int _containsScore = 25;

  /// Score awarded when description contains the query.
  static const int _descriptionScore = 10;

  /// The package documentation being served.
  final PackageDoc package;

  /// Creates an MCP server for the given package.
  ///
  /// **Important**: You must call [initialize] before the server can handle
  /// requests. Tool registration happens during initialization to ensure
  /// all tools are available when the client connects, following the MCP
  /// protocol lifecycle.
  ///
  /// Example:
  /// ```dart
  /// final server = PubdevMcpServer(
  ///   channel: channel,
  ///   package: packageDoc,
  /// );
  /// await server.initialize(request);
  /// // Server is now ready to handle tool calls
  /// ```
  PubdevMcpServer({
    required StreamChannel<String> channel,
    required this.package,
  }) : super.fromStreamChannel(
         channel,
         implementation: Implementation(
           name: package.name,
           version: package.version,
         ),
         instructions:
             'MCP server providing API documentation for the ${package.name} '
             'Dart package. Use the tools to search and retrieve documentation '
             'for classes, functions, enums, and more.',
       );

  /// Initializes the server and registers all MCP tools.
  ///
  /// This method must be called before the server can handle requests.
  /// It registers the 11 documentation tools (search, get_class, etc.)
  /// after the parent server initialization completes.
  ///
  /// This follows the MCP protocol lifecycle where tools are registered
  /// during the initialization phase.
  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) async {
    final result = await super.initialize(request);
    _registerTools();
    return result;
  }

  void _registerTools() {
    // Search tool
    registerTool(
      Tool(
        name: 'search',
        description:
            'Search the ${package.name} API documentation for '
            'classes, functions, enums, and more.',
        inputSchema: ObjectSchema(
          properties: {
            'query': StringSchema(description: 'Search query'),
            'limit': IntegerSchema(
              description: 'Maximum number of results (default: 10)',
            ),
          },
          required: ['query'],
        ),
      ),
      _handleSearch,
    );

    // Get class tool
    registerTool(
      Tool(
        name: 'get_class',
        description: 'Get detailed documentation for a specific class.',
        inputSchema: ObjectSchema(
          properties: {
            'class_name': StringSchema(description: 'Name of the class'),
          },
          required: ['class_name'],
        ),
      ),
      _handleGetClass,
    );

    // Get function tool
    registerTool(
      Tool(
        name: 'get_function',
        description: 'Get detailed documentation for a specific function.',
        inputSchema: ObjectSchema(
          properties: {
            'function_name': StringSchema(description: 'Name of the function'),
          },
          required: ['function_name'],
        ),
      ),
      _handleGetFunction,
    );

    // Get enum tool
    registerTool(
      Tool(
        name: 'get_enum',
        description: 'Get detailed documentation for a specific enum.',
        inputSchema: ObjectSchema(
          properties: {
            'enum_name': StringSchema(description: 'Name of the enum'),
          },
          required: ['enum_name'],
        ),
      ),
      _handleGetEnum,
    );

    // Get library tool
    registerTool(
      Tool(
        name: 'get_library',
        description: 'Get detailed documentation for a specific library.',
        inputSchema: ObjectSchema(
          properties: {
            'library_name': StringSchema(description: 'Name of the library'),
          },
          required: ['library_name'],
        ),
      ),
      _handleGetLibrary,
    );

    // Get methods tool
    registerTool(
      Tool(
        name: 'get_methods',
        description: 'Get all methods of a specific class.',
        inputSchema: ObjectSchema(
          properties: {
            'class_name': StringSchema(description: 'Name of the class'),
          },
          required: ['class_name'],
        ),
      ),
      _handleGetMethods,
    );

    // List classes tool
    registerTool(
      Tool(
        name: 'list_classes',
        description: 'List all classes in the ${package.name} package.',
        inputSchema: ObjectSchema(properties: {}),
      ),
      _handleListClasses,
    );

    // List functions tool
    registerTool(
      Tool(
        name: 'list_functions',
        description:
            'List all top-level functions in the ${package.name} package.',
        inputSchema: ObjectSchema(properties: {}),
      ),
      _handleListFunctions,
    );

    // List enums tool
    registerTool(
      Tool(
        name: 'list_enums',
        description: 'List all enums in the ${package.name} package.',
        inputSchema: ObjectSchema(properties: {}),
      ),
      _handleListEnums,
    );

    // List libraries tool
    registerTool(
      Tool(
        name: 'list_libraries',
        description: 'List all libraries in the ${package.name} package.',
        inputSchema: ObjectSchema(properties: {}),
      ),
      _handleListLibraries,
    );

    // Get package info tool
    registerTool(
      Tool(
        name: 'get_package_info',
        description: 'Get information about the ${package.name} package.',
        inputSchema: ObjectSchema(properties: {}),
      ),
      _handleGetPackageInfo,
    );
  }

  // === Tool Handlers ===

  Future<CallToolResult> _handleSearch(CallToolRequest request) async {
    final args = request.arguments ?? {};
    final queryLower = (args['query'] as String).toLowerCase();
    final limit = args['limit'] as int? ?? 10;

    final results = <_SearchResult>[];

    // Search classes
    for (final cls in package.allClasses) {
      final score = _matchScore(cls.name, cls.description, queryLower);
      if (score > 0) {
        results.add(_SearchResult('class', cls.name, cls.description, score));
      }
    }

    // Search functions
    for (final func in package.allFunctions) {
      final score = _matchScore(func.name, func.description, queryLower);
      if (score > 0) {
        results.add(
          _SearchResult('function', func.name, func.description, score),
        );
      }
    }

    // Search enums
    for (final e in package.allEnums) {
      final score = _matchScore(e.name, e.description, queryLower);
      if (score > 0) {
        results.add(_SearchResult('enum', e.name, e.description, score));
      }
    }

    // Sort by score descending, take limit
    results.sort((a, b) => b.score.compareTo(a.score));
    final topResults = results.take(limit);

    final text =
        topResults.isEmpty
            ? 'No results found for "${args['query']}"'
            : topResults
                .map(
                  (r) =>
                      '${r.type}: ${r.name}${r.description != null ? ' - ${r.description}' : ''}',
                )
                .join('\n');

    return CallToolResult(content: [TextContent(text: text)]);
  }

  /// Calculates a relevance score for a search match.
  ///
  /// Scoring breakdown:
  /// - Exact match: [_exactMatchScore] points
  /// - Starts with query: [_startsWithScore] points
  /// - Contains query: [_containsScore] points
  /// - Description contains query: [_descriptionScore] points
  ///
  /// Higher scores indicate more relevant matches.
  ///
  /// **Performance**: The [queryLower] parameter should already be lowercased
  /// to avoid redundant conversions when searching multiple items.
  int _matchScore(String name, String? description, String queryLower) {
    var score = 0;
    final nameLower = name.toLowerCase();

    if (nameLower == queryLower) {
      score += _exactMatchScore;
    }
    if (nameLower.startsWith(queryLower)) {
      score += _startsWithScore;
    }
    if (nameLower.contains(queryLower)) {
      score += _containsScore;
    }

    // Cache description lowercase conversion
    if (description != null) {
      final descLower = description.toLowerCase();
      if (descLower.contains(queryLower)) {
        score += _descriptionScore;
      }
    }

    return score;
  }

  Future<CallToolResult> _handleGetClass(CallToolRequest request) async {
    final args = request.arguments ?? {};
    final className = args['class_name'] as String;

    final cls =
        package.allClasses.where((c) => c.name == className).firstOrNull;
    if (cls == null) {
      return CallToolResult(
        content: [TextContent(text: 'Class not found: $className')],
        isError: true,
      );
    }

    return CallToolResult(content: [TextContent(text: _formatClass(cls))]);
  }

  Future<CallToolResult> _handleGetFunction(CallToolRequest request) async {
    final args = request.arguments ?? {};
    final funcName = args['function_name'] as String;

    final func =
        package.allFunctions.where((f) => f.name == funcName).firstOrNull;
    if (func == null) {
      return CallToolResult(
        content: [TextContent(text: 'Function not found: $funcName')],
        isError: true,
      );
    }

    return CallToolResult(content: [TextContent(text: _formatFunction(func))]);
  }

  Future<CallToolResult> _handleGetEnum(CallToolRequest request) async {
    final args = request.arguments ?? {};
    final enumName = args['enum_name'] as String;

    final enumDoc =
        package.allEnums.where((e) => e.name == enumName).firstOrNull;
    if (enumDoc == null) {
      return CallToolResult(
        content: [TextContent(text: 'Enum not found: $enumName')],
        isError: true,
      );
    }

    return CallToolResult(content: [TextContent(text: _formatEnum(enumDoc))]);
  }

  Future<CallToolResult> _handleGetLibrary(CallToolRequest request) async {
    final args = request.arguments ?? {};
    final libName = args['library_name'] as String;

    final lib = package.libraries.where((l) => l.name == libName).firstOrNull;
    if (lib == null) {
      return CallToolResult(
        content: [TextContent(text: 'Library not found: $libName')],
        isError: true,
      );
    }

    return CallToolResult(content: [TextContent(text: _formatLibrary(lib))]);
  }

  Future<CallToolResult> _handleGetMethods(CallToolRequest request) async {
    final args = request.arguments ?? {};
    final className = args['class_name'] as String;

    final cls =
        package.allClasses.where((c) => c.name == className).firstOrNull;
    if (cls == null) {
      return CallToolResult(
        content: [TextContent(text: 'Class not found: $className')],
        isError: true,
      );
    }

    final text =
        cls.methods.isEmpty
            ? '$className has no methods'
            : cls.methods
                .map((m) => '${m.signature}\n  ${m.description ?? ''}')
                .join('\n\n');

    return CallToolResult(content: [TextContent(text: text)]);
  }

  Future<CallToolResult> _handleListClasses(CallToolRequest request) async {
    final classes = package.allClasses;
    final text =
        classes.isEmpty
            ? 'No classes found'
            : classes.map((c) => c.name).join('\n');
    return CallToolResult(content: [TextContent(text: text)]);
  }

  Future<CallToolResult> _handleListFunctions(CallToolRequest request) async {
    final functions = package.allFunctions;
    final text =
        functions.isEmpty
            ? 'No top-level functions found'
            : functions.map((f) => f.name).join('\n');
    return CallToolResult(content: [TextContent(text: text)]);
  }

  Future<CallToolResult> _handleListEnums(CallToolRequest request) async {
    final enums = package.allEnums;
    final text =
        enums.isEmpty ? 'No enums found' : enums.map((e) => e.name).join('\n');
    return CallToolResult(content: [TextContent(text: text)]);
  }

  Future<CallToolResult> _handleListLibraries(CallToolRequest request) async {
    final libs = package.libraries;
    final text =
        libs.isEmpty
            ? 'No libraries found'
            : libs.map((l) => l.name).join('\n');
    return CallToolResult(content: [TextContent(text: text)]);
  }

  Future<CallToolResult> _handleGetPackageInfo(CallToolRequest request) async {
    final buffer = StringBuffer();
    buffer.writeln('Package: ${package.name}');
    buffer.writeln('Version: ${package.version}');
    if (package.description != null) {
      buffer.writeln('Description: ${package.description}');
    }
    if (package.homepage != null) {
      buffer.writeln('Homepage: ${package.homepage}');
    }
    if (package.repository != null) {
      buffer.writeln('Repository: ${package.repository}');
    }
    buffer.writeln();
    buffer.writeln('Statistics:');
    buffer.writeln('  Libraries: ${package.libraries.length}');
    buffer.writeln('  Classes: ${package.allClasses.length}');
    buffer.writeln('  Functions: ${package.allFunctions.length}');
    buffer.writeln('  Enums: ${package.allEnums.length}');

    return CallToolResult(content: [TextContent(text: buffer.toString())]);
  }

  // === Formatters ===

  String _formatClass(ClassDoc cls) {
    final buffer = StringBuffer();
    if (cls.isAbstract) buffer.write('abstract ');
    buffer.writeln('class ${cls.name}');

    if (cls.superclass != null) {
      buffer.writeln('  extends ${cls.superclass}');
    }
    if (cls.interfaces.isNotEmpty) {
      buffer.writeln('  implements ${cls.interfaces.join(', ')}');
    }
    if (cls.mixins.isNotEmpty) {
      buffer.writeln('  with ${cls.mixins.join(', ')}');
    }
    buffer.writeln();

    if (cls.description != null) {
      buffer.writeln(cls.description);
      buffer.writeln();
    }

    if (cls.constructors.isNotEmpty) {
      buffer.writeln('Constructors:');
      for (final c in cls.constructors) {
        buffer.writeln('  ${c.signature}');
      }
      buffer.writeln();
    }

    if (cls.fields.isNotEmpty) {
      buffer.writeln('Fields:');
      for (final f in cls.fields) {
        buffer.writeln('  ${f.type} ${f.name}');
      }
      buffer.writeln();
    }

    if (cls.methods.isNotEmpty) {
      buffer.writeln('Methods:');
      for (final m in cls.methods) {
        buffer.writeln('  ${m.signature}');
      }
    }

    return buffer.toString();
  }

  String _formatFunction(FunctionDoc func) {
    final buffer = StringBuffer();
    buffer.writeln(func.signature);
    buffer.writeln();
    if (func.description != null) {
      buffer.writeln(func.description);
    }
    return buffer.toString();
  }

  String _formatEnum(EnumDoc enumDoc) {
    final buffer = StringBuffer();
    buffer.writeln('enum ${enumDoc.name}');
    buffer.writeln();

    if (enumDoc.description != null) {
      buffer.writeln(enumDoc.description);
      buffer.writeln();
    }

    buffer.writeln('Values:');
    for (final v in enumDoc.values) {
      buffer.write('  ${v.name}');
      if (v.description != null) {
        buffer.write(' - ${v.description}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  String _formatLibrary(LibraryDoc lib) {
    final buffer = StringBuffer();
    buffer.writeln('library ${lib.name}');
    buffer.writeln();

    if (lib.description != null) {
      buffer.writeln(lib.description);
      buffer.writeln();
    }

    if (lib.classes.isNotEmpty) {
      buffer.writeln('Classes: ${lib.classes.map((c) => c.name).join(', ')}');
    }
    if (lib.functions.isNotEmpty) {
      buffer.writeln(
        'Functions: ${lib.functions.map((f) => f.name).join(', ')}',
      );
    }
    if (lib.enums.isNotEmpty) {
      buffer.writeln('Enums: ${lib.enums.map((e) => e.name).join(', ')}');
    }

    return buffer.toString();
  }
}

/// Internal search result for ranking documentation matches.
///
/// This class is private because it's an implementation detail of the
/// search algorithm and not part of the public API.
final class _SearchResult {
  /// The type of element (e.g., 'class', 'function', 'enum').
  final String type;

  /// The name of the element.
  final String name;

  /// Optional description of the element.
  final String? description;

  /// The search relevance score (higher is better).
  final int score;

  /// Creates a search result with the given properties.
  const _SearchResult(this.type, this.name, this.description, this.score);
}
