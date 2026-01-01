# Publishing Checklist for pub.dev

This document provides the complete checklist for publishing `pubdev_mcp_bridge` to pub.dev.

## Pre-Publication Checklist

### ✅ Required Files

- [x] **pubspec.yaml** - Complete with all metadata
  - [x] Name: `pubdev_mcp_bridge`
  - [x] Description: 105 characters (within 60-180 range)
  - [x] Version: `2.0.0` (follows semantic versioning)
  - [x] SDK constraint: `^3.5.0`
  - [x] Repository URL: `https://github.com/aphrabehn/pubdev_to_mcp`
  - [x] Homepage URL: `https://github.com/aphrabehn/pubdev_to_mcp`
  - [x] Issue tracker URL: `https://github.com/aphrabehn/pubdev_to_mcp/issues`
  - [x] Topics: mcp, documentation, pub-dev, code-generation, ai
  - [x] Executables: `pubdev_mcp_bridge`

- [x] **README.md** - Comprehensive user guide
  - [x] Project description
  - [x] Features list
  - [x] Installation instructions (from pub.dev and source)
  - [x] Quick start guide
  - [x] Usage examples
  - [x] API documentation
  - [x] Development guide

- [x] **CHANGELOG.md** - Version history
  - [x] Follows Keep a Changelog format
  - [x] Documents all changes in 2.0.0
  - [x] Includes release dates

- [x] **LICENSE** - MIT License
  - [x] Copyright notice: Aphra Bloomfield 2025
  - [x] Full MIT license text

