---
description: Test-Driven Development workflow for Dart projects. Generates comprehensive tests using package:test, reviews existing tests, and ensures proper coverage of critical code paths.
---

# Dart Test-Driven Development

Implement comprehensive test coverage for Dart projects following TDD best practices and Dart testing conventions.

## Philosophy

This skill follows a pragmatic TDD approach:
1. **Understand before testing** - Deeply analyze codebase structure and existing patterns
2. **Test what matters** - Focus on critical paths, public APIs, edge cases
3. **Make tests maintainable** - Clear naming, proper organization, DRY principles
4. **Review before writing** - Check existing tests, avoid duplication
5. **User confirmation** - Always ask before executing tests

## Dart Testing Conventions

### Test Organization

Follow Dart's standard test structure:
```
test/
├── unit/                    # Unit tests (optional subdirectory)
│   ├── client_test.dart
│   ├── extractor_test.dart
│   └── cache_test.dart
├── integration/             # Integration tests (optional subdirectory)
│   └── mcp_server_test.dart
└── <component>_test.dart    # Test files mirror lib/ structure
```

**Naming:**
- Test files: `<source_file>_test.dart`
- Test functions: `test('should do something when condition')` or `test('does something')`
- Test groups: `group('ClassName', () { ... })`

**Structure:**
```dart
import 'package:test/test.dart';
import 'package:<package>/src/component.dart';

void main() {
  group('ComponentName', () {
    late ComponentName component; // Declare shared setup
    
    setUp(() {
      // Initialize before each test
      component = ComponentName();
    });
    
    tearDown(() {
      // Cleanup after each test
    });
    
    test('should handle normal case', () {
      expect(component.method(), equals(expectedValue));
    });
    
    test('should throw when invalid input', () {
      expect(() => component.method(null), throwsA(isA<ArgumentError>()));
    });
  });
}
```

### Test Patterns

**Common Matchers:**
```dart
expect(value, equals(expected));
expect(value, isNotNull);
expect(value, isA<Type>());
expect(list, isEmpty);
expect(list, hasLength(3));
expect(list, contains('item'));
expect(() => function(), throwsA(isA<ExceptionType>()));
expect(future, completion(equals(value)));
expect(stream, emitsInOrder([1, 2, 3]));
```

**Async Testing:**
```dart
test('async operation completes', () async {
  final result = await asyncFunction();
  expect(result, equals(expected));
});

test('stream emits values', () async {
  expect(
    stream,
    emitsInOrder([value1, value2, emitsDone]),
  );
});
```

**Mocking (with package:mockito or package:mocktail):**
```dart
import 'package:mocktail/mocktail.dart';

class MockDependency extends Mock implements Dependency {}

test('uses dependency', () {
  final mock = MockDependency();
  when(() => mock.method()).thenReturn(value);
  
  final result = component.usesDependency(mock);
  
  verify(() => mock.method()).called(1);
  expect(result, equals(expected));
});
```

## Workflow

### Phase 1: Context Gathering (Ultrathink)

Before generating any tests, deeply understand:

1. **Codebase Structure**
   - Read `pubspec.yaml` for dependencies and package info
   - List all files in `lib/` to understand architecture
   - Identify public API surface (`lib/<package>.dart` exports)
   - Map out internal implementation (`lib/src/`)

2. **Existing Tests**
   - Check if `test/` directory exists
   - List all `*_test.dart` files
   - Read existing tests to understand patterns and coverage
   - Identify what's already tested vs. gaps

3. **Dependencies Analysis**
   - Check if `package:test` is in `dev_dependencies`
   - Identify if mocking libraries are needed (mockito, mocktail)
   - Check if integration test dependencies exist

4. **Critical Paths Identification**
   - Public API methods (most important)
   - Complex business logic
   - Error handling paths
   - Edge cases (null, empty, boundary conditions)
   - External dependencies (file I/O, network, etc.)

### Phase 2: Test Strategy Planning

Create a test plan covering:

**Unit Tests** (test individual components in isolation)
- Each public class/function
- Private methods if complex
- Error conditions and edge cases
- Null safety and boundary conditions

**Integration Tests** (test component interactions)
- End-to-end workflows
- External dependencies (files, network, databases)
- CLI commands
- Server/client interactions

**Test Priorities:**
1. **Critical** - Public APIs, core business logic, data integrity
2. **Important** - Error handling, edge cases, integration points
3. **Nice-to-have** - Helper functions, simple getters/setters

### Phase 3: Test Review (if tests exist)

If tests already exist:
1. Read all test files thoroughly
2. Assess test quality:
   - Are tests clear and maintainable?
   - Do they follow Dart conventions?
   - Are assertions specific enough?
   - Is setup/teardown used properly?
3. Identify gaps in coverage
4. Suggest improvements:
   - Missing edge cases
   - Better test organization
   - Clearer test names
   - Reduced duplication

### Phase 4: Test Generation

Generate tests following this template:

