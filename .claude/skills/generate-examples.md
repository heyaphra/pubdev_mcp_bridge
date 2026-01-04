---
description: Traverse a Dart codebase and generate comprehensive, runnable examples in the example/ directory for pub.dev compliance and developer onboarding.
---

# Generate Examples from Codebase

Analyze a Dart codebase and automatically generate relevant, runnable example files that demonstrate the public API, improving pub.dev scoring and developer experience.

## Purpose

This skill addresses a common gap in Dart packages: missing or inadequate example code. Pub.dev awards points for having runnable examples, and good examples significantly improve developer adoption.

## What This Skill Does

1. **Traverses the codebase** to understand the public API
2. **Identifies key use cases** based on exported classes and functions
3. **Generates runnable examples** that demonstrate real-world usage
4. **Ensures pub.dev compliance** with proper example structure
5. **Creates educational content** that helps developers get started quickly

## Workflow

### Phase 1: Codebase Analysis

Gather comprehensive understanding of the package:

1. **Read pubspec.yaml**
   - Package name, description, version
   - Dependencies (to understand ecosystem)
   - SDK constraints

2. **Identify Public API**
   - Read main library file (`lib/<package>.dart`)
   - List all exports
   - Understand what's exposed to users

3. **Analyze Exported Components**
   - Read each exported file
   - Identify classes, functions, enums, typedefs
   - Extract documentation comments
   - Note constructor signatures and method signatures

4. **Check Existing Examples**
   - List files in `example/` directory
   - Read `example/README.md` if it exists
   - Identify what's already covered vs. gaps

5. **Review README.md**
   - Extract any code snippets already shown
   - Understand the package's intended use cases
   - Note any getting-started guidance

### Phase 2: Use Case Identification

Based on analysis, identify example scenarios:

**Primary Example** (required for pub.dev):
- `example/<package>_example.dart`
- Must be runnable (`dart run example/<package>_example.dart`)
- Should demonstrate the main use case
- Include imports, main function, basic usage

**Secondary Examples** (optional but valuable):
- Common workflows
- Integration patterns
- Advanced features
- Error handling
- Configuration options

**Example Categories to Consider:**
- **Quick Start** - Minimal code to get something working
- **Common Patterns** - Typical usage scenarios
- **Advanced Usage** - Complex features, customization
- **Integration** - Working with other packages
- **CLI Usage** - If package has executables

### Phase 3: Example Generation

Generate examples following these principles:

**Structure Requirements:**
```dart
/// Brief description of what this example demonstrates.
///
/// Run with: `dart run example/<filename>.dart`
library;

import 'package:<package>/<package>.dart';

Future<void> main() async {
  // Example code here
}
```

**Quality Guidelines:**
- Self-contained and runnable
- Include comments explaining each step
- Handle errors gracefully
- Print meaningful output
- Use realistic (not contrived) scenarios
- Follow Effective Dart style

**Pub.dev Compliance:**
- Main example must be at `example/<package>_example.dart`
- File must have a `main()` function
- Must compile without errors
- Should run without requiring external setup

### Phase 4: Example Content Patterns

**Pattern 1: Quick Start Example**
```dart
/// Quick start example for <package>.
///
/// Demonstrates the most basic usage in under 20 lines.
library;

import 'package:<package>/<package>.dart';

void main() {
  // Minimal viable example
  final instance = MainClass();
  final result = instance.primaryMethod();
  print('Result: $result');
}
```

**Pattern 2: Comprehensive Example**
```dart
/// Comprehensive example demonstrating key features of <package>.
///
/// This example shows:
/// - Basic initialization
/// - Common operations
/// - Error handling
/// - Cleanup
library;

import 'package:<package>/<package>.dart';

Future<void> main() async {
  print('=== <Package> Example ===\n');

  // Section 1: Initialization
  print('1. Initializing...');
  final component = Component();

  try {
    // Section 2: Main operations
    print('2. Performing operations...');
    final result = await component.doSomething();
    print('   Result: $result');

    // Section 3: Additional features
    print('3. Advanced features...');
    // ...

  } catch (e) {
    print('Error: $e');
  } finally {
    // Section 4: Cleanup
    print('4. Cleaning up...');
    component.dispose();
  }

  print('\n=== Example Complete ===');
}
```

**Pattern 3: Multiple Scenarios Example**
```dart
/// Examples of different <package> use cases.
library;

import 'package:<package>/<package>.dart';

void main() {
  example1BasicUsage();
  example2WithOptions();
  example3ErrorHandling();
}

void example1BasicUsage() {
  print('--- Example 1: Basic Usage ---');
  // ...
}

void example2WithOptions() {
  print('--- Example 2: With Options ---');
  // ...
}

void example3ErrorHandling() {
  print('--- Example 3: Error Handling ---');
  // ...
}
```

### Phase 5: Validation

Before finalizing examples:

1. **Syntax Check**
   ```bash
   dart analyze example/
   ```

2. **Run Examples**
   ```bash
   dart run example/<package>_example.dart
   ```

3. **Format Check**
   ```bash
   dart format example/
   ```

4. **Documentation Review**
   - Comments are clear and helpful
   - Output is meaningful
   - Code demonstrates actual features

### Phase 6: Update Supporting Files

**Update example/README.md:**
```markdown
# Examples

## Quick Start

```bash
dart run example/<package>_example.dart
```

## Available Examples

| File | Description |
|------|-------------|
| `<package>_example.dart` | Main example - demonstrates core functionality |
| `advanced_example.dart` | Advanced features and customization |

## Running Examples

All examples can be run directly:

```bash
cd example
dart run <filename>.dart
```

Or from the project root:

```bash
dart run example/<filename>.dart
```
```

## Output Format

When generating examples, provide:

1. **Summary of Analysis**
   - Public API components identified
   - Existing examples found
   - Gaps identified

2. **Proposed Examples**
   - List of example files to create
   - Brief description of each
   - Key features demonstrated

3. **Generated Code**
   - Complete, runnable example files
   - Proper formatting and documentation

4. **Validation Results**
   - Analysis passes
   - Examples run successfully
   - Any warnings or suggestions

## Example Selection Criteria

Prioritize examples that:
- **Demonstrate primary use case** - What most users need
- **Are self-contained** - No external setup required
- **Show realistic usage** - Not contrived scenarios
- **Include error handling** - Production-ready patterns
- **Are educational** - Help users learn the API

Avoid examples that:
- Require complex setup (databases, servers, etc.)
- Depend on external resources
- Are too simple to be useful
- Are too complex to understand quickly
- Duplicate existing documentation

## Integration with Pub.dev Scoring

This skill directly improves pub.dev scoring:

| Requirement | Points | How This Helps |
|-------------|--------|----------------|
| Example file exists | +10 | Creates `example/<package>_example.dart` |
| Example is valid Dart | Included | Validates syntax and formatting |
| Example demonstrates API | Qualitative | Uses actual public API |
| Documentation quality | Qualitative | Includes helpful comments |

## When to Use

Invoke this skill when:
- Preparing a package for pub.dev publication
- Example directory is empty or has only README
- Existing examples are outdated or incomplete
- Adding new features that need demonstration
- Improving developer onboarding

## Success Criteria

Generated examples should:
- ✅ Compile without errors (`dart analyze`)
- ✅ Run successfully (`dart run`)
- ✅ Demonstrate the public API
- ✅ Include helpful comments
- ✅ Follow Effective Dart style
- ✅ Be realistic and useful
- ✅ Handle errors appropriately
- ✅ Produce meaningful output