- [x] **example/** - Usage examples
  - [x] example/README.md with comprehensive examples

### ✅ Code Quality

- [x] **Formatting**: All code formatted with `dart format`
  ```bash
  dart format .
  # Result: Formatted 16 files (0 changed)
  ```

- [x] **Analysis**: No analysis issues
  ```bash
  dart analyze --fatal-infos
  # Result: No issues found!
  ```

- [x] **Documentation**: All public APIs documented
  - [x] Library-level documentation in `lib/pubdev_mcp_bridge.dart`
  - [x] Class and method documentation

### ✅ Package Validation

- [x] **Dry-run validation passed**
  ```bash
  dart pub publish --dry-run
  # Result: Package has 1 warning (uncommitted changes - expected)
  ```

- [x] **Package size**: 84 KB compressed (well under 10 MB limit)

- [x] **Dependencies**: All dependencies use appropriate version constraints
  - analyzer: ^9.0.0
  - args: ^2.4.0
  - archive: ^4.0.0
  - dart_mcp: ^0.2.0
  - http: ^1.1.0
  - path: ^1.8.0
  - stream_channel: ^2.1.0

### ✅ Testing

- [x] **Manual testing**: CLI commands work correctly
  - [x] `pubdev_mcp_bridge serve <package>`
  - [x] `pubdev_mcp_bridge extract <package>`
  - [x] `pubdev_mcp_bridge list`
  - [x] `pubdev_mcp_bridge clean <package>`

- [x] **Global installation**: Can be installed and run globally
  ```bash
  dart pub global activate --source path .
  pubdev_mcp_bridge --help
  ```

## Publication Steps

### 1. Commit All Changes

```bash
git add .
git commit -m "chore: prepare for pub.dev publication

- Add CHANGELOG.md
- Add example/ directory with comprehensive examples
- Update pubspec.yaml with repository, homepage, issue_tracker, and topics
- Update README.md with pub.dev installation instructions
- Add PUBLISHING.md checklist
"
```

### 2. Create Git Tag

```bash
git tag -a v2.0.0 -m "Release version 2.0.0"
git push origin main
git push origin v2.0.0
```

### 3. Verify Repository

Ensure the GitHub repository is public and accessible:
- URL: https://github.com/aphrabehn/pubdev_to_mcp
- Public visibility
- Contains all source code

### 4. Authenticate with pub.dev

```bash
# First-time authentication
dart pub login
```

You'll be prompted to sign in with your Google Account. Follow the browser authentication flow.

### 5. Publish to pub.dev

```bash
# Final validation
dart pub publish --dry-run

# Publish for real
dart pub publish
```

You'll be asked to confirm:
```
Publishing pubdev_mcp_bridge 2.0.0 to https://pub.dev:

Uploading...
Successfully uploaded package.
```

### 6. Verify Publication

1. Visit https://pub.dev/packages/pubdev_mcp_bridge
2. Check that all information displays correctly:
   - Description
   - README renders properly
   - CHANGELOG shows version history
   - Example code is visible
   - Repository links work
   - Topics are displayed

3. Test installation:
   ```bash
   dart pub global activate pubdev_mcp_bridge
   pubdev_mcp_bridge --version
   ```

### 7. Post-Publication

1. **Update repository README**: Add pub.dev badges
   ```markdown
   [![pub package](https://img.shields.io/pub/v/pubdev_mcp_bridge.svg)](https://pub.dev/packages/pubdev_mcp_bridge)
   [![package publisher](https://img.shields.io/pub/publisher/pubdev_mcp_bridge.svg)](https://pub.dev/packages/pubdev_mcp_bridge/publisher)
   ```

2. **Create GitHub Release**: Create a release on GitHub for v2.0.0 with the same content as CHANGELOG.md

3. **Announce**: Share the package in relevant communities
   - Reddit: r/dartlang, r/FlutterDev
   - Twitter/X with #dartlang hashtag
   - Discord: Dart/Flutter communities

## Updating the Package

For future updates:

1. Update version in `pubspec.yaml` (follow semantic versioning)
2. Update `CHANGELOG.md` with new changes
3. Commit changes: `git commit -am "chore: bump version to X.Y.Z"`
4. Create tag: `git tag -a vX.Y.Z -m "Release version X.Y.Z"`
5. Push: `git push origin main && git push origin vX.Y.Z`
6. Publish: `dart pub publish`

## Semantic Versioning Guide

- **Major (X.0.0)**: Breaking changes, incompatible API changes
- **Minor (x.Y.0)**: New features, backwards-compatible
- **Patch (x.y.Z)**: Bug fixes, backwards-compatible

## Troubleshooting

### "Package validation failed"

Run `dart pub publish --dry-run` to see specific issues.

### "Authentication failed"

Ensure you're logged in: `dart pub login`

### "Package already exists"

You cannot publish a version that already exists. Increment the version number in `pubspec.yaml`.

### "Package too large"

The package must be under 10 MB compressed. Remove unnecessary files or add them to `.pubignore`.

## Additional Resources

- [Publishing packages](https://dart.dev/tools/pub/publishing)
- [Package layout conventions](https://dart.dev/tools/pub/package-layout)
- [Pubspec format](https://dart.dev/tools/pub/pubspec)
- [Versioning](https://dart.dev/tools/pub/versioning)

## Pub Points Checklist (Max 160 points)

To maximize pub points:

- [x] **Follow Dart file conventions** (10 points)
  - [x] LICENSE file exists
  - [x] README.md exists
  - [x] CHANGELOG.md exists

- [x] **Provide documentation** (10 points)
  - [x] Package description in pubspec.yaml (60-180 chars)
  - [x] README.md with examples

- [x] **Support multiple platforms** (20 points)
  - [x] Works on macOS, Linux, Windows

- [x] **Pass static analysis** (50 points)
  - [x] No errors or warnings from `dart analyze`

- [x] **Support latest stable SDK** (20 points)
  - [x] SDK constraint: `^3.5.0`

- [x] **Use null safety** (10 points)
  - [x] All code uses null safety

- [x] **Format code** (10 points)
  - [x] All files formatted with `dart format`

- [x] **Have examples** (10 points)
  - [x] example/ directory exists

- [x] **Support dependency constraint lower bounds** (20 points)
  - [x] All dependencies have lower bounds

**Estimated Score: 160/160 points** ✅

---

**Status**: Ready for publication ✅

All requirements met. Package is ready to be published to pub.dev.
