/// Tests for [DartMetadataExtractor] using package:analyzer.
///
/// Tests the core extraction logic that replaces dartdoc_json with direct
/// analyzer access. Covers workspace resolution stripping, library file
/// discovery, element extraction (classes, functions, enums, etc.),
/// documentation parsing, and error handling.
///
/// Test isolation: Creates temporary Dart packages in isolated directories
/// with real pubspec.yaml and Dart source files. Tests run against actual
/// package:analyzer to ensure compatibility with experimental features.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:pubdev_mcp_bridge/src/extractor/dart_metadata_extractor.dart';
import 'package:pubdev_mcp_bridge/src/extractor/extraction_exception.dart';

import '../test_utils.dart';

void main() {
  late Directory tempDir;
  late DartMetadataExtractor extractor;

  setUp(() async {
    tempDir = await createTempTestDir('dart_extractor_test_');
    extractor = DartMetadataExtractor();
  });

  group('DartMetadataExtractor', () {
    group('isAvailable', () {
      test('returns true since analyzer is a dependency', () async {
        expect(await extractor.isAvailable(), isTrue);
      });
    });

    group('workspace resolution stripping', () {
      test('removes resolution: workspace from pubspec.yaml', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          pubspecContent: '''
name: test_pkg
version: 1.0.0
environment:
  sdk: ^3.0.0

resolution: workspace

dependencies:
  path: ^1.9.0
''',
        );

        await extractor.pubGet(packageDir);

        final pubspecFile = File(p.join(packageDir, 'pubspec.yaml'));
        final content = await pubspecFile.readAsString();
        expect(content, isNot(contains('resolution: workspace')));
        expect(content, contains('name: test_pkg'));
        expect(content, contains('path: ^1.9.0'));
      });

      test(
        'removes resolution: workspace from nested pubspec.yaml files',
        () async {
          final packageDir = await _createTestPackage(
            tempDir,
            name: 'test_pkg',
            pubspecContent: '''
name: test_pkg
version: 1.0.0
environment:
  sdk: ^3.0.0
resolution: workspace
''',
          );

          // Create nested package
          final nestedDir = Directory(p.join(packageDir, 'packages', 'nested'));
          await nestedDir.create(recursive: true);
          final nestedPubspec = File(p.join(nestedDir.path, 'pubspec.yaml'));
          await nestedPubspec.writeAsString('''
name: nested_pkg
version: 1.0.0
environment:
  sdk: ^3.0.0
resolution: workspace
''');

          await extractor.pubGet(packageDir);

          // Check both pubspec files
          final rootContent =
              await File(p.join(packageDir, 'pubspec.yaml')).readAsString();
          final nestedContent = await nestedPubspec.readAsString();

          expect(rootContent, isNot(contains('resolution: workspace')));
          expect(nestedContent, isNot(contains('resolution: workspace')));
        },
      );

      test('preserves pubspec.yaml without workspace resolution', () async {
        final originalContent = '''
name: test_pkg
version: 1.0.0
environment:
  sdk: ^3.0.0

dependencies:
  path: ^1.9.0
''';

        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          pubspecContent: originalContent,
        );

        await extractor.pubGet(packageDir);

        final content =
            await File(p.join(packageDir, 'pubspec.yaml')).readAsString();
        expect(content, equals(originalContent));
      });

      test('handles missing package directory gracefully', () async {
        final nonExistentDir = p.join(tempDir.path, 'does_not_exist');
        // Should throw ProcessException since directory doesn't exist
        expect(
          () => extractor.pubGet(nonExistentDir),
          throwsA(isA<ProcessException>()),
        );
      });

      test('handles malformed pubspec.yaml gracefully', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          pubspecContent: 'not: valid: yaml: content:',
        );

        // pubGet will fail, but should throw ExtractionException
        expect(
          () => extractor.pubGet(packageDir),
          throwsA(isA<ExtractionException>()),
        );
      });
    });

    group('pubGet', () {
      test('runs dart pub get successfully', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          pubspecContent: '''
name: test_pkg
version: 1.0.0
environment:
  sdk: ^3.0.0
''',
        );

        await extractor.pubGet(packageDir);

        // Verify .dart_tool directory was created
        expect(
          Directory(p.join(packageDir, '.dart_tool')).existsSync(),
          isTrue,
        );
      });

      test('throws ExtractionException on dart pub get failure', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          pubspecContent: '''
name: test_pkg
version: 1.0.0
dependencies:
  nonexistent_package_12345: ^999.0.0
''',
        );

        expect(
          () => extractor.pubGet(packageDir),
          throwsA(
            isA<ExtractionException>().having(
              (e) => e.message,
              'message',
              'dart pub get failed',
            ),
          ),
        );
      });
    });

    group('findLibraryFiles', () {
      test('finds all .dart files in lib/', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '// main',
            'utils.dart': '// utils',
            'models/user.dart': '// user',
          },
        );

        final files = extractor.findLibraryFiles(packageDir);

        expect(files, hasLength(3));
        expect(files.any((f) => f.endsWith('main.dart')), isTrue);
        expect(files.any((f) => f.endsWith('utils.dart')), isTrue);
        expect(files.any((f) => f.endsWith('user.dart')), isTrue);
      });

      test('returns empty list for missing lib/ directory', () async {
        final packageDir = tempDir.path;
        final files = extractor.findLibraryFiles(packageDir);
        expect(files, isEmpty);
      });

      test('ignores non-.dart files', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '// main',
            'README.md': '# Readme',
            'data.json': '{}',
          },
        );

        final files = extractor.findLibraryFiles(packageDir);

        expect(files, hasLength(1));
        expect(files.first.endsWith('main.dart'), isTrue);
      });

      test('handles nested directory structures', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'a.dart': '// a',
            'dir1/b.dart': '// b',
            'dir1/dir2/c.dart': '// c',
            'dir1/dir2/dir3/d.dart': '// d',
          },
        );

        final files = extractor.findLibraryFiles(packageDir);

        expect(files, hasLength(4));
      });
    });

    group('element extraction - classes', () {
      test('extracts basic class', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
/// A calculator class.
class Calculator {
  /// Adds two numbers.
  int add(int a, int b) => a + b;
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        expect(classes, hasLength(1));

        final calc = classes.first;
        expect(calc['name'], equals('Calculator'));
        expect(calc['description'], contains('calculator class'));
        expect(calc['abstract'], isFalse);
      });

      test('extracts abstract class', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
abstract class Shape {
  double area();
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        expect(classes.first['abstract'], isTrue);
      });

      test('extracts class with type parameters', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
class Box<T> {
  T value;
  Box(this.value);
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        expect(classes.first['typeParameters'], equals(['T']));
      });

      test('extracts class inheritance (extends)', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
class Animal {}
class Dog extends Animal {}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final dog = classes.firstWhere((c) => c['name'] == 'Dog');
        expect(dog['extends'], contains('Animal'));
      });

      test('extracts class with interfaces', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
abstract class Flyable {}
abstract class Swimmable {}
class Duck implements Flyable, Swimmable {}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final duck = classes.firstWhere((c) => c['name'] == 'Duck');
        expect(duck['implements'], hasLength(2));
      });

      test('extracts class with mixins', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
mixin Swimmer {}
mixin Flyer {}
class Duck with Swimmer, Flyer {}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final duck = classes.firstWhere((c) => c['name'] == 'Duck');
        expect(duck['with'], hasLength(2));
      });

      test('filters private classes', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
class PublicClass {}
class _PrivateClass {}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        expect(classes, hasLength(1));
        expect(classes.first['name'], equals('PublicClass'));
      });
    });

    group('element extraction - constructors', () {
      test('extracts default constructor', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
class Point {
  final int x, y;
  Point(this.x, this.y);
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final ctors = classes.first['constructors'] as List;
        expect(ctors, hasLength(1));
        // Dart 3 uses 'ClassName.new' for default constructors
        expect(
          ctors.first['name'],
          anyOf(equals('Point'), equals('Point.new')),
        );
      });

      test('extracts named constructor', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
class Point {
  final int x, y;
  Point(this.x, this.y);
  Point.origin() : x = 0, y = 0;
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final ctors = classes.first['constructors'] as List;
        expect(ctors, hasLength(2));
        expect(ctors.any((c) => c['name'] == 'Point.origin'), isTrue);
      });

      test('extracts const constructor', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
class Point {
  final int x, y;
  const Point(this.x, this.y);
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final ctors = classes.first['constructors'] as List;
        expect(ctors.first['const'], isTrue);
      });

      test('extracts factory constructor', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
class Logger {
  static final _instance = Logger._internal();
  Logger._internal();
  factory Logger() => _instance;
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final ctors = classes.first['constructors'] as List;
        final factoryCtor = ctors.firstWhere((c) => c['factory'] == true);
        // Dart 3 uses 'ClassName.new' for default constructors
        expect(
          factoryCtor['name'],
          anyOf(equals('Logger'), equals('Logger.new')),
        );
      });
    });

    group('element extraction - methods', () {
      test('extracts instance methods', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
class Calculator {
  /// Adds two numbers.
  int add(int a, int b) => a + b;
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final methods = classes.first['methods'] as List;
        final add = methods.firstWhere((m) => m['name'] == 'add');
        expect(add['description'], contains('Adds two numbers'));
        expect(add['returns'], contains('int'));
        expect(add['static'], isFalse);
      });

      test('extracts static methods', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
class Math {
  static int square(int x) => x * x;
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final methods = classes.first['methods'] as List;
        expect(methods.first['static'], isTrue);
      });

      test('extracts abstract methods', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
abstract class Shape {
  double area();
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final methods = classes.first['methods'] as List;
        expect(methods.first['abstract'], isTrue);
      });

      test('extracts getters', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
class Person {
  String _name = '';
  String get name => _name;
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final methods = classes.first['methods'] as List;
        final getter = methods.firstWhere((m) => m['name'] == 'name');
        expect(getter['getter'], isTrue);
        expect(getter['setter'], isFalse);
      });

      test('extracts setters', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
class Person {
  String _name = '';
  set name(String value) => _name = value;
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final methods = classes.first['methods'] as List;
        final setter = methods.firstWhere((m) => m['name'] == 'name');
        expect(setter['setter'], isTrue);
        expect(setter['getter'], isFalse);
      });

      test('extracts operator methods', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
class Point {
  final int x, y;
  Point(this.x, this.y);
  Point operator +(Point other) => Point(x + other.x, y + other.y);
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final methods = classes.first['methods'] as List;
        final operator = methods.firstWhere((m) => m['operator'] == true);
        expect(operator['name'], equals('+'));
      });
    });

    group('element extraction - fields', () {
      test('extracts instance fields', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
class Point {
  int x = 0;
  int y = 0;
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final fields = classes.first['fields'] as List;
        expect(fields, hasLength(2));
        expect(fields.any((f) => f['name'] == 'x'), isTrue);
        expect(fields.any((f) => f['name'] == 'y'), isTrue);
      });

      test('extracts final fields', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
class Point {
  final int x;
  final int y;
  Point(this.x, this.y);
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final fields = classes.first['fields'] as List;
        expect(fields.every((f) => f['final'] == true), isTrue);
      });

      test('extracts static fields', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
class Config {
  static const String version = '1.0.0';
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final fields = classes.first['fields'] as List;
        expect(fields.first['static'], isTrue);
        expect(fields.first['const'], isTrue);
      });

      test('extracts late fields', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
class Config {
  late String value;
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final fields = classes.first['fields'] as List;
        expect(fields.first['late'], isTrue);
      });

      test('filters synthetic fields (from getters/setters)', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
class Person {
  String get name => 'John';
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        final fields = classes.first['fields'] as List;
        // Synthetic field created by getter should be filtered
        expect(fields.where((f) => f['name'] == 'name'), isEmpty);
      });
    });

    group('element extraction - functions', () {
      test('extracts top-level functions', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
/// Prints a greeting.
void greet(String name) {
  print('Hello, \$name!');
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final functions = _findDeclarations(json, 'function');
        expect(functions, hasLength(1));
        expect(functions.first['name'], equals('greet'));
        expect(functions.first['description'], contains('greeting'));
      });

      test('extracts function with type parameters', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
T identity<T>(T value) => value;
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final functions = _findDeclarations(json, 'function');
        expect(functions.first['typeParameters'], equals(['T']));
      });

      test('filters private functions', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
void publicFunction() {}
void _privateFunction() {}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final functions = _findDeclarations(json, 'function');
        expect(functions, hasLength(1));
        expect(functions.first['name'], equals('publicFunction'));
      });
    });

    group('element extraction - enums', () {
      test('extracts basic enum', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
/// Primary colors.
enum Color { red, green, blue }
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final enums = _findDeclarations(json, 'enum');
        expect(enums, hasLength(1));
        expect(enums.first['name'], equals('Color'));
        expect(enums.first['description'], contains('Primary colors'));
      });

      test('extracts enum values', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
enum Color {
  /// Red color.
  red,
  /// Green color.
  green,
  /// Blue color.
  blue
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final enums = _findDeclarations(json, 'enum');
        final values = enums.first['values'] as List;
        expect(values, hasLength(3));
        expect(values.any((v) => v['name'] == 'red'), isTrue);
        expect(values.any((v) => v['name'] == 'green'), isTrue);
        expect(values.any((v) => v['name'] == 'blue'), isTrue);
      });

      test('extracts enhanced enum with methods', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
enum Color {
  red, green, blue;

  bool get isPrimary => true;
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final enums = _findDeclarations(json, 'enum');
        final methods = enums.first['methods'] as List;
        expect(methods.any((m) => m['name'] == 'isPrimary'), isTrue);
      });
    });

    group('element extraction - other types', () {
      test('extracts typedefs', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
/// A comparison function.
typedef Comparator<T> = int Function(T a, T b);
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final typedefs = _findDeclarations(json, 'typedef');
        expect(typedefs, hasLength(1));
        expect(typedefs.first['name'], equals('Comparator'));
        expect(typedefs.first['description'], contains('comparison'));
      });

      test('extracts extensions', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
extension StringExtension on String {
  bool get isBlank => trim().isEmpty;
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final extensions = _findDeclarations(json, 'extension');
        expect(extensions, hasLength(1));
        expect(extensions.first['name'], equals('StringExtension'));
        expect(extensions.first['on'], contains('String'));
      });

      test('extracts mixins', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
mixin Swimmer {
  void swim() {}
}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final mixins = _findDeclarations(json, 'mixin');
        expect(mixins, hasLength(1));
        expect(mixins.first['name'], equals('Swimmer'));
      });

      test('extracts top-level variables', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
/// The version number.
const String version = '1.0.0';
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final variables = _findDeclarations(json, 'variable');
        expect(variables, hasLength(1));
        expect(variables.first['name'], equals('version'));
        expect(variables.first['const'], isTrue);
      });
    });

    group('documentation extraction', () {
      test('extracts /// style comments', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
/// This is a class.
/// It does something useful.
class MyClass {}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        expect(classes.first['description'], contains('This is a class'));
        expect(classes.first['description'], contains('useful'));
      });

      test('extracts /** */ style comments', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
/**
 * This is a class.
 * It does something useful.
 */
class MyClass {}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        expect(classes.first['description'], contains('This is a class'));
      });

      test('handles missing documentation', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {'main.dart': 'class MyClass {}'},
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final classes = _findDeclarations(json, 'class');
        expect(classes.first['description'], isNull);
      });
    });

    group('parameter extraction', () {
      test('extracts positional parameters', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
void greet(String name, int age) {}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final functions = _findDeclarations(json, 'function');
        final params = functions.first['parameters'] as Map;
        expect(params['positional'], equals(2));
        expect(params['named'], equals(0));
        expect((params['all'] as List).length, equals(2));
      });

      test('extracts named parameters', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
void greet({String? name, int? age}) {}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final functions = _findDeclarations(json, 'function');
        final params = functions.first['parameters'] as Map;
        expect(params['positional'], equals(0));
        expect(params['named'], equals(2));
      });

      test('extracts required named parameters', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
void greet({required String name}) {}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final functions = _findDeclarations(json, 'function');
        final params = functions.first['parameters'] as Map;
        final allParams = params['all'] as List;
        expect(allParams.first['required'], isTrue);
      });

      test('extracts default parameter values', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
void greet({String name = 'World'}) {}
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        final functions = _findDeclarations(json, 'function');
        final params = functions.first['parameters'] as Map;
        final allParams = params['all'] as List;
        expect(allParams.first['default'], contains('World'));
      });
    });

    group('error handling', () {
      test('throws ExtractionException when no library files found', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          createLibDir: false,
        );

        expect(
          () => extractor.run(packageDir),
          throwsA(
            isA<ExtractionException>().having(
              (e) => e.message,
              'message',
              contains('No library files found'),
            ),
          ),
        );
      });

      test('handles unparseable Dart files gracefully', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {'main.dart': 'class { invalid dart syntax'},
        );

        // Should complete without throwing, but might skip the invalid file
        final jsonPath = await extractor.run(packageDir);
        expect(File(jsonPath).existsSync(), isTrue);
      });

      test('skips part files gracefully', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
part 'part.dart';
class MainClass {}
''',
            'part.dart': '''
part of 'main.dart';
class PartClass {}
''',
          },
        );

        // Should complete - part files are skipped during iteration
        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);
        // Should have extracted from main.dart
        expect(json, isNotEmpty);
      });
    });

    group('analysis_options.yaml creation', () {
      test(
        'creates analysis_options.yaml with experimental features',
        () async {
          final packageDir = await _createTestPackage(
            tempDir,
            name: 'test_pkg',
            libFiles: {'main.dart': 'void main() {}'},
          );

          await extractor.run(packageDir);

          final optionsFile = File(p.join(packageDir, 'analysis_options.yaml'));
          expect(optionsFile.existsSync(), isTrue);

          final content = await optionsFile.readAsString();
          expect(content, contains('enable-experiment'));
          expect(content, contains('dot-shorthands'));
          expect(content, contains('macros'));
          expect(content, contains('records'));
          expect(content, contains('patterns'));
        },
      );
    });

    group('integration - full extraction', () {
      test('extracts complete package with multiple element types', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
library test_pkg;

/// A calculator class.
class Calculator {
  /// Adds two numbers.
  int add(int a, int b) => a + b;
}

/// Greets someone.
void greet(String name) {
  print('Hello, \$name!');
}

/// Colors.
enum Color { red, green, blue }

/// Version number.
const String version = '1.0.0';
''',
          },
        );

        final jsonPath = await extractor.run(packageDir);
        final json = await _loadJson(jsonPath);

        expect(_findDeclarations(json, 'class'), hasLength(1));
        expect(_findDeclarations(json, 'function'), hasLength(1));
        expect(_findDeclarations(json, 'enum'), hasLength(1));
        expect(_findDeclarations(json, 'variable'), hasLength(1));
      });

      test('handles package with experimental features', () async {
        final packageDir = await _createTestPackage(
          tempDir,
          name: 'test_pkg',
          libFiles: {
            'main.dart': '''
// Using records (experimental feature)
(int, String) getUserInfo() => (42, 'John');

// Using patterns (experimental feature)
void printUser() {
  final (age, name) = getUserInfo();
  print('\$name is \$age years old');
}
''',
          },
        );

        // Should successfully extract even with experimental features
        final jsonPath = await extractor.run(packageDir);
        expect(File(jsonPath).existsSync(), isTrue);
      });
    });
  });
}

