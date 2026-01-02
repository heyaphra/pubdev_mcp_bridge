/// Parses analyzer JSON output into PackageDoc model.
///
/// Converts the JSON output from [DartMetadataExtractor] (which uses
/// `package:analyzer`) into structured [PackageDoc] objects for caching
/// and serving via MCP.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/package_doc.dart';
import 'extraction_exception.dart';

/// Parses analyzer JSON output into [PackageDoc] model.
///
/// The [DartMetadataExtractor] produces JSON containing library declarations
/// (classes, functions, enums, etc.) which this parser converts into
/// strongly-typed model objects.
class DartdocParser {
  /// Parses the analyzer JSON file into a PackageDoc.
  ///
  /// The [jsonPath] should point to the JSON file created by
  /// [DartMetadataExtractor.run].
  Future<PackageDoc> parse(
    String jsonPath,
    String packageName,
    String version,
  ) async {
    final file = File(jsonPath);
    if (!file.existsSync()) {
      throw ExtractionException(
        'JSON file not found',
        'Expected file at: $jsonPath',
      );
    }

    final content = await file.readAsString();
    final json = jsonDecode(content);

    // The analyzer outputs an array of library objects
    final libraryList = json as List<dynamic>;
    final libraries = <LibraryDoc>[];

    for (final libJson in libraryList) {
      final lib = _parseLibrary(libJson as Map<String, dynamic>);
      if (lib != null) {
        libraries.add(lib);
      }
    }

    return PackageDoc(
      name: packageName,
      version: version,
      libraries: libraries,
    );
  }

  LibraryDoc? _parseLibrary(Map<String, dynamic> json) {
    final source = json['source'] as String?;
    if (source == null) return null;

    // Extract library name from source path
    final name = p.basenameWithoutExtension(source);
    final declarations = json['declarations'] as List<dynamic>? ?? [];

    final classes = <ClassDoc>[];
    final functions = <FunctionDoc>[];
    final enums = <EnumDoc>[];
    final variables = <VariableDoc>[];
    final typedefs = <TypedefDoc>[];
    final extensions = <ExtensionDoc>[];
    final mixins = <MixinDoc>[];

    for (final decl in declarations) {
      final declMap = decl as Map<String, dynamic>;
      final kind = declMap['kind'] as String?;

      switch (kind) {
        case 'class':
          classes.add(_parseClass(declMap));
        case 'function':
          functions.add(_parseFunction(declMap));
        case 'enum':
          enums.add(_parseEnum(declMap));
        case 'variable':
          variables.add(_parseVariable(declMap));
        case 'typedef':
          typedefs.add(_parseTypedef(declMap));
        case 'extension':
          extensions.add(_parseExtension(declMap));
        case 'mixin':
          mixins.add(_parseMixin(declMap));
      }
    }

    return LibraryDoc(
      name: name,
      classes: classes,
      functions: functions,
      enums: enums,
      variables: variables,
      typedefs: typedefs,
      extensions: extensions,
      mixins: mixins,
    );
  }

  ClassDoc _parseClass(Map<String, dynamic> json) {
    return ClassDoc(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      superclass: json['extends'] as String?,
      interfaces: _parseStringList(json['implements']),
      mixins: _parseStringList(json['with']),
      typeParameters: _parseTypeParams(json['typeParameters']),
      constructors: _parseConstructors(json['constructors']),
      methods: _parseMethods(json['methods']),
      fields: _parseFields(json['fields']),
      isAbstract: json['abstract'] as bool? ?? false,
    );
  }

  List<ConstructorDoc> _parseConstructors(dynamic json) {
    if (json == null) return [];
    return (json as List<dynamic>)
        .map((c) => _parseConstructor(c as Map<String, dynamic>))
        .toList();
  }

  ConstructorDoc _parseConstructor(Map<String, dynamic> json) {
    return ConstructorDoc(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      parameters: _parseParameters(json['parameters']),
      isConst: json['const'] as bool? ?? false,
      isFactory: json['factory'] as bool? ?? false,
    );
  }

  List<MethodDoc> _parseMethods(dynamic json) {
    if (json == null) return [];
    return (json as List<dynamic>)
        .map((m) => _parseMethod(m as Map<String, dynamic>))
        .toList();
  }

