/// Tests for [CleanCommand] CLI command.
///
/// Tests argument parsing, validation, and option handling for the clean
/// command. Full integration tests are in cache_manager_test.dart.
import 'package:test/test.dart';
import 'package:args/command_runner.dart';
import 'package:pubdev_mcp_bridge/src/cli/commands/clean_command.dart';

void main() {
  group('CleanCommand', () {
    late CommandRunner<int> runner;
    late CleanCommand command;

    setUp(() {
      command = CleanCommand();
      runner = CommandRunner<int>('test', 'Test runner')..addCommand(command);
    });

    group('command metadata', () {
      test('has correct name', () {
        expect(command.name, equals('clean'));
      });

      test('has description', () {
        expect(command.description, isNotEmpty);
        expect(command.description, contains('Remove'));
      });
    });

    group('argument parsing', () {
      test('supports --version flag', () {
        expect(command.argParser.options.containsKey('version'), isTrue);
        expect(command.argParser.options['version']?.abbr, equals('v'));
      });

      test('supports --all flag', () {
        expect(command.argParser.options.containsKey('all'), isTrue);
        expect(command.argParser.options['all']?.abbr, equals('a'));
        expect(command.argParser.options['all']?.isFlag, isTrue);
      });

      test('all flag is not negatable', () {
        expect(command.argParser.options['all']?.negatable, isFalse);
      });
    });

    group('validation', () {
      test(
        'throws UsageException when package name missing and not --all',
        () async {
          expect(() => runner.run(['clean']), throwsA(isA<UsageException>()));
        },
      );

      test('accepts package name', () {
        final results = command.argParser.parse(['test_package']);
        expect(results.rest.first, equals('test_package'));
      });

      test('accepts --all without package name', () {
        final results = command.argParser.parse(['--all']);
        expect(results['all'], isTrue);
      });
    });

    group('option handling', () {
      test('parses version option', () {
        final results = command.argParser.parse([
          '--version',
          '1.0.0',
          'test_package',
        ]);

        expect(results['version'], equals('1.0.0'));
        expect(results.rest.first, equals('test_package'));
      });

      test('parses all flag', () {
        final results = command.argParser.parse(['--all']);

        expect(results['all'], isTrue);
      });

      test('all defaults to false', () {
        final results = command.argParser.parse(['test_package']);

        expect(results['all'], isFalse);
      });

      test('supports abbreviated flags', () {
        final results = command.argParser.parse(['-v', '1.0.0', '-a']);

        expect(results['version'], equals('1.0.0'));
        expect(results['all'], isTrue);
      });

      test('can specify version without package for --all', () {
        // This is technically allowed by parser, though may not be used
        final results = command.argParser.parse(['--all', '-v', '1.0.0']);

        expect(results['all'], isTrue);
        expect(results['version'], equals('1.0.0'));
      });
    });

    group('usage', () {
      test('includes usage information', () {
        expect(command.usage, isNotEmpty);
        expect(command.usage, contains('clean'));
      });

      test('shows available options in usage', () {
        expect(command.usage, contains('version'));
        expect(command.usage, contains('all'));
      });
    });
  });
}
