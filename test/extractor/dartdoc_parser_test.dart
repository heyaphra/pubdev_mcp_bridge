/// Tests for [DartdocParser] JSON documentation parsing.
///
/// Tests parse analyzer-formatted JSON output and convert it to [PackageDoc]
/// models. Covers all Dart declaration types: classes, functions, enums,
/// variables, typedefs, extensions, and mixins. Also tests parameter parsing,
/// type parameter handling, and error conditions.
///
/// Test isolation: Creates temporary JSON files per test with in-memory data.
/// No dependency on external files or network.
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:pubdev_mcp_bridge/src/extractor/dartdoc_parser.dart';
import 'package:pubdev_mcp_bridge/src/extractor/extraction_exception.dart';

void main() {
  late Directory tempDir;
  late DartdocParser parser;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('parser_test_');
    parser = DartdocParser();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Creates a temporary JSON file containing analyzer output.
  ///
  /// The JSON format matches the output from DartMetadataExtractor's
  /// analyzer-based extraction process.
  ///
  /// Parameters:
  ///   - [libraries]: List of library maps with 'source' and 'declarations' keys
  ///
  /// Returns the absolute path to the created JSON file.
  ///
  /// Example:
  /// ```dart
  /// final jsonPath = await createAnalyzerJson([
  ///   {
  ///     'source': 'lib/main.dart',
  ///     'declarations': [
  ///       {'kind': 'class', 'name': 'MyClass'},
  ///     ],
  ///   },
  /// ]);
  /// ```
  Future<String> createAnalyzerJson(
    List<Map<String, dynamic>> libraries,
  ) async {
    final jsonPath = '${tempDir.path}/analyzer_output.json';
    await File(jsonPath).writeAsString(jsonEncode(libraries));
    return jsonPath;
  }

  group('DartdocParser - Basic Parsing', () {
    test('parses empty library list', () async {
      final jsonPath = await createAnalyzerJson([]);
      final doc = await parser.parse(jsonPath, 'test_pkg', '1.0.0');

      expect(doc.name, equals('test_pkg'));
      expect(doc.version, equals('1.0.0'));
      expect(doc.libraries, isEmpty);
    });

    test('throws ExtractionException when JSON file not found', () async {
      expect(
        () => parser.parse(
          '${tempDir.path}/nonexistent.json',
          'test_pkg',
          '1.0.0',
        ),
        throwsA(
          isA<ExtractionException>().having(
            (e) => e.message,
            'message',
            contains('JSON file not found'),
          ),
        ),
      );
    });

    test('parses single library with no declarations', () async {
      final jsonPath = await createAnalyzerJson([
        {'source': 'lib/main.dart', 'declarations': []},
      ]);

      final doc = await parser.parse(jsonPath, 'test_pkg', '1.0.0');

      expect(doc.libraries, hasLength(1));
      expect(doc.libraries.first.name, equals('main'));
      expect(doc.libraries.first.classes, isEmpty);
    });

    test('skips library without source', () async {
      final jsonPath = await createAnalyzerJson([
        {'declarations': []},
      ]);

      final doc = await parser.parse(jsonPath, 'test_pkg', '1.0.0');

      expect(doc.libraries, isEmpty);
    });
  });

  group('DartdocParser - Class Parsing', () {
    test('parses simple class', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/models.dart',
          'declarations': [
            {'kind': 'class', 'name': 'User', 'description': 'A user model'},
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final cls = doc.libraries.first.classes.first;

      expect(cls.name, equals('User'));
      expect(cls.description, equals('A user model'));
      expect(cls.isAbstract, isFalse);
    });

    test('parses abstract class', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/base.dart',
          'declarations': [
            {'kind': 'class', 'name': 'BaseClass', 'abstract': true},
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final cls = doc.libraries.first.classes.first;

      expect(cls.isAbstract, isTrue);
    });

    test('parses class with inheritance', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/models.dart',
          'declarations': [
            {
              'kind': 'class',
              'name': 'AdminUser',
              'extends': 'User',
              'implements': ['Serializable', 'Comparable'],
              'with': ['LoggableMixin'],
            },
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final cls = doc.libraries.first.classes.first;

      expect(cls.superclass, equals('User'));
      expect(cls.interfaces, equals(['Serializable', 'Comparable']));
      expect(cls.mixins, equals(['LoggableMixin']));
    });

    test('parses class with type parameters', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/core.dart',
          'declarations': [
            {
              'kind': 'class',
              'name': 'Result',
              'typeParameters': ['T', 'E'],
            },
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final cls = doc.libraries.first.classes.first;

      expect(cls.typeParameters, equals(['T', 'E']));
    });

    test('parses class with constructors', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/models.dart',
          'declarations': [
            {
              'kind': 'class',
              'name': 'Point',
              'constructors': [
                {
                  'name': '',
                  'description': 'Default constructor',
                  'parameters': [],
                },
                {'name': 'fromJson', 'factory': true, 'parameters': []},
                {'name': 'zero', 'const': true, 'parameters': []},
              ],
            },
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final cls = doc.libraries.first.classes.first;

      expect(cls.constructors, hasLength(3));
      expect(cls.constructors[0].name, equals(''));
      expect(cls.constructors[0].description, equals('Default constructor'));
      expect(cls.constructors[1].name, equals('fromJson'));
      expect(cls.constructors[1].isFactory, isTrue);
      expect(cls.constructors[2].name, equals('zero'));
      expect(cls.constructors[2].isConst, isTrue);
    });

    test('parses class with methods', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/models.dart',
          'declarations': [
            {
              'kind': 'class',
              'name': 'Calculator',
              'methods': [
                {'name': 'add', 'returns': 'int', 'parameters': []},
                {
                  'name': 'create',
                  'static': true,
                  'returns': 'Calculator',
                  'parameters': [],
                },
                {'name': 'value', 'getter': true, 'returns': 'int'},
                {
                  'name': 'value',
                  'setter': true,
                  'returns': 'void',
                  'parameters': [],
                },
              ],
            },
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final cls = doc.libraries.first.classes.first;

      expect(cls.methods, hasLength(4));
      expect(cls.methods[0].name, equals('add'));
      expect(cls.methods[0].returnType, equals('int'));
      expect(cls.methods[1].isStatic, isTrue);
      expect(cls.methods[2].isGetter, isTrue);
      expect(cls.methods[3].isSetter, isTrue);
    });

    test('parses class with fields', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/models.dart',
          'declarations': [
            {
              'kind': 'class',
              'name': 'Config',
              'fields': [
                {'name': 'name', 'type': 'String', 'final': true},
                {
                  'name': 'version',
                  'type': 'String',
                  'static': true,
                  'const': true,
                },
                {'name': 'data', 'type': 'Map<String, dynamic>', 'late': true},
              ],
            },
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final cls = doc.libraries.first.classes.first;

      expect(cls.fields, hasLength(3));
      expect(cls.fields[0].name, equals('name'));
      expect(cls.fields[0].isFinal, isTrue);
      expect(cls.fields[1].isStatic, isTrue);
      expect(cls.fields[1].isConst, isTrue);
      expect(cls.fields[2].isLate, isTrue);
    });
  });

  group('DartdocParser - Function Parsing', () {
    test('parses top-level function', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/utils.dart',
          'declarations': [
            {
              'kind': 'function',
              'name': 'formatDate',
              'description': 'Formats a date',
              'returns': 'String',
              'parameters': [],
            },
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final func = doc.libraries.first.functions.first;

      expect(func.name, equals('formatDate'));
      expect(func.description, equals('Formats a date'));
      expect(func.returnType, equals('String'));
    });

    test('parses function with type parameters', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/utils.dart',
          'declarations': [
            {
              'kind': 'function',
              'name': 'identity',
              'returns': 'T',
              'typeParameters': ['T'],
              'parameters': [],
            },
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final func = doc.libraries.first.functions.first;

      expect(func.typeParameters, equals(['T']));
    });

    test('defaults return type to dynamic when not specified', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/utils.dart',
          'declarations': [
            {'kind': 'function', 'name': 'doSomething', 'parameters': []},
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final func = doc.libraries.first.functions.first;

      expect(func.returnType, equals('dynamic'));
    });
  });

  group('DartdocParser - Enum Parsing', () {
    test('parses simple enum with string values', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/enums.dart',
          'declarations': [
            {
              'kind': 'enum',
              'name': 'Status',
              'values': ['pending', 'active', 'completed'],
            },
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final enumDoc = doc.libraries.first.enums.first;

      expect(enumDoc.name, equals('Status'));
      expect(enumDoc.values, hasLength(3));
      expect(enumDoc.values[0].name, equals('pending'));
      expect(enumDoc.values[1].name, equals('active'));
      expect(enumDoc.values[2].name, equals('completed'));
    });

    test('parses enum with documented values', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/enums.dart',
          'declarations': [
            {
              'kind': 'enum',
              'name': 'Priority',
              'description': 'Priority levels',
              'values': [
                {'name': 'high', 'description': 'High priority'},
                {'name': 'low', 'description': 'Low priority'},
              ],
            },
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final enumDoc = doc.libraries.first.enums.first;

      expect(enumDoc.description, equals('Priority levels'));
      expect(enumDoc.values[0].description, equals('High priority'));
      expect(enumDoc.values[1].description, equals('Low priority'));
    });
  });

  group('DartdocParser - Variable Parsing', () {
    test('parses top-level variable', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/constants.dart',
          'declarations': [
            {
              'kind': 'variable',
              'name': 'version',
              'type': 'String',
              'final': true,
            },
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final variable = doc.libraries.first.variables.first;

      expect(variable.name, equals('version'));
      expect(variable.type, equals('String'));
      expect(variable.isFinal, isTrue);
    });

    test('parses const variable', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/constants.dart',
          'declarations': [
            {
              'kind': 'variable',
              'name': 'maxValue',
              'type': 'int',
              'const': true,
            },
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final variable = doc.libraries.first.variables.first;

      expect(variable.isConst, isTrue);
    });
  });

  group('DartdocParser - Typedef Parsing', () {
    test('parses typedef', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/types.dart',
          'declarations': [
            {
              'kind': 'typedef',
              'name': 'IntCallback',
              'type': 'void Function(int)',
            },
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final typedef = doc.libraries.first.typedefs.first;

      expect(typedef.name, equals('IntCallback'));
      expect(typedef.type, equals('void Function(int)'));
    });

    test('parses typedef with type parameters', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/types.dart',
          'declarations': [
            {
              'kind': 'typedef',
              'name': 'Mapper',
              'type': 'R Function(T)',
              'typeParameters': ['T', 'R'],
            },
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final typedef = doc.libraries.first.typedefs.first;

      expect(typedef.typeParameters, equals(['T', 'R']));
    });
  });

  group('DartdocParser - Extension Parsing', () {
    test('parses extension', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/extensions.dart',
          'declarations': [
            {'kind': 'extension', 'name': 'StringExtensions', 'on': 'String'},
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final ext = doc.libraries.first.extensions.first;

      expect(ext.name, equals('StringExtensions'));
      expect(ext.onType, equals('String'));
    });
  });

  group('DartdocParser - Mixin Parsing', () {
    test('parses mixin', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/mixins.dart',
          'declarations': [
            {'kind': 'mixin', 'name': 'Loggable'},
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final mixin = doc.libraries.first.mixins.first;

      expect(mixin.name, equals('Loggable'));
    });
  });

  group('DartdocParser - Parameter Parsing', () {
    test('parses positional parameters', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/utils.dart',
          'declarations': [
            {
              'kind': 'function',
              'name': 'add',
              'returns': 'int',
              'parameters': [
                {'name': 'a', 'type': 'int', 'required': true},
                {'name': 'b', 'type': 'int', 'required': true},
              ],
            },
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final func = doc.libraries.first.functions.first;

      expect(func.parameters, hasLength(2));
      expect(func.parameters[0].name, equals('a'));
      expect(func.parameters[0].type, equals('int'));
      expect(func.parameters[0].isRequired, isTrue);
    });

    test('parses named parameters', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/utils.dart',
          'declarations': [
            {
              'kind': 'function',
              'name': 'greet',
              'returns': 'void',
              'parameters': [
                {
                  'name': 'name',
                  'type': 'String',
                  'named': true,
                  'required': true,
                },
                {
                  'name': 'greeting',
                  'type': 'String',
                  'named': true,
                  'required': false,
                  'default': 'Hello',
                },
              ],
            },
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final func = doc.libraries.first.functions.first;

      expect(func.parameters[0].isNamed, isTrue);
      expect(func.parameters[0].isRequired, isTrue);
      expect(func.parameters[1].defaultValue, equals('Hello'));
    });

    test('parses parameters with complex format', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/utils.dart',
          'declarations': [
            {
              'kind': 'function',
              'name': 'process',
              'returns': 'void',
              'parameters': {
                'all': [
                  {'name': 'data', 'type': 'String'},
                  {'name': 'options', 'type': 'Map'},
                ],
                'positional': 1,
              },
            },
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final func = doc.libraries.first.functions.first;

      expect(func.parameters, hasLength(2));
      expect(func.parameters[0].isPositional, isTrue);
      expect(func.parameters[1].isNamed, isTrue);
    });
  });

  group('DartdocParser - Multiple Libraries', () {
    test('parses package with multiple libraries', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/core.dart',
          'declarations': [
            {'kind': 'class', 'name': 'CoreClass'},
          ],
        },
        {
          'source': 'lib/utils.dart',
          'declarations': [
            {'kind': 'function', 'name': 'utilFunction', 'returns': 'void'},
          ],
        },
        {
          'source': 'lib/models.dart',
          'declarations': [
            {'kind': 'class', 'name': 'Model'},
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');

      expect(doc.libraries, hasLength(3));
      expect(doc.libraries[0].name, equals('core'));
      expect(doc.libraries[1].name, equals('utils'));
      expect(doc.libraries[2].name, equals('models'));
    });

    test('handles mixed declaration types in single library', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/main.dart',
          'declarations': [
            {'kind': 'class', 'name': 'MyClass'},
            {'kind': 'function', 'name': 'myFunction', 'returns': 'void'},
            {
              'kind': 'enum',
              'name': 'MyEnum',
              'values': ['a', 'b'],
            },
            {'kind': 'variable', 'name': 'myVar', 'type': 'String'},
            {'kind': 'typedef', 'name': 'MyTypedef', 'type': 'void Function()'},
            {'kind': 'extension', 'name': 'MyExt', 'on': 'String'},
            {'kind': 'mixin', 'name': 'MyMixin'},
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final lib = doc.libraries.first;

      expect(lib.classes, hasLength(1));
      expect(lib.functions, hasLength(1));
      expect(lib.enums, hasLength(1));
      expect(lib.variables, hasLength(1));
      expect(lib.typedefs, hasLength(1));
      expect(lib.extensions, hasLength(1));
      expect(lib.mixins, hasLength(1));
    });
  });

  group('DartdocParser - Edge Cases', () {
    test('handles malformed JSON gracefully', () async {
      final jsonPath = '${tempDir.path}/invalid.json';
      await File(jsonPath).writeAsString('not valid json');

      expect(
        () => parser.parse(jsonPath, 'pkg', '1.0.0'),
        throwsA(isA<FormatException>()),
      );
    });

    test('handles missing optional fields', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/minimal.dart',
          'declarations': [
            {
              'kind': 'class',
              'name': 'MinimalClass',
              // No description, constructors, methods, etc.
            },
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final cls = doc.libraries.first.classes.first;

      expect(cls.name, equals('MinimalClass'));
      expect(cls.description, isNull);
      expect(cls.constructors, isEmpty);
      expect(cls.methods, isEmpty);
      expect(cls.fields, isEmpty);
    });

    test('ignores unknown declaration kinds', () async {
      final jsonPath = await createAnalyzerJson([
        {
          'source': 'lib/test.dart',
          'declarations': [
            {'kind': 'class', 'name': 'KnownClass'},
            {'kind': 'unknown_kind', 'name': 'ShouldBeIgnored'},
            {'kind': 'function', 'name': 'knownFunction', 'returns': 'void'},
          ],
        },
      ]);

      final doc = await parser.parse(jsonPath, 'pkg', '1.0.0');
      final lib = doc.libraries.first;

      expect(lib.classes, hasLength(1));
      expect(lib.functions, hasLength(1));
    });
  });

  group('DartdocParser - Integration with Fixture', () {
    test('can parse analyzer-formatted fixture data', () async {
      // Create analyzer-formatted JSON inline
      final analyzerJson = [
        {
          'source': 'lib/test_package.dart',
          'declarations': [
            {
              'kind': 'class',
              'name': 'Calculator',
              'description': 'A simple calculator class',
              'constructors': [
                {'name': '', 'description': 'Creates a new Calculator'},
              ],
              'methods': [
                {
                  'name': 'add',
                  'returns': 'int',
                  'parameters': [
                    {'name': 'a', 'type': 'int'},
                    {'name': 'b', 'type': 'int'},
                  ],
                },
              ],
              'fields': [
                {'name': 'version', 'type': 'String', 'static': true},
              ],
            },
            {'kind': 'function', 'name': 'greet', 'returns': 'String'},
            {
              'kind': 'enum',
              'name': 'Status',
              'values': ['pending', 'completed'],
            },
          ],
        },
      ];

      final jsonPath = await createAnalyzerJson(analyzerJson);
      final doc = await parser.parse(jsonPath, 'test_package', '1.0.0');

      expect(doc.libraries, isNotEmpty);
      expect(doc.libraries.first.classes, hasLength(1));
      expect(doc.libraries.first.functions, hasLength(1));
      expect(doc.libraries.first.enums, hasLength(1));

      final cls = doc.libraries.first.classes.first;
      expect(cls.name, equals('Calculator'));
      expect(cls.constructors, hasLength(1));
      expect(cls.methods, hasLength(1));
      expect(cls.fields, hasLength(1));
    });
  });
}
