/// Runs dartdoc_json to generate API documentation.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Runs dartdoc_json on a package directory.
class DartdocRunner {
  /// Checks if dartdoc_json is installed globally.
  Future<bool> isInstalled() async {
    try {
      // dartdoc_json doesn't have --version, just check if it's in PATH
      final result = await Process.run('which', ['dartdoc_json']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Creates an analysis_options.yaml file to enable language features.
  Future<void> _createAnalysisOptions(String packageDir) async {
    final analysisOptions = File(p.join(packageDir, 'analysis_options.yaml'));

    // Enable all experimental features for parsing
    const content = '''
analyzer:
  enable-experiment:
    - dot-shorthands
    - inline-class
    - macros
''';

    await analysisOptions.writeAsString(content);
  }

  /// Runs `dart pub get` in the package directory.
  Future<void> pubGet(String packageDir) async {
    final result = await Process.run('dart', [
      'pub',
      'get',
    ], workingDirectory: packageDir);

    if (result.exitCode != 0) {
      throw StateError('dart pub get failed: ${result.stderr}');
    }
  }

  /// Finds all Dart files in a package's lib directory.
  /// Includes both public libraries and src files to capture all declarations.
  List<String> findLibraryFiles(String packageDir) {
    final libDir = Directory(p.join(packageDir, 'lib'));
    if (!libDir.existsSync()) return [];

    final files = <String>[];

    // Get all dart files recursively (including src/)
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(p.relative(entity.path, from: packageDir));
      }
    }

    return files;
  }

  /// Runs dartdoc_json and returns the output JSON file path.
  ///
  /// Returns the path to the generated JSON file.
  Future<String> run(String packageDir) async {
    if (!await isInstalled()) {
      throw StateError(
        'dartdoc_json is not installed. '
        'Run: dart pub global activate dartdoc_json',
      );
    }

    // Create analysis options to enable experimental features
    await _createAnalysisOptions(packageDir);

    // Run pub get first
    await pubGet(packageDir);

    // Find library files
    final libFiles = findLibraryFiles(packageDir);
    if (libFiles.isEmpty) {
      throw StateError('No library files found in package');
    }

    // Output file path
    final outputPath = p.join(packageDir, 'api_doc.json');

    // Run dartdoc_json with experiments enabled via environment variable
    // This is necessary because dartdoc_json uses parseFile which doesn't
    // respect analysis_options.yaml
    final result = await Process.run(
      'dartdoc_json',
      ['--root', packageDir, '--output', outputPath, '--pretty', ...libFiles],
      environment: {
        ...Platform.environment,
        'DART_VM_OPTIONS': '--enable-experiment=dot-shorthands,macros',
      },
    );

    if (result.exitCode != 0) {
      throw StateError('dartdoc_json failed: ${result.stderr}');
    }

    if (!File(outputPath).existsSync()) {
      throw StateError('dartdoc_json did not create output file');
    }

    return outputPath;
  }
}
