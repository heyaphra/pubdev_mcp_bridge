---
description: Generate and review Dart tests following TDD best practices with package:test
tools: [mcp__acp__Read, mcp__acp__Write, mcp__acp__Bash, Grep, Glob]
---

Implement comprehensive test coverage for this Dart project using the `tdd-dart` skill.

Follow the TDD workflow:

1. **Ultrathink** - Gather deep context about the codebase structure, existing tests, and critical code paths
2. **Review** - If tests exist, analyze their quality and identify gaps
3. **Plan** - Create a test strategy covering unit and integration tests
4. **Generate** - Write tests following Dart conventions with `package:test`
5. **Confirm** - Ask user whether to run tests before executing

Generate tests that:
- Follow Dart naming conventions (`component_test.dart`)
- Use proper test organization (groups, setUp/tearDown)
- Cover happy path, error cases, and edge cases
- Are maintainable and clearly named
- Test behavior, not implementation

Always request user confirmation before running any tests.
