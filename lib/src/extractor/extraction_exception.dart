/// Exception thrown during package extraction or analysis.
///
/// This exception is used throughout the extraction pipeline when errors
/// occur during:
/// - Running `dart pub get`
/// - Analyzing Dart source code
/// - Parsing documentation
/// - Writing output files
library;

/// Exception thrown when package extraction fails.
///
/// Provides detailed error information including the operation that failed
/// and optional details about what went wrong.
class ExtractionException implements Exception {
  /// The error message describing what went wrong.
  final String message;

  /// Additional details about the error (e.g., stderr output, stack trace).
  final String? details;

  /// Creates an extraction exception with [message] and optional [details].
  ///
  /// Example:
  /// ```dart
  /// throw ExtractionException(
  ///   'dart pub get failed',
  ///   'Error: Could not resolve dependencies',
  /// );
  /// ```
  ExtractionException(this.message, [this.details]);

  @override
  String toString() {
    if (details != null && details!.isNotEmpty) {
      return 'ExtractionException: $message\nDetails: $details';
    }
    return 'ExtractionException: $message';
  }
}
