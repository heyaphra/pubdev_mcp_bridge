# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