```dart
import 'package:test/test.dart';
import 'package:<package>/src/component.dart';

/// Tests for [ComponentName]
void main() {
  group('ComponentName', () {
    late ComponentName component;
    
    setUp(() {
      component = ComponentName();
    });
    
    group('methodName', () {
      test('should return expected value for normal input', () {
        final result = component.methodName('input');
        expect(result, equals('expected'));
      });
      
      test('should handle empty input', () {
        expect(() => component.methodName(''), throwsArgumentError);
      });
      
      test('should handle null input', () {
        expect(() => component.methodName(null), throwsArgumentError);
      });
    });
  });
}
```

**Test Generation Guidelines:**
- One test file per source file
- Group tests by class/component
- Nested groups for individual methods
- Clear, descriptive test names
- Cover happy path, error cases, edge cases
- Use appropriate matchers
- Keep tests focused (one assertion per test when possible)
- Add comments for complex test logic

### Phase 5: Test Configuration

Ensure proper setup:

**pubspec.yaml:**
```yaml
dev_dependencies:
  test: ^1.25.0
  # Add if needed:
  # mocktail: ^1.0.0
  # mockito: ^5.4.0
```

**test/README.md** (optional but recommended):
```markdown
# Tests

## Running Tests

```bash
# All tests
dart test

# Specific file
dart test test/client_test.dart

# With coverage
dart test --coverage=coverage
dart pub global activate coverage
dart pub global run coverage:format_coverage --packages=.dart_tool/package_config.json --report-on=lib --in=coverage --out=coverage/lcov.info --lcov
```

## Test Organization

- `test/unit/` - Unit tests for individual components
- `test/integration/` - Integration tests for workflows
```

### Phase 6: User Confirmation & Execution

**Always ask user before running tests:**

"I've generated the following tests:
- `test/component_test.dart` - Unit tests for Component (12 tests)
- `test/integration/workflow_test.dart` - Integration tests (5 tests)

Would you like me to:
1. Run all tests
2. Run specific tests
3. Just save the tests without running
4. Review tests first

Type your choice (1-4):"

**When user confirms, run:**
```bash
# Add test dependency if needed
dart pub add test --dev

# Run tests
dart test

# Or specific file
dart test test/component_test.dart

# With verbose output
dart test --reporter=expanded
```

**Report results:**
- Number of tests passed/failed
- Any failures with details
- Coverage summary if available
- Suggestions for fixing failures

## Test Quality Checklist

Generated tests should:
- ✅ Follow Dart naming conventions (`component_test.dart`)
- ✅ Use `package:test` properly (groups, setUp/tearDown)
- ✅ Have clear, descriptive test names
- ✅ Cover happy path, error cases, edge cases
- ✅ Use specific matchers (not just `isTrue`)
- ✅ Be maintainable (DRY, clear setup)
- ✅ Test behavior, not implementation
- ✅ Be fast and isolated (no external dependencies in unit tests)
- ✅ Include comments for complex logic
- ✅ Follow AAA pattern (Arrange, Act, Assert)

## What to Test

**High Priority:**
- Public API methods
- Complex algorithms
- Error handling
- Null safety boundaries
- Data transformations
- Critical business logic

**Medium Priority:**
- Integration between components
- File I/O operations
- Network requests
- CLI commands
- Configuration parsing

**Low Priority:**
- Simple getters/setters
- Trivial helper functions
- Generated code
- Third-party library wrappers (if thin)

## What NOT to Test

Avoid testing:
- Private methods directly (test through public API)
- Third-party library functionality
- Generated code (unless custom logic added)
- Framework features (trust the framework)
- Trivial code (simple assignments, getters)

## Example Test Structure for pubdev_mcp_bridge

```dart
test/
├── client/
│   └── pubdev_client_test.dart        # Tests API client
├── extractor/
│   ├── dart_metadata_extractor_test.dart
│   └── extractor_test.dart
├── cache/
│   └── cache_manager_test.dart
├── server/
│   └── mcp_server_test.dart
├── models/
│   └── package_doc_test.dart
└── integration/
    ├── extract_workflow_test.dart      # Full extraction flow
    └── serve_workflow_test.dart        # Server startup and tool calls
```

## Common Dart Testing Patterns

**Testing Futures:**
```dart
test('async method completes', () async {
  final result = await asyncMethod();
  expect(result, equals(expected));
});
```

**Testing Streams:**
```dart
test('stream emits values', () {
  expect(stream, emitsInOrder([1, 2, 3, emitsDone]));
});
```

**Testing Exceptions:**
```dart
test('throws on invalid input', () {
  expect(() => method(null), throwsA(isA<ArgumentError>()));
});
```

**Setup/Teardown:**
```dart
group('Component', () {
  late Component component;
  late Directory tempDir;
  
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp();
    component = Component(tempDir.path);
  });
  
  tearDown(() async {
    await tempDir.delete(recursive: true);
  });
  
  test('uses temp directory', () {
    // Tests run with fresh temp dir each time
  });
});
```

## Success Criteria

A successful TDD implementation will:
- Cover all critical code paths
- Follow Dart testing conventions
- Be maintainable and readable
- Run fast (< 1s for unit tests)
- Be isolated (no shared state)
- Provide clear failure messages
- Give user control over execution
- Include both unit and integration tests where appropriate
