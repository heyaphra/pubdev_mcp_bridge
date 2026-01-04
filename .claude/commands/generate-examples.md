---
description: Traverse the Dart codebase and generate comprehensive, runnable examples in the example/ directory
tools: [mcp__acp__Read, mcp__acp__Write, mcp__acp__Bash, Glob, Grep]
---

Generate comprehensive, runnable examples for this Dart package using the `generate-examples` skill.

## Task

Analyze the codebase and create example files that:
1. Demonstrate the public API
2. Are runnable with `dart run`
3. Follow pub.dev requirements
4. Help developers get started quickly

## Process

### Step 1: Analyze the Codebase

First, gather context:
- Read `pubspec.yaml` to understand the package
- Read the main library file (`lib/<package>.dart`) to identify exports
- Read exported source files to understand the public API
- Check existing `example/` directory contents
- Review `README.md` for documented use cases

### Step 2: Identify Key Examples to Generate

Based on analysis, determine:
- **Primary example**: `example/<package>_example.dart` (required)
- **Additional examples**: Based on distinct features/use cases

### Step 3: Generate Example Files

Create runnable examples that:
- Import the package correctly
- Have a `main()` function
- Include helpful comments
- Print meaningful output
- Demonstrate realistic usage
- Handle errors appropriately

### Step 4: Validate Examples

Run validation:
```bash
dart analyze example/
dart format example/
dart run example/<package>_example.dart
```

### Step 5: Update example/README.md

Ensure the README documents all examples and how to run them.

## Output

For each generated example, show:
1. File path
2. What it demonstrates
3. The complete code
4. Validation results

## Example Structure

The primary example should follow this pattern:

```dart
/// Brief description of what this example demonstrates.
///
/// Run with: `dart run example/<package>_example.dart`
library;

import 'package:<package>/<package>.dart';

Future<void> main() async {
  print('=== <Package> Example ===\n');
  
  // Example code demonstrating key features
  
  print('\n=== Complete ===');
}
```

## Quality Checklist

Before finalizing, verify:
- [ ] `dart analyze example/` passes with no issues
- [ ] `dart format --output=none --set-exit-if-changed example/` passes
- [ ] Primary example runs successfully
- [ ] Examples demonstrate actual public API usage
- [ ] Comments explain what's happening
- [ ] Output is meaningful and helpful
