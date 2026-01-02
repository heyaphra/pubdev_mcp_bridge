/// Extracts API documentation from Dart packages using package:analyzer.
///
/// Replaces dartdoc_json with direct analyzer access, enabling support for
/// experimental language features like dot-shorthands.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;

/// Extracts API documentation from Dart packages using package:analyzer.
class DartMetadataExtractor {
  /// Checks if analyzer is available (always true, it's a dependency).
  Future<bool> isAvailable() async => true;

  /// Prepares package for analysis by removing workspace resolution.
  ///
  /// Packages developed in Dart workspaces (monorepos) may have
  /// `resolution: workspace` in their pubspec.yaml. This is a development-time
  /// artifact - published packages on pub.dev have normal dependencies that
  /// work standalone. We strip this line from all pubspec.yaml files in the
  /// package directory to allow `dart pub get` to succeed.
  Future<void> _prepareForAnalysis(String packageDir) async {
    // Find all pubspec.yaml files recursively
    final packageDirEntity = Directory(packageDir);
    if (!packageDirEntity.existsSync()) return;

    await for (final entity in packageDirEntity.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('pubspec.yaml')) {
        var content = await entity.readAsString();

        if (content.contains('resolution: workspace')) {
          content = content.replaceAll(
            RegExp(r'resolution:\s*workspace\s*\n?'),
            '',
          );
          await entity.writeAsString(content);
        }
      }
    }
  }

  /// Runs `dart pub get` in the package directory.
  Future<void> pubGet(String packageDir) async {
    // Strip workspace resolution if present
    await _prepareForAnalysis(packageDir);

    final result = await Process.run('dart', [
      'pub',
      'get',
    ], workingDirectory: packageDir);
    if (result.exitCode != 0) {
      throw StateError('dart pub get failed: ${result.stderr}');
    }
  }

  /// Finds all Dart library files in a package.
  List<String> findLibraryFiles(String packageDir) {
    final libDir = Directory(p.join(packageDir, 'lib'));
    if (!libDir.existsSync()) return [];

    final files = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(p.normalize(entity.path));
      }
    }
    return files;
  }

  /// Creates analysis_options.yaml with experimental features enabled.
  Future<void> _createAnalysisOptions(String packageDir) async {
    final file = File(p.join(packageDir, 'analysis_options.yaml'));
    const content = '''
analyzer:
  enable-experiment:
    - dot-shorthands
    - inline-class
    - macros
    - enhanced-enums
    - records
    - patterns
''';
    await file.writeAsString(content);
  }

  /// Extracts documentation and writes JSON to output file.
  ///
  /// Returns the path to the generated JSON file.
  Future<String> run(String packageDir) async {
    // Ensure experimental features are enabled
    await _createAnalysisOptions(packageDir);

    // Run pub get to resolve dependencies
    await pubGet(packageDir);

    // Find library files
    final libFiles = findLibraryFiles(packageDir);
    if (libFiles.isEmpty) {
      throw StateError('No library files found in package');
    }

    // Normalize the package directory path
    final normalizedPackageDir = p.normalize(packageDir);

    // Create analysis context with the package
    final collection = AnalysisContextCollection(
      includedPaths: [p.join(normalizedPackageDir, 'lib')],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );

    final libraries = <Map<String, dynamic>>[];
    final processedFiles = <String>{};

    for (final filePath in libFiles) {
      if (processedFiles.contains(filePath)) continue;
      processedFiles.add(filePath);

      try {
        final context = collection.contextFor(filePath);
        final result = await context.currentSession.getResolvedLibrary(
          filePath,
        );

        if (result is ResolvedLibraryResult) {
          final libraryJson = _extractLibrary(
            filePath,
            normalizedPackageDir,
            result,
          );
          if (libraryJson != null) {
            libraries.add(libraryJson);
          }
        }
      } catch (e) {
        // Skip files that can't be analyzed (e.g., part files)
        stderr.writeln('Warning: Could not analyze $filePath: $e');
      }
    }

    // Write output JSON
    final outputPath = p.join(packageDir, 'api_doc.json');
    final encoder = JsonEncoder.withIndent('  ');
    await File(outputPath).writeAsString(encoder.convert(libraries));

    return outputPath;
  }

  Map<String, dynamic>? _extractLibrary(
    String filePath,
    String packageDir,
    ResolvedLibraryResult result,
  ) {
    final library = result.element;
    final relativePath = p.relative(filePath, from: packageDir);

    final declarations = <Map<String, dynamic>>[];
    final directives = <Map<String, dynamic>>[];

    // Track processed elements to avoid duplicates
    final processedNames = <String>{};

    // Extract classes from library
    for (final cls in library.classes) {
      final name = cls.name;
      if (name == null || name.isEmpty || processedNames.contains(name)) {
        continue;
      }
      if (_isPrivate(name)) continue;
      final decl = _extractClass(cls);
      if (decl != null) {
        declarations.add(decl);
        processedNames.add(name);
      }
    }

    // Extract enums
    for (final e in library.enums) {
      final name = e.name;
      if (name == null || name.isEmpty || processedNames.contains(name)) {
        continue;
      }
      if (_isPrivate(name)) continue;
      final decl = _extractEnum(e);
      if (decl != null) {
        declarations.add(decl);
        processedNames.add(name);
      }
    }

    // Extract extensions
    for (final ext in library.extensions) {
      final name = ext.name ?? '';
      if (processedNames.contains(name)) continue;
      if (_isPrivate(name)) continue;
      final decl = _extractExtension(ext);
      if (decl != null) {
        declarations.add(decl);
        if (name.isNotEmpty) processedNames.add(name);
      }
    }

    // Extract top-level functions
    for (final func in library.topLevelFunctions) {
      final name = func.name;
      if (name == null || name.isEmpty || processedNames.contains(name)) {
        continue;
      }
      if (_isPrivate(name)) continue;
      final decl = _extractFunction(func);
      if (decl != null) {
        declarations.add(decl);
        processedNames.add(name);
      }
    }

    // Extract mixins
    for (final mixin in library.mixins) {
      final name = mixin.name;
      if (name == null || name.isEmpty || processedNames.contains(name)) {
        continue;
      }
      if (_isPrivate(name)) continue;
      final decl = _extractMixin(mixin);
      if (decl != null) {
        declarations.add(decl);
        processedNames.add(name);
      }
    }

    // Extract top-level variables
    for (final v in library.topLevelVariables) {
      final name = v.name;
      if (name == null || name.isEmpty || processedNames.contains(name)) {
        continue;
      }
      if (_isPrivate(name)) continue;
      final decl = _extractVariable(v);
      if (decl != null) {
        declarations.add(decl);
        processedNames.add(name);
      }
    }

    // Extract typedefs
    for (final td in library.typeAliases) {
      final name = td.name;
      if (name == null || name.isEmpty || processedNames.contains(name)) {
        continue;
      }
      if (_isPrivate(name)) continue;
      final decl = _extractTypedef(td);
      if (decl != null) {
        declarations.add(decl);
        processedNames.add(name);
      }
    }

    if (declarations.isEmpty && directives.isEmpty) return null;

    return {
      'source': relativePath,
      'directives': directives,
      'declarations': declarations,
    };
  }

  bool _isPrivate(String name) {
    if (name.isEmpty) return false;
    return name.startsWith('_');
  }

  Map<String, dynamic>? _extractClass(ClassElement element) {
    final name = element.name;
    if (name == null || name.isEmpty) return null;

    final json = <String, dynamic>{'kind': 'class', 'name': name};

    final desc = _getDescription(element);
    if (desc != null) json['description'] = desc;

    json['abstract'] = element.isAbstract;

    final supertype = element.supertype;
    if (supertype != null && supertype.element.name != 'Object') {
      json['extends'] = _typeString(supertype);
    }

    if (element.interfaces.isNotEmpty) {
      json['implements'] = element.interfaces.map(_typeString).toList();
    }

    if (element.mixins.isNotEmpty) {
      json['with'] = element.mixins.map(_typeString).toList();
    }

    if (element.typeParameters.isNotEmpty) {
      json['typeParameters'] =
          element.typeParameters.map((t) => t.name ?? '').toList();
    }

    json['constructors'] =
        element.constructors
            .where((c) => !_isPrivate(c.name ?? ''))
            .map((c) => _extractConstructor(c, name))
            .toList();

    json['methods'] = [
      ...element.methods
          .where((m) => !_isPrivate(m.name ?? ''))
          .map(_extractMethod),
      ...element.getters
          .where((g) => !_isPrivate(g.name ?? '') && !g.isSynthetic)
          .map(_extractGetter),
      ...element.setters
          .where((s) => !_isPrivate(s.name ?? '') && !s.isSynthetic)
          .map(_extractSetter),
    ];

    json['fields'] =
        element.fields
            .where((f) => !_isPrivate(f.name ?? '') && !f.isSynthetic)
            .map(_extractField)
            .toList();

    return json;
  }

  Map<String, dynamic> _extractConstructor(
    ConstructorElement element,
    String className,
  ) {
    final ctorName = element.name ?? '';
    final name = ctorName.isEmpty ? className : '$className.$ctorName';

    final json = <String, dynamic>{'name': name};

    final desc = _getDescription(element);
    if (desc != null) json['description'] = desc;

    json['const'] = element.isConst;
    json['factory'] = element.isFactory;
    json['parameters'] = _extractParameters(element.formalParameters);

    return json;
  }

  Map<String, dynamic> _extractMethod(MethodElement element) {
    final json = <String, dynamic>{'name': element.name ?? ''};

    final desc = _getDescription(element);
    if (desc != null) json['description'] = desc;

    json['returns'] = _typeString(element.returnType);
    json['static'] = element.isStatic;
    json['abstract'] = element.isAbstract;
    json['operator'] = element.isOperator;
    json['getter'] = false;
    json['setter'] = false;

    if (element.typeParameters.isNotEmpty) {
      json['typeParameters'] =
          element.typeParameters.map((t) => t.name ?? '').toList();
    }

    json['parameters'] = _extractParameters(element.formalParameters);

    return json;
  }

  Map<String, dynamic> _extractGetter(GetterElement element) {
    final json = <String, dynamic>{
      'name': (element.name ?? '').replaceAll('=', ''),
    };

    final desc = _getDescription(element);
    if (desc != null) json['description'] = desc;

    json['returns'] = _typeString(element.returnType);
    json['static'] = element.isStatic;
    json['abstract'] = element.isAbstract;
    json['operator'] = false;
    json['getter'] = true;
    json['setter'] = false;

    return json;
  }

  Map<String, dynamic> _extractSetter(SetterElement element) {
    final json = <String, dynamic>{
      'name': (element.name ?? '').replaceAll('=', ''),
    };

    final desc = _getDescription(element);
    if (desc != null) json['description'] = desc;

    json['returns'] = 'void';
    json['static'] = element.isStatic;
    json['abstract'] = element.isAbstract;
    json['operator'] = false;
    json['getter'] = false;
    json['setter'] = true;
    json['parameters'] = _extractParameters(element.formalParameters);

    return json;
  }

  Map<String, dynamic> _extractField(FieldElement element) {
    final json = <String, dynamic>{
      'name': element.name ?? '',
      'type': _typeString(element.type),
    };

    final desc = _getDescription(element);
    if (desc != null) json['description'] = desc;

    json['static'] = element.isStatic;
    json['final'] = element.isFinal;
    json['const'] = element.isConst;
    json['late'] = element.isLate;

    return json;
  }

  Map<String, dynamic>? _extractFunction(TopLevelFunctionElement element) {
    final name = element.name;
    if (name == null || name.isEmpty) return null;

    final json = <String, dynamic>{'kind': 'function', 'name': name};

    final desc = _getDescription(element);
    if (desc != null) json['description'] = desc;

    json['returns'] = _typeString(element.returnType);

    if (element.typeParameters.isNotEmpty) {
      json['typeParameters'] =
          element.typeParameters.map((t) => t.name ?? '').toList();
    }

    json['parameters'] = _extractParameters(element.formalParameters);

    return json;
  }

  Map<String, dynamic>? _extractEnum(EnumElement element) {
    final name = element.name;
    if (name == null || name.isEmpty) return null;

    final json = <String, dynamic>{'kind': 'enum', 'name': name};

    final desc = _getDescription(element);
    if (desc != null) json['description'] = desc;

    json['values'] =
        element.fields.where((f) => f.isEnumConstant).map((c) {
          final valueJson = <String, dynamic>{'name': c.name ?? ''};
          final valueDesc = _getDescription(c);
          if (valueDesc != null) valueJson['description'] = valueDesc;
          return valueJson;
        }).toList();

    json['methods'] = [
      ...element.methods
          .where((m) => !_isPrivate(m.name ?? ''))
          .map(_extractMethod),
      ...element.getters
          .where((g) => !_isPrivate(g.name ?? '') && !g.isSynthetic)
          .map(_extractGetter),
      ...element.setters
          .where((s) => !_isPrivate(s.name ?? '') && !s.isSynthetic)
          .map(_extractSetter),
    ];

    json['fields'] =
        element.fields
            .where(
              (f) =>
                  !_isPrivate(f.name ?? '') &&
                  !f.isSynthetic &&
                  !f.isEnumConstant,
            )
            .map(_extractField)
            .toList();

    return json;
  }

  Map<String, dynamic>? _extractVariable(TopLevelVariableElement element) {
    final name = element.name;
    if (name == null || name.isEmpty) return null;

    final json = <String, dynamic>{
      'kind': 'variable',
      'name': name,
      'type': _typeString(element.type),
    };

    final desc = _getDescription(element);
    if (desc != null) json['description'] = desc;

    json['const'] = element.isConst;
    json['final'] = element.isFinal;

    return json;
  }

  Map<String, dynamic>? _extractTypedef(TypeAliasElement element) {
    final name = element.name;
    if (name == null || name.isEmpty) return null;

    final json = <String, dynamic>{
      'kind': 'typedef',
      'name': name,
      'type': _typeString(element.aliasedType),
    };

    final desc = _getDescription(element);
    if (desc != null) json['description'] = desc;

    if (element.typeParameters.isNotEmpty) {
      json['typeParameters'] =
          element.typeParameters.map((t) => t.name ?? '').toList();
    }

    return json;
  }

  Map<String, dynamic>? _extractExtension(ExtensionElement element) {
    final name = element.name;

    final json = <String, dynamic>{'kind': 'extension', 'name': name ?? ''};

    final desc = _getDescription(element);
    if (desc != null) json['description'] = desc;

    json['on'] = _typeString(element.extendedType);

    json['methods'] = [
      ...element.methods
          .where((m) => !_isPrivate(m.name ?? ''))
          .map(_extractMethod),
      ...element.getters
          .where((g) => !_isPrivate(g.name ?? '') && !g.isSynthetic)
          .map(_extractGetter),
      ...element.setters
          .where((s) => !_isPrivate(s.name ?? '') && !s.isSynthetic)
          .map(_extractSetter),
    ];

    json['fields'] =
        element.fields
            .where((f) => !_isPrivate(f.name ?? '') && !f.isSynthetic)
            .map(_extractField)
            .toList();

    return json;
  }

  Map<String, dynamic>? _extractMixin(MixinElement element) {
    final name = element.name;
    if (name == null || name.isEmpty) return null;

    final json = <String, dynamic>{'kind': 'mixin', 'name': name};

    final desc = _getDescription(element);
    if (desc != null) json['description'] = desc;

    if (element.superclassConstraints.isNotEmpty) {
      json['on'] = element.superclassConstraints.map(_typeString).toList();
    }

    if (element.interfaces.isNotEmpty) {
      json['implements'] = element.interfaces.map(_typeString).toList();
    }

    json['methods'] = [
      ...element.methods
          .where((m) => !_isPrivate(m.name ?? ''))
          .map(_extractMethod),
      ...element.getters
          .where((g) => !_isPrivate(g.name ?? '') && !g.isSynthetic)
          .map(_extractGetter),
      ...element.setters
          .where((s) => !_isPrivate(s.name ?? '') && !s.isSynthetic)
          .map(_extractSetter),
    ];

    json['fields'] =
        element.fields
            .where((f) => !_isPrivate(f.name ?? '') && !f.isSynthetic)
            .map(_extractField)
            .toList();

    return json;
  }

  Map<String, dynamic> _extractParameters(
    List<FormalParameterElement> parameters,
  ) {
    final all = <Map<String, dynamic>>[];
    var positionalCount = 0;

    for (final param in parameters) {
      final paramJson = <String, dynamic>{
        'name': param.name ?? '',
        'type': _typeString(param.type),
      };

      if (param.isRequiredNamed) {
        paramJson['required'] = true;
      }

      if (param.hasDefaultValue && param.defaultValueCode != null) {
        paramJson['default'] = param.defaultValueCode;
      }

      all.add(paramJson);

      if (param.isPositional) positionalCount++;
    }

    return {
      'all': all,
      'positional': positionalCount,
      'named': parameters.length - positionalCount,
    };
  }

  String _typeString(DartType type) {
    return type.getDisplayString();
  }

  String? _getDescription(Element element) {
    final comment = element.documentationComment;
    if (comment == null || comment.isEmpty) return null;

    // Strip comment markers (/// or /** */)
    return comment
        .split('\n')
        .map((line) {
          line = line.trim();
          if (line.startsWith('///')) {
            return line.substring(3).trim();
          } else if (line.startsWith('*')) {
            return line.substring(1).trim();
          } else if (line.startsWith('/**') || line.startsWith('*/')) {
            return '';
          }
          return line;
        })
        .where((line) => line.isNotEmpty)
        .join('\n');
  }
}
