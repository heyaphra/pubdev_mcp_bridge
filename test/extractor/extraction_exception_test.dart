/// Tests for [ExtractionException] custom exception.
///
/// Tests exception creation, string formatting, and error message handling.
import 'package:test/test.dart';
import 'package:pubdev_mcp_bridge/src/extractor/extraction_exception.dart';

void main() {
  group('ExtractionException', () {
    group('constructor', () {
      test('creates with message only', () {
        final exception = ExtractionException('Test error');

        expect(exception.message, equals('Test error'));
        expect(exception.details, isNull);
      });

      test('creates with message and details', () {
        final exception = ExtractionException(
          'Test error',
          'Additional details here',
        );

        expect(exception.message, equals('Test error'));
        expect(exception.details, equals('Additional details here'));
      });

      test('handles null details', () {
        final exception = ExtractionException('Test error', null);

        expect(exception.message, equals('Test error'));
        expect(exception.details, isNull);
      });
    });

    group('toString', () {
      test('returns message only when no details', () {
        final exception = ExtractionException('Test error');

        expect(exception.toString(), equals('ExtractionException: Test error'));
      });

      test('includes details when present', () {
        final exception = ExtractionException(
          'Test error',
          'Additional details',
        );

        final str = exception.toString();
        expect(str, contains('ExtractionException: Test error'));
        expect(str, contains('Details: Additional details'));
      });

      test('handles empty details string', () {
        final exception = ExtractionException('Test error', '');

        // Empty details should not include Details: section
        expect(exception.toString(), equals('ExtractionException: Test error'));
      });
    });
  });
}
