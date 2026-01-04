/// Primary example demonstrating the core pubdev_mcp_bridge API.
///
/// This example shows how to:
/// - Extract package documentation
/// - Query classes, functions, and other API elements
/// - Work with package metadata
///
/// Run with: `dart run example/pubdev_mcp_bridge_example.dart`
library;

import 'package:pubdev_mcp_bridge/pubdev_mcp_bridge.dart';

Future<void> main() async {
  print('=== pubdev_mcp_bridge Example ===\n');

  // Create a documentation extractor
  final extractor = DocExtractor();

  try {
    print('Extracting documentation for package "path"...');
    // Extract documentation for a small, common package
    // This will download and cache it if not already cached
    final package = await extractor.getPackage('path');

    print('✓ Successfully extracted ${package.name}@${package.version}\n');

    // Display package metadata
    print('--- Package Information ---');
    print('Name: ${package.name}');
    print('Version: ${package.version}');
    if (package.description != null) {
      print('Description: ${package.description}');
    }
    if (package.repository != null) {
      print('Repository: ${package.repository}');
    }
    if (package.homepage != null) {
      print('Homepage: ${package.homepage}');
    }
    print('');

    // Display statistics
    print('--- Package Statistics ---');
    print('Libraries: ${package.libraries.length}');
    print('Total Classes: ${package.allClasses.length}');
    print('Total Functions: ${package.allFunctions.length}');
    print('Total Enums: ${package.allEnums.length}');
    print('');

    // Explore libraries
    print('--- Libraries ---');
    for (final library in package.libraries) {
      print('${library.name}:');
      print('  Classes: ${library.classes.length}');
      print('  Functions: ${library.functions.length}');
      print('  Enums: ${library.enums.length}');
    }
    print('');

    // Find and display details of a specific class
    print('--- Class Details Example ---');
    final context =
        package.allClasses.where((c) => c.name == 'Context').firstOrNull;
    if (context != null) {
      print('Class: ${context.name}');
      if (context.description != null) {
        print('Description: ${context.description}');
      }
      print('Abstract: ${context.isAbstract}');
      if (context.superclass != null) {
        print('Extends: ${context.superclass}');
      }
      print('Constructors: ${context.constructors.length}');
      print('Methods: ${context.methods.length}');
      print('Fields: ${context.fields.length}');

      // Show first constructor
      if (context.constructors.isNotEmpty) {
        print('\nFirst constructor:');
        final ctor = context.constructors.first;
        print('  ${ctor.signature}');
        if (ctor.description != null) {
          print('  ${ctor.description}');
        }
      }

      // Show first few methods
      if (context.methods.isNotEmpty) {
        print('\nMethods:');
        for (final method in context.methods.take(3)) {
          print('  ${method.signature}');
        }
        if (context.methods.length > 3) {
          print('  ... and ${context.methods.length - 3} more');
        }
      }
    } else {
      print('Context class not found (this is okay, just an example)');
    }
    print('');

    // Find and display top-level functions
    print('--- Top-Level Functions ---');
    if (package.allFunctions.isNotEmpty) {
      for (final function in package.allFunctions.take(5)) {
        print(function.signature);
        if (function.description != null) {
          final desc = function.description!.split('\n').first;
          print('  $desc');
        }
      }
      if (package.allFunctions.length > 5) {
        final remaining = package.allFunctions.length - 5;
        print('... and $remaining more');
      }
    } else {
      print('No top-level functions found');
    }
    print('');

    // Search example: Find all classes with "path" in the name
    print('--- Search Example ---');
    print('Classes with "path" in the name:');
    final pathClasses =
        package.allClasses
            .where((c) => c.name.toLowerCase().contains('path'))
            .toList();
    for (final cls in pathClasses) {
      print('  ${cls.name}');
    }
    print('');
  } catch (e) {
    print('Error: $e');
    rethrow;
  } finally {
    // Always close the extractor to free resources
    extractor.close();
    print('=== Complete ===');
  }
}
