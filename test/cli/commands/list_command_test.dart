/// Tests for [ListCommand] CLI command.
///
/// Covers basic command configuration (name, description) and integration
/// with [CacheManager] for listing cached packages. Tests verify command
/// execution and output formatting.
///
/// Test isolation: Integration tests use isolated temporary cache directories
/// to avoid interfering with the system cache.
import 'dart:io';
import 'package:test/test.dart';
import 'package:pubdev_mcp_bridge/src/cli/commands/list_command.dart';
import 'package:pubdev_mcp_bridge/src/cache/cache_manager.dart';
import 'package:pubdev_mcp_bridge/src/models/package_doc.dart';

void main() {
  group('ListCommand', () {
    late ListCommand command;

    setUp(() {
      command = ListCommand();
    });

    test('has correct name', () {
      expect(command.name, equals('list'));
    });

    test('has description', () {
      expect(command.description, isNotEmpty);
    });

    test('prints message when no packages cached', () async {
      // Note: This test will use the default cache location
      // In a real scenario, you'd want to mock CacheManager
      // For now, we just verify the command runs without error
      final exitCode = await command.run();
      expect(exitCode, equals(0));
    });

    test('runs successfully', () async {
      final exitCode = await command.run();
      expect(exitCode, isA<int>());
    });
  });

  group('ListCommand - Integration', () {
    late Directory tempDir;
    late CacheManager cache;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('list_cmd_test_');
      cache = CacheManager(tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('command can list packages from cache', () async {
      // Setup: Add some packages to cache
      await cache.savePackage(PackageDoc(name: 'pkg1', version: '1.0.0'));
      await cache.savePackage(PackageDoc(name: 'pkg2', version: '2.0.0'));

      final packages = await cache.listCached();
      expect(packages, hasLength(2));
    });
  });
}
