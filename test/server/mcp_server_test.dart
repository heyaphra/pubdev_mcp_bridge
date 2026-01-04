/// Tests for [PubdevMcpServer] MCP server implementation.
///
/// Tests server creation and package documentation integration.
/// Full MCP protocol testing would require complex stdio mocking and is
/// better suited for integration tests.
///
/// Test isolation: Uses in-memory fixtures. No network or file system
/// dependencies.
import 'dart:async';

import 'package:test/test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:pubdev_mcp_bridge/src/server/mcp_server.dart';
import 'package:pubdev_mcp_bridge/src/models/package_doc.dart';

void main() {
  group('PubdevMcpServer', () {
    late PackageDoc testPackage;

    setUp(() {
      testPackage = _createTestPackage();
    });

    group('creation', () {
      test('creates server with package documentation', () {
        final channel = _createMockChannel();
        final server = PubdevMcpServer(channel: channel, package: testPackage);

        expect(server, isNotNull);
        expect(server.package, equals(testPackage));
      });

      test('package field is accessible', () {
        final channel = _createMockChannel();
        final server = PubdevMcpServer(channel: channel, package: testPackage);

        expect(server.package.name, equals('test_package'));
        expect(server.package.version, equals('1.0.0'));
        expect(server.package.libraries, hasLength(1));
      });

      test('creates server with empty package', () {
        final emptyPackage = PackageDoc(
          name: 'empty',
          version: '1.0.0',
          libraries: [],
        );

        final channel = _createMockChannel();
        final server = PubdevMcpServer(channel: channel, package: emptyPackage);

        expect(server.package.libraries, isEmpty);
      });
    });

    group('package integration', () {
      test('accesses all classes from package', () {
        final channel = _createMockChannel();
        final server = PubdevMcpServer(channel: channel, package: testPackage);

        expect(server.package.allClasses, hasLength(1));
        expect(server.package.allClasses.first.name, equals('Calculator'));
      });

      test('accesses all functions from package', () {
        final channel = _createMockChannel();
        final server = PubdevMcpServer(channel: channel, package: testPackage);

        expect(server.package.allFunctions, hasLength(1));
        expect(server.package.allFunctions.first.name, equals('greet'));
      });

      test('accesses all enums from package', () {
        final channel = _createMockChannel();
        final server = PubdevMcpServer(channel: channel, package: testPackage);

        expect(server.package.allEnums, hasLength(1));
        expect(server.package.allEnums.first.name, equals('Color'));
      });

      test('accesses all extensions from package', () {
        final channel = _createMockChannel();
        final server = PubdevMcpServer(channel: channel, package: testPackage);

        expect(server.package.allExtensions, hasLength(1));
        expect(server.package.allExtensions.first.name, equals('StringUtils'));
        expect(server.package.allExtensions.first.onType, equals('String'));
      });

      test('accesses libraries from package', () {
        final channel = _createMockChannel();
        final server = PubdevMcpServer(channel: channel, package: testPackage);

        expect(server.package.libraries, hasLength(1));
        expect(server.package.libraries.first.name, equals('test_package'));
      });

      test('handles package with metadata', () {
        final packageWithMetadata = PackageDoc(
          name: 'test_package',
          version: '1.0.0',
          description: 'A test package',
          homepage: 'https://example.com',
          repository: 'https://github.com/test/pkg',
          libraries: [],
        );

        final channel = _createMockChannel();
        final server = PubdevMcpServer(
          channel: channel,
          package: packageWithMetadata,
        );

        expect(server.package.description, equals('A test package'));
        expect(server.package.homepage, equals('https://example.com'));
        expect(
          server.package.repository,
          equals('https://github.com/test/pkg'),
        );
      });
    });

    group('test data validation', () {
      test('test package has expected structure', () {
        expect(testPackage.name, equals('test_package'));
        expect(testPackage.version, equals('1.0.0'));
        expect(testPackage.libraries, hasLength(1));

        final library = testPackage.libraries.first;
        expect(library.name, equals('test_package'));
        expect(library.classes, hasLength(1));
        expect(library.functions, hasLength(1));
        expect(library.enums, hasLength(1));
        expect(library.extensions, hasLength(1));
      });

      test('test class has expected structure', () {
        final calculator = testPackage.allClasses.first;
        expect(calculator.name, equals('Calculator'));
        expect(calculator.description, contains('calculator'));
        expect(calculator.constructors, hasLength(1));
        expect(calculator.methods, hasLength(1));
      });

      test('test function has expected structure', () {
        final greet = testPackage.allFunctions.first;
        expect(greet.name, equals('greet'));
        expect(greet.description, contains('Greets'));
      });

      test('test enum has expected structure', () {
        final color = testPackage.allEnums.first;
        expect(color.name, equals('Color'));
        expect(color.values, hasLength(3));
        expect(
          color.values.map((v) => v.name),
          containsAll(['red', 'green', 'blue']),
        );
      });

      test('test extension has expected structure', () {
        final stringUtils = testPackage.allExtensions.first;
        expect(stringUtils.name, equals('StringUtils'));
        expect(stringUtils.description, contains('string utilities'));
        expect(stringUtils.onType, equals('String'));
        expect(stringUtils.methods, hasLength(1));
        expect(stringUtils.methods.first.name, equals('capitalize'));
      });
    });
  });
}

// === Helper Functions ===

/// Creates a test PackageDoc with sample data.
PackageDoc _createTestPackage() {
  return PackageDoc(
    name: 'test_package',
    version: '1.0.0',
    libraries: [
      LibraryDoc(
        name: 'test_package',
        description: 'Main library',
        classes: [
          ClassDoc(
            name: 'Calculator',
            description: 'A simple calculator class',
            isAbstract: false,
            constructors: [
              ConstructorDoc(
                name: 'Calculator',
                parameters: [],
                isConst: false,
                isFactory: false,
              ),
            ],
            methods: [
              MethodDoc(
                name: 'add',
                description: 'Adds two numbers',
                returnType: 'int',
                isStatic: false,
                isAbstract: false,
                isOperator: false,
                parameters: [],
              ),
            ],
            fields: [],
          ),
        ],
        functions: [
          FunctionDoc(
            name: 'greet',
            description: 'Greets someone',
            returnType: 'void',
            parameters: [],
          ),
        ],
        enums: [
          EnumDoc(
            name: 'Color',
            description: 'Primary colors',
            values: [
              EnumValueDoc(name: 'red'),
              EnumValueDoc(name: 'green'),
              EnumValueDoc(name: 'blue'),
            ],
          ),
        ],
        extensions: [
          ExtensionDoc(
            name: 'StringUtils',
            description: 'Useful string utilities',
            onType: 'String',
            methods: [
              MethodDoc(
                name: 'capitalize',
                description: 'Capitalizes the first letter',
                returnType: 'String',
                isStatic: false,
                isAbstract: false,
                isOperator: false,
                parameters: [],
              ),
            ],
            fields: [],
          ),
        ],
      ),
    ],
  );
}

/// Creates a mock StreamChannel for testing.
StreamChannel<String> _createMockChannel() {
  final inputController = StreamController<String>();
  final outputController = StreamController<String>();

  return StreamChannel(inputController.stream, outputController.sink);
}
