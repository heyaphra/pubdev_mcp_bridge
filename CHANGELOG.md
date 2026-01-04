# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.5] - 2025-01-03

### Added
- Added comprehensive example files demonstrating package usage
  - `example/pubdev_mcp_bridge_example.dart`: Primary example showing core API usage
  - `example/cache_example.dart`: Cache management demonstration
  - `example/client_example.dart`: PubdevClient usage examples
- Added generate-examples skill and slash command for automated example generation

## [2.0.4] - 2025-01-02

### Fixed
- Fixed support for Dart workspace packages (riverpod, jaspr, etc.)
  - Workspace packages now extract successfully by stripping `resolution: workspace` from pubspec.yaml files
  - This fix allows proper dependency resolution from pub.dev for packages developed in monorepos
  - Affected packages: riverpod, flutter_riverpod, hooks_riverpod, jaspr, and other workspace-based packages

## [2.0.3] - 2025-01-02

### Added
- Added .pubignore to exclude development files from published package
- Added CLAUDE.md with project overview and development guidelines
- Added CONTRIBUTING.md with architecture details and contribution guidelines
- Added doc/TUTORIAL.md with comprehensive usage guide
- Added example/README.md with example usage

### Changed
- Updated README.md with improved documentation and examples
- Improved package metadata and topics

### Removed
- Removed PUBLISHING.md from published package (now in .pubignore)
- Removed firebase-debug.log from published package

## [2.0.2] - 2025-01-01

### Fixed
- Resolved static analysis linting issues
- Added curly braces around all control flow statements
- Added analysis_options.yaml for consistent linting
- Formatted code with dart format

## [2.0.1] - 2025-01-01

### Fixed
- Updated SDK constraint from ^3.5.0 to ^3.7.0 to match dart_mcp requirement
- Tightened all dependency constraints to resolve pub.dev downgrade analysis issues
- Updated dart_mcp constraint from ^0.2.0 to ^0.4.0

## [2.0.0] - 2025-01-01

### Changed
- Complete rewrite using `package:analyzer` for direct source code analysis
- Replaced dartdoc_json-based extraction with analyzer-based extraction
- Support for experimental Dart features (dot-shorthands, macros, records, etc.)
- Generic MCP server architecture (no code generation required)
- Three-level caching system (archives, extracted sources, documentation JSON)

### Added
- 11 MCP tools: search, get_class, get_function, get_enum, get_library, get_methods, list_classes, list_functions, list_enums, list_libraries, get_package_info
- CLI commands: serve, extract, list, clean
- Automatic generation of analysis_options.yaml with experimental features enabled
- Package version selection support
- Cache refresh functionality
- Comprehensive error handling and user feedback

### Removed
- Code generation pipeline (replaced with runtime JSON loading)
- Dependency on dartdoc_json
- Per-package generated Dart projects

## [1.0.0] - Initial Release

### Added
- Initial implementation with dartdoc_json-based extraction
- Code generation for per-package MCP servers
- Basic caching functionality
