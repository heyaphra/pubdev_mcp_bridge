/// Tests for [ServeCommand] CLI command.
///
/// Tests argument parsing, validation, and option handling for the serve
/// command. Full integration tests would require MCP protocol testing.
import 'package:test/test.dart';
import 'package:args/command_runner.dart';
import 'package:pubdev_mcp_bridge/src/cli/commands/serve_command.dart';

void main() {
  group('ServeCommand', () {
    late CommandRunner<int> runner;
    late ServeCommand command;

    setUp(() {
      command = ServeCommand();
      runner = CommandRunner<int>('test', 'Test runner')..addCommand(command);
    });

    group('command metadata', () {
      test('has correct name', () {
        expect(command.name, equals('serve'));
      });

      test('has description', () {
        expect(command.description, isNotEmpty);
        expect(command.description, contains('MCP server'));
      });
    });

    group('argument parsing', () {
      test('supports --version flag', () {
        expect(command.argParser.options.containsKey('version'), isTrue);
        expect(command.argParser.options['version']?.abbr, equals('v'));
      });

      test('supports --refresh flag', () {
        expect(command.argParser.options.containsKey('refresh'), isTrue);
        expect(command.argParser.options['refresh']?.abbr, equals('r'));
        expect(command.argParser.options['refresh']?.isFlag, isTrue);
      });

      test('refresh flag is not negatable', () {
        expect(command.argParser.options['refresh']?.negatable, isFalse);
      });
    });

    group('validation', () {
      test('throws UsageException when package name missing', () async {
        expect(() => runner.run(['serve']), throwsA(isA<UsageException>()));
      });

      test('accepts package name', () {
        final results = command.argParser.parse(['test_package']);
        expect(results.rest.first, equals('test_package'));
      });
    });

    group('option handling', () {
      test('parses version option', () {
        final results = command.argParser.parse([
          '--version',
          '1.2.3',
          'test_package',
        ]);

        expect(results['version'], equals('1.2.3'));
        expect(results.rest.first, equals('test_package'));
      });

      test('parses refresh flag', () {
        final results = command.argParser.parse(['--refresh', 'test_package']);

        expect(results['refresh'], isTrue);
      });

      test('refresh defaults to false', () {
        final results = command.argParser.parse(['test_package']);

        expect(results['refresh'], isFalse);
      });

      test('supports abbreviated flags', () {
        final results = command.argParser.parse([
          '-v',
          '2.0.0',
          '-r',
          'test_package',
        ]);

        expect(results['version'], equals('2.0.0'));
        expect(results['refresh'], isTrue);
      });
    });

    group('usage', () {
      test('includes usage information', () {
        expect(command.usage, isNotEmpty);
        expect(command.usage, contains('serve'));
      });

      test('shows available options in usage', () {
        expect(command.usage, contains('version'));
        expect(command.usage, contains('refresh'));
      });
    });
  });
}