// === Helper Functions ===

/// Creates a test Dart package in a temporary directory.
Future<String> _createTestPackage(
  Directory tempDir, {
  required String name,
  String? pubspecContent,
  Map<String, String>? libFiles,
  bool createLibDir = true,
}) async {
  final files = libFiles ?? <String, String>{};
  final packageDir = Directory(p.join(tempDir.path, name));
  await packageDir.create(recursive: true);

  // Create pubspec.yaml
  final pubspec =
      pubspecContent ??
      '''
name: $name
version: 1.0.0
environment:
  sdk: ^3.0.0
''';
  await File(p.join(packageDir.path, 'pubspec.yaml')).writeAsString(pubspec);

  // Create lib/ directory and files
  if (createLibDir) {
    final libDir = Directory(p.join(packageDir.path, 'lib'));
    await libDir.create();

    for (final entry in files.entries) {
      final filePath = p.join(libDir.path, entry.key);
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
    }
  }

  return packageDir.path;
}

/// Loads and parses JSON output from extractor.
Future<List<dynamic>> _loadJson(String jsonPath) async {
  final content = await File(jsonPath).readAsString();
  return jsonDecode(content) as List<dynamic>;
}

/// Finds all declarations of a specific kind in the JSON output.
List<Map<String, dynamic>> _findDeclarations(List<dynamic> json, String kind) {
  final results = <Map<String, dynamic>>[];
  for (final library in json) {
    if (library is! Map<String, dynamic>) continue;
    final declarations = library['declarations'] as List<dynamic>?;
    if (declarations == null) continue;

    for (final decl in declarations) {
      if (decl is Map<String, dynamic> && decl['kind'] == kind) {
        results.add(decl);
      }
    }
  }
  return results;
}