  MethodDoc _parseMethod(Map<String, dynamic> json) {
    return MethodDoc(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      returnType: json['returns'] as String? ?? 'dynamic',
      parameters: _parseParameters(json['parameters']),
      typeParameters: _parseTypeParams(json['typeParameters']),
      isStatic: json['static'] as bool? ?? false,
      isAbstract: json['abstract'] as bool? ?? false,
      isOperator: json['operator'] as bool? ?? false,
      isGetter: json['getter'] as bool? ?? false,
      isSetter: json['setter'] as bool? ?? false,
    );
  }

  List<FieldDoc> _parseFields(dynamic json) {
    if (json == null) return [];
    return (json as List<dynamic>)
        .map((f) => _parseField(f as Map<String, dynamic>))
        .toList();
  }

  FieldDoc _parseField(Map<String, dynamic> json) {
    return FieldDoc(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'dynamic',
      isStatic: json['static'] as bool? ?? false,
      isFinal: json['final'] as bool? ?? false,
      isConst: json['const'] as bool? ?? false,
      isLate: json['late'] as bool? ?? false,
    );
  }

  List<ParameterDoc> _parseParameters(dynamic json) {
    if (json == null) return [];

    // Parameters can be in different formats
    if (json is Map<String, dynamic>) {
      final all = json['all'] as List<dynamic>? ?? [];
      final positionalCount = json['positional'] as int? ?? all.length;

      return all.asMap().entries.map((entry) {
        final p = entry.value as Map<String, dynamic>;
        final isPositional = entry.key < positionalCount;
        return ParameterDoc(
          name: p['name'] as String? ?? '',
          type: p['type'] as String? ?? 'dynamic',
          isRequired:
              p['required'] as bool? ?? (isPositional && p['default'] == null),
          isNamed: !isPositional,
          isPositional: isPositional,
          defaultValue: p['default'] as String?,
        );
      }).toList();
    }

    if (json is List<dynamic>) {
      return json.map((p) {
        final pMap = p as Map<String, dynamic>;
        return ParameterDoc(
          name: pMap['name'] as String? ?? '',
          type: pMap['type'] as String? ?? 'dynamic',
          isRequired: pMap['required'] as bool? ?? true,
          isNamed: pMap['named'] as bool? ?? false,
          isPositional: !(pMap['named'] as bool? ?? false),
          defaultValue: pMap['default'] as String?,
        );
      }).toList();
    }

    return [];
  }

  FunctionDoc _parseFunction(Map<String, dynamic> json) {
    return FunctionDoc(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      returnType: json['returns'] as String? ?? 'dynamic',
      parameters: _parseParameters(json['parameters']),
      typeParameters: _parseTypeParams(json['typeParameters']),
    );
  }

  EnumDoc _parseEnum(Map<String, dynamic> json) {
    final values =
        (json['values'] as List<dynamic>? ?? []).map((v) {
          if (v is String) {
            return EnumValueDoc(name: v);
          }
          final vMap = v as Map<String, dynamic>;
          return EnumValueDoc(
            name: vMap['name'] as String? ?? '',
            description: vMap['description'] as String?,
          );
        }).toList();

    return EnumDoc(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      values: values,
      methods: _parseMethods(json['methods']),
      fields: _parseFields(json['fields']),
    );
  }

  TypedefDoc _parseTypedef(Map<String, dynamic> json) {
    return TypedefDoc(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'dynamic',
      typeParameters: _parseTypeParams(json['typeParameters']),
    );
  }

  ExtensionDoc _parseExtension(Map<String, dynamic> json) {
    return ExtensionDoc(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      onType: json['on'] as String? ?? 'dynamic',
      methods: _parseMethods(json['methods']),
      fields: _parseFields(json['fields']),
    );
  }

  MixinDoc _parseMixin(Map<String, dynamic> json) {
    return MixinDoc(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      superclassConstraints: _parseStringList(json['on']),
      interfaces: _parseStringList(json['implements']),
      methods: _parseMethods(json['methods']),
      fields: _parseFields(json['fields']),
    );
  }

  VariableDoc _parseVariable(Map<String, dynamic> json) {
    return VariableDoc(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'dynamic',
      isConst: json['const'] as bool? ?? false,
      isFinal: json['final'] as bool? ?? false,
    );
  }

  List<String> _parseTypeParams(dynamic json) {
    if (json == null) return [];
    if (json is List<dynamic>) {
      return json
          .map((t) {
            if (t is String) return t;
            if (t is Map<String, dynamic>) return t['name'] as String? ?? '';
            return '';
          })
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  List<String> _parseStringList(dynamic json) {
    if (json == null) return [];
    if (json is String) return [json];
    if (json is List<dynamic>) return json.cast<String>();
    return [];
  }
}
