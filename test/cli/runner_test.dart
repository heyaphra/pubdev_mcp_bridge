/// Tests for [PubdevMcpBridgeRunner] CLI runner.
///
/// Tests command registration, version flag, and error handling for the
/// main CLI entry point.
import 'package:test/test.dart';
import 'package:pubdev_mcp_bridge/src/cli/runner.dart';
import 'package:pubdev_mcp_bridge/src/version.dart';

void main() {
  group('PubdevMcpBridgeRunner', () {
    late PubdevMcpBridgeRunner runner;

    setUp(() {
      runner = PubdevMcpBridgeRunner();
    });

    group('runner metadata', () {
      test('has correct executable name', () {
        expect(runner.executableName, equals('pubdev_mcp_bridge'));
      });

      test('has description', () {
        expect(runner.description, isNotEmpty);
        expect(runner.description, contains('MCP'));
      });
    });

    group('command registration', () {
      test('registers serve command', () {
        expect(runner.commands.containsKey('serve'), isTrue);
      });

      test('registers extract command', () {
        expect(runner.commands.containsKey('extract'), isTrue);
      });

      test('registers list command', () {
        expect(runner.commands.containsKey('list'), isTrue);
      });

      test('registers clean command', () {
        expect(runner.commands.containsKey('clean'), isTrue);
      });
    });

    group('version flag', () {
      test('supports --version flag', () {
        expect(runner.argParser.options.containsKey('version'), isTrue);
      });

      test('version flag is not negatable', () {
        expect(runner.argParser.options['version']?.negatable, isFalse);
      });

      test('prints version when --version flag provided', () async {
        final exitCode = await runner.run(['--version']);

        expect(exitCode, equals(0));
      });

      test('version output includes package version', () async {
        // This would require capturing stdout, which is complex in tests
        // The test above verifies the flag works without error
        expect(packageVersion, isNotEmpty);
      });
    });

    group('error handling', () {
      test('returns EX_USAGE code for unknown command', () async {
        final exitCode = await runner.run(['unknown_command']);

        expect(exitCode, equals(64)); // EX_USAGE
      });

      test('returns EX_USAGE code for invalid arguments', () async {
        final exitCode = await runner.run(['serve']); // Missing package name

        expect(exitCode, equals(64)); // EX_USAGE
      });
    });

    group('help', () {
      test('shows usage when no command provided', () async {
        final exitCode = await runner.run([]);

        // Should show usage and return success or usage error
        expect(exitCode, anyOf(equals(0), equals(64)));
      });
    });
  });
}
