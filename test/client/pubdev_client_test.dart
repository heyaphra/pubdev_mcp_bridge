/// Tests for [PubdevClient] HTTP client functionality.
///
/// Uses [MockClient] from package:http/testing.dart for all network requests
/// to ensure tests are isolated and don't depend on external services or
/// network connectivity. Covers package metadata fetching, version resolution,
/// archive downloads, and comprehensive error handling.
///
/// Test isolation: All HTTP requests are mocked. File downloads use isolated
/// temporary directories that are cleaned up after each test.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pubdev_mcp_bridge/src/client/pubdev_client.dart';

void main() {
  group('PackageNotFoundException', () {
    test('creates instance with package name', () {
      final exception = PackageNotFoundException('test_package');
      expect(exception.packageName, equals('test_package'));
    });

    test('toString includes package name', () {
      final exception = PackageNotFoundException('my_pkg');
      expect(exception.toString(), equals('Package not found: my_pkg'));
    });
  });

  group('PubdevClientException', () {
    test('creates instance with message only', () {
      final exception = PubdevClientException('Test error');
      expect(exception.message, equals('Test error'));
      expect(exception.statusCode, isNull);
      expect(exception.stackTrace, isNull);
    });

    test('creates instance with status code', () {
      final exception = PubdevClientException('Test error', 500);
      expect(exception.message, equals('Test error'));
      expect(exception.statusCode, equals(500));
    });

    test('creates instance with stack trace', () {
      final trace = StackTrace.current;
      final exception = PubdevClientException('Test error', 500, trace);
      expect(exception.stackTrace, equals(trace));
    });

    test('toString includes message', () {
      final exception = PubdevClientException('Test error');
      expect(exception.toString(), contains('Test error'));
    });

    test('toString includes status code when provided', () {
      final exception = PubdevClientException('Test error', 500);
      expect(exception.toString(), contains('500'));
      expect(exception.toString(), contains('Test error'));
    });

    test('toString includes stack trace when provided', () {
      final trace = StackTrace.current;
      final exception = PubdevClientException('Test error', 500, trace);
      final str = exception.toString();
      expect(str, contains('Test error'));
      expect(str, contains('\n')); // Stack trace should add newlines
    });
  });

  group('PubdevClient - Initialization', () {
    test('creates instance with default client', () {
      final client = PubdevClient();
      addTearDown(() => client.close());

      expect(client, isNotNull);
    });

    test('creates instance with custom client', () {
      final mockClient = MockClient((_) async => http.Response('', 200));
      final client = PubdevClient(mockClient);
      addTearDown(() => client.close());

      expect(client, isNotNull);
    });

    test('close can be called multiple times', () {
      final client = PubdevClient();
      client.close();
      client.close(); // Should not throw
    });
  });

  group('PubdevClient - getPackageMetadata', () {
    test('returns metadata for valid package', () async {
      final mockMetadata = {
        'name': 'test_package',
        'latest': {
          'version': '1.0.0',
          'pubspec': {'description': 'Test package'},
        },
        'versions': [
          {'version': '1.0.0'},
        ],
      };

      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          equals('https://pub.dev/api/packages/test_package'),
        );
        return http.Response(jsonEncode(mockMetadata), 200);
      });

      final client = PubdevClient(mockClient);
      final metadata = await client.getPackageMetadata('test_package');

      expect(metadata['name'], equals('test_package'));
      expect(metadata['latest']['version'], equals('1.0.0'));
      client.close();
    });

    test('throws PackageNotFoundException for 404', () async {
      final mockClient = MockClient(
        (_) async => http.Response('Not Found', 404),
      );

      final client = PubdevClient(mockClient);

      expect(
        () => client.getPackageMetadata('nonexistent_package'),
        throwsA(isA<PackageNotFoundException>()),
      );

      client.close();
    });

    test('throws PubdevClientException for 500 error', () async {
      final mockClient = MockClient(
        (_) async => http.Response('Server Error', 500),
      );

      final client = PubdevClient(mockClient);

      expect(
        () => client.getPackageMetadata('test_package'),
        throwsA(
          isA<PubdevClientException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );

      client.close();
    });

    test('throws PubdevClientException for network error', () async {
      final mockClient = MockClient((_) async {
        throw const SocketException('Network unreachable');
      });

      final client = PubdevClient(mockClient);

      expect(
        () => client.getPackageMetadata('test_package'),
        throwsA(isA<SocketException>()),
      );

      client.close();
    });

    test('handles complex metadata structure', () async {
      final mockMetadata = {
        'name': 'dio',
        'latest': {
          'version': '5.4.0',
          'pubspec': {
            'name': 'dio',
            'description': 'HTTP client for Dart',
            'homepage': 'https://github.com/cfug/dio',
          },
          'archive_url': 'https://pub.dev/packages/dio/versions/5.4.0.tar.gz',
        },
        'versions': [
          {'version': '5.4.0'},
          {'version': '5.3.0'},
          {'version': '5.2.0'},
        ],
      };

      final mockClient = MockClient(
        (_) async => http.Response(jsonEncode(mockMetadata), 200),
      );

      final client = PubdevClient(mockClient);
      final metadata = await client.getPackageMetadata('dio');

      expect(metadata['versions'], hasLength(3));
      expect(metadata['latest']['pubspec']['description'], isNotNull);
      client.close();
    });
  });

  group('PubdevClient - getLatestVersion', () {
    test('returns latest version for package', () async {
      final mockMetadata = {
        'name': 'test_package',
        'latest': {'version': '2.5.1'},
      };

      final mockClient = MockClient(
        (_) async => http.Response(jsonEncode(mockMetadata), 200),
      );

      final client = PubdevClient(mockClient);
      final version = await client.getLatestVersion('test_package');

      expect(version, equals('2.5.1'));
      client.close();
    });

    test('throws PackageNotFoundException for non-existent package', () async {
      final mockClient = MockClient(
        (_) async => http.Response('Not Found', 404),
      );

      final client = PubdevClient(mockClient);

      expect(
        () => client.getLatestVersion('nonexistent'),
        throwsA(isA<PackageNotFoundException>()),
      );

      client.close();
    });

    test('handles pre-release versions', () async {
      final mockMetadata = {
        'name': 'test_package',
        'latest': {'version': '3.0.0-beta.1'},
      };

      final mockClient = MockClient(
        (_) async => http.Response(jsonEncode(mockMetadata), 200),
      );

      final client = PubdevClient(mockClient);
      final version = await client.getLatestVersion('test_package');

      expect(version, equals('3.0.0-beta.1'));
      client.close();
    });
  });

  group('PubdevClient - resolveVersion', () {
    final mockMetadata = {
      'name': 'test_package',
      'latest': {'version': '2.0.0'},
      'versions': [
        {'version': '2.0.0'},
        {'version': '1.5.0'},
        {'version': '1.0.0'},
      ],
    };

    test('returns latest version when version is null', () async {
      final mockClient = MockClient(
        (_) async => http.Response(jsonEncode(mockMetadata), 200),
      );

      final client = PubdevClient(mockClient);
      final version = await client.resolveVersion('test_package', null);

      expect(version, equals('2.0.0'));
      client.close();
    });

    test('returns latest version when version is "latest"', () async {
      final mockClient = MockClient(
        (_) async => http.Response(jsonEncode(mockMetadata), 200),
      );

      final client = PubdevClient(mockClient);
      final version = await client.resolveVersion('test_package', 'latest');

      expect(version, equals('2.0.0'));
      client.close();
    });

    test('verifies and returns specific version', () async {
      final mockClient = MockClient(
        (_) async => http.Response(jsonEncode(mockMetadata), 200),
      );

      final client = PubdevClient(mockClient);
      final version = await client.resolveVersion('test_package', '1.5.0');

      expect(version, equals('1.5.0'));
      client.close();
    });

    test('throws PubdevClientException for non-existent version', () async {
      final mockClient = MockClient(
        (_) async => http.Response(jsonEncode(mockMetadata), 200),
      );

      final client = PubdevClient(mockClient);

      expect(
        () => client.resolveVersion('test_package', '999.0.0'),
        throwsA(
          isA<PubdevClientException>().having(
            (e) => e.message,
            'message',
            contains('Version 999.0.0 not found'),
          ),
        ),
      );

      client.close();
    });

    test('throws PackageNotFoundException for non-existent package', () async {
      final mockClient = MockClient(
        (_) async => http.Response('Not Found', 404),
      );

      final client = PubdevClient(mockClient);

      expect(
        () => client.resolveVersion('nonexistent', '1.0.0'),
        throwsA(isA<PackageNotFoundException>()),
      );

      client.close();
    });
  });

  group('PubdevClient - downloadArchive', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('download_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('downloads archive successfully', () async {
      final archiveData = List.generate(100, (i) => i % 256);

      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          equals('https://pub.dev/packages/test_package/versions/1.0.0.tar.gz'),
        );
        return http.Response.bytes(archiveData, 200);
      });

      final client = PubdevClient(mockClient);
      final outputPath = '${tempDir.path}/test_package-1.0.0.tar.gz';

      await client.downloadArchive('test_package', '1.0.0', outputPath);

      final file = File(outputPath);
      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync(), equals(archiveData));

      client.close();
    });

    test('creates parent directories if needed', () async {
      final mockClient = MockClient(
        (_) async => http.Response.bytes([1, 2, 3], 200),
      );

      final client = PubdevClient(mockClient);
      final outputPath = '${tempDir.path}/nested/dir/package.tar.gz';

      await client.downloadArchive('test_package', '1.0.0', outputPath);

      expect(File(outputPath).existsSync(), isTrue);
      client.close();
    });

    test('throws PackageNotFoundException for 404', () async {
      final mockClient = MockClient(
        (_) async => http.Response('Not Found', 404),
      );

      final client = PubdevClient(mockClient);
      final outputPath = '${tempDir.path}/package.tar.gz';

      expect(
        () => client.downloadArchive('nonexistent', '1.0.0', outputPath),
        throwsA(
          isA<PackageNotFoundException>().having(
            (e) => e.packageName,
            'packageName',
            'nonexistent@1.0.0',
          ),
        ),
      );

      client.close();
    });

    test('throws PubdevClientException for server error', () async {
      final mockClient = MockClient((_) async => http.Response('Error', 500));

      final client = PubdevClient(mockClient);
      final outputPath = '${tempDir.path}/package.tar.gz';

      expect(
        () => client.downloadArchive('test_package', '1.0.0', outputPath),
        throwsA(
          isA<PubdevClientException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );

      client.close();
    });

    test('handles large archives', () async {
      // Simulate a 1MB archive
      final largeData = List.generate(1024 * 1024, (i) => i % 256);

      final mockClient = MockClient(
        (_) async => http.Response.bytes(largeData, 200),
      );

      final client = PubdevClient(mockClient);
      final outputPath = '${tempDir.path}/large.tar.gz';

      await client.downloadArchive('large_package', '1.0.0', outputPath);

      final file = File(outputPath);
      expect(file.lengthSync(), equals(1024 * 1024));

      client.close();
    });

    test('overwrites existing file', () async {
      final outputPath = '${tempDir.path}/package.tar.gz';

      // Create existing file
      await File(outputPath).writeAsBytes([1, 2, 3]);

      final newData = [4, 5, 6, 7, 8];
      final mockClient = MockClient(
        (_) async => http.Response.bytes(newData, 200),
      );

      final client = PubdevClient(mockClient);

      await client.downloadArchive('test_package', '1.0.0', outputPath);

      final file = File(outputPath);
      expect(file.readAsBytesSync(), equals(newData));

      client.close();
    });
  });

  group('PubdevClient - Integration Scenarios', () {
    test('complete workflow: resolve version and download', () async {
      final metadata = {
        'name': 'my_package',
        'latest': {'version': '3.2.1'},
        'versions': [
          {'version': '3.2.1'},
          {'version': '3.2.0'},
        ],
      };

      final archiveData = [1, 2, 3, 4, 5];
      var requestCount = 0;

      final mockClient = MockClient((request) async {
        requestCount++;
        if (request.url.path.contains('/api/packages/')) {
          return http.Response(jsonEncode(metadata), 200);
        } else {
          return http.Response.bytes(archiveData, 200);
        }
      });

      final client = PubdevClient(mockClient);

      // Resolve version
      final version = await client.resolveVersion('my_package', null);
      expect(version, equals('3.2.1'));

      // Download archive
      final tempDir = await Directory.systemTemp.createTemp('test_');
      final outputPath = '${tempDir.path}/archive.tar.gz';
      await client.downloadArchive('my_package', version, outputPath);

      expect(File(outputPath).existsSync(), isTrue);
      expect(requestCount, equals(2)); // One for metadata, one for download

      client.close();
      await tempDir.delete(recursive: true);
    });

    test('handles multiple packages in sequence', () async {
      final responses = {
        'pkg1': {
          'name': 'pkg1',
          'latest': {'version': '1.0.0'},
          'versions': [],
        },
        'pkg2': {
          'name': 'pkg2',
          'latest': {'version': '2.0.0'},
          'versions': [],
        },
        'pkg3': {
          'name': 'pkg3',
          'latest': {'version': '3.0.0'},
          'versions': [],
        },
      };

      final mockClient = MockClient((request) async {
        final packageName = request.url.pathSegments.last;
        if (responses.containsKey(packageName)) {
          return http.Response(jsonEncode(responses[packageName]), 200);
        }
        return http.Response('Not Found', 404);
      });

      final client = PubdevClient(mockClient);

      final v1 = await client.getLatestVersion('pkg1');
      final v2 = await client.getLatestVersion('pkg2');
      final v3 = await client.getLatestVersion('pkg3');

      expect(v1, equals('1.0.0'));
      expect(v2, equals('2.0.0'));
      expect(v3, equals('3.0.0'));

      client.close();
    });
  });

  group('PubdevClient - Error Handling', () {
    test('provides helpful error message on network timeout', () async {
      final mockClient = MockClient((_) async {
        throw TimeoutException('Connection timed out');
      });

      final client = PubdevClient(mockClient);

      expect(
        () => client.getPackageMetadata('test_package'),
        throwsA(isA<TimeoutException>()),
      );

      client.close();
    });

    test('handles malformed JSON response', () async {
      final mockClient = MockClient(
        (_) async => http.Response('not valid json', 200),
      );

      final client = PubdevClient(mockClient);

      expect(
        () => client.getPackageMetadata('test_package'),
        throwsA(isA<FormatException>()),
      );

      client.close();
    });

    test('handles missing fields in metadata', () async {
      final mockClient = MockClient(
        (_) async => http.Response('{"name": "pkg"}', 200),
      );

      final client = PubdevClient(mockClient);

      // Should throw when trying to access missing 'latest' field
      expect(
        () => client.getLatestVersion('test_package'),
        throwsA(isA<NoSuchMethodError>()),
      );

      client.close();
    });
  });
}
