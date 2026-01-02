---
description: Comprehensive Dart code review with deep analysis of Effective Dart guidelines, null safety patterns, pub.dev best practices, and architecture quality.
---

# Dart Code Review

Conduct a thorough, expert-level code review of Dart code with focus on:
- Effective Dart guidelines (Style, Documentation, Usage, Design)
- Null safety patterns and best practices
- Pub.dev scoring optimization (160/160 points)
- Architecture and design patterns
- Performance and error handling
- Test coverage and quality

## Review Scope

The review should analyze:

### Code Quality
- **Effective Dart compliance** - All four pillars (Style, Documentation, Usage, Design)
- **Null safety** - Proper use of `?`, `late`, `required`, avoiding `!`
- **Error handling** - Typed exceptions, proper `rethrow`, async error handling
- **Performance** - `const` usage, unnecessary allocations, collection literals
- **Naming conventions** - `lowerCamelCase`, `UpperCamelCase`, meaningful names

### Architecture
- **Separation of concerns** - Single Responsibility Principle
- **Abstraction layers** - Proper use of interfaces and implementations
- **Dependency management** - Dependency injection, loose coupling
- **Public API design** - Minimal, intuitive, well-documented surface area
- **Library structure** - Proper use of `lib/`, `lib/src/`, exports

### Documentation
- **Public API docs** - All public APIs have `///` documentation
- **README.md** - Comprehensive guide with examples
- **CHANGELOG.md** - Up to date with semantic versioning
- **Code comments** - Clear, non-redundant, explain "why" not "what"
- **Examples** - Working code in `example/` directory

### Package Quality (for pub.dev)
- **pubspec.yaml** - Complete metadata, proper versioning, dependencies
- **analysis_options.yaml** - Strict lints enabled
- **Static analysis** - Zero errors/warnings/infos with `--fatal-infos`
- **Formatting** - `dart format` produces no changes
- **Pub points** - Path to 160/160 score

### Testing
- **Coverage** - Critical paths have tests
- **Test organization** - Proper `test/` structure, `_test.dart` naming
- **Test quality** - Descriptive names, proper assertions, edge cases
- **Test patterns** - Groups, matchers, async test handling

## Review Process

### Phase 1: Context Gathering

First, understand the codebase structure:
1. Read `pubspec.yaml` for package overview
2. Read `README.md` to understand purpose
3. List files in `lib/`, `lib/src/`, `test/`, `example/`
4. Identify main entry points and public APIs

### Phase 2: Static Analysis

Run automated checks:
```bash
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
dart pub publish --dry-run  # if preparing for publication
```

### Phase 3: Deep Code Review

Systematically review each component:
- Read source files in logical order (dependencies first)
- Check against Effective Dart guidelines
- Identify antipatterns and opportunities
- Assess architecture and design decisions

### Phase 4: Documentation Review

Verify documentation completeness:
- All public APIs have doc comments
- README has clear examples
- CHANGELOG follows format
- Code examples are tested and work

### Phase 5: Test Review

Analyze test coverage and quality:
- Critical functionality is tested
- Tests are maintainable
- Edge cases are covered
- Integration and unit tests are balanced

## Output Format

Structure the review as follows:

### Executive Summary
2-3 sentence overview of code quality and readiness

### Critical Issues 🔴
Must-fix issues that block publication or cause bugs

### Warnings ⚠️
Should-fix issues that impact maintainability or best practices

### Suggestions 💡
Nice-to-have improvements and optimizations

### Effective Dart Compliance
Specific violations with links to guidelines:
- Style issues
- Documentation gaps
- Usage problems
- Design concerns

### Null Safety Review
Assessment of null safety patterns and recommendations

### Architecture Assessment
High-level design evaluation:
- Strengths
- Areas for improvement
- Refactoring opportunities

### Documentation Quality
Completeness and clarity of documentation

### Test Coverage Analysis
What's tested, what's missing, test quality

### Pub Points Analysis (if applicable)
Current estimated score breakdown and path to 160/160:
- ✅ What's already correct
- ⚠️ What needs fixing
- Current estimated score: X/160

### Positive Observations ✅
Always acknowledge what the code does well

### Actionable Next Steps
Prioritized list of recommended changes

## Invocation

This skill should be invoked by the `dart-code-reviewer` subagent, which has specialized expertise in:
- Effective Dart guidelines (all four pillars)
- Dart language features and idioms
- Pub.dev scoring criteria
- Common Dart antipatterns
- Performance optimization patterns
- Null safety best practices

The subagent will "ultrathink" through the review, taking time to:
1. Thoroughly understand the codebase
2. Cross-reference against Dart best practices
3. Identify subtle issues and opportunities
4. Provide educational, constructive feedback
5. Balance criticism with recognition

## When to Use

Invoke this review:
- **Before publication** - Ensure pub.dev readiness
- **Before major releases** - Catch issues early
- **After significant refactoring** - Validate architecture
- **During PR review** - Get expert second opinion
- **When learning Dart** - Identify areas for improvement

## Example Usage

User invokes:
```
/code-review:dart
```

Or explicitly:
```
Review the MCP server implementation in lib/src/server/ for Effective Dart compliance and pub.dev readiness
```

The dart-code-reviewer subagent will:
1. Gather full codebase context
2. Run static analysis tools
3. Perform deep manual review
4. Provide comprehensive, actionable feedback
5. Suggest concrete improvements with code examples

## Success Criteria

A successful review will:
- Identify all Effective Dart violations
- Catch potential bugs and edge cases
- Suggest architecture improvements
- Provide clear, actionable recommendations
- Include code examples for fixes
- Link to authoritative Dart documentation
- Balance criticism with positive observations
- Prioritize issues by severity
