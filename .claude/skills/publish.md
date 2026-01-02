---
description: Complete workflow for publishing pubdev_mcp_bridge to pub.dev, including pre-publication checklist, publication steps, and post-publication tasks.
---

# Publishing to pub.dev

Guide the user through the complete publication workflow for `pubdev_mcp_bridge`.

## Pre-Publication Checklist

Run through this checklist before publishing:

### Required Files
- [ ] **pubspec.yaml** - Verify all metadata is current
  - Package name, description (60-180 chars)
  - Version follows semantic versioning
  - SDK constraint is `^3.7.0` or higher
  - Repository, homepage, issue tracker URLs are correct
  - Topics are relevant
  - Executables are defined
- [ ] **README.md** - Comprehensive user guide with examples
- [ ] **CHANGELOG.md** - Updated with latest version changes
- [ ] **LICENSE** - MIT License with correct copyright year
- [ ] **example/** - Working usage examples

### Code Quality
- [ ] Run `dart format .` - All code formatted
- [ ] Run `dart analyze --fatal-infos` - No analysis issues
- [ ] All public APIs have documentation comments

### Package Validation
- [ ] Run `dart pub publish --dry-run` - Passes validation
- [ ] Check package size (should be under 10 MB)
- [ ] All dependencies use appropriate version constraints

### Testing
- [ ] Manual test all CLI commands:
  - `pubdev_mcp_bridge serve <package>`
  - `pubdev_mcp_bridge extract <package>`
  - `pubdev_mcp_bridge list`
  - `pubdev_mcp_bridge clean <package>`
- [ ] Test global installation:
  ```bash
  dart pub global activate --source path .
  pubdev_mcp_bridge --help
  ```

## Publication Steps

### 1. Update Version
Update version in `pubspec.yaml` following semantic versioning:
- **Major (X.0.0)**: Breaking changes
- **Minor (x.Y.0)**: New features, backwards-compatible
- **Patch (x.y.Z)**: Bug fixes, backwards-compatible

### 2. Update CHANGELOG.md
Add new version entry with:
- Version number and release date
- Added features
- Changed behavior
- Deprecated features
- Removed features
- Fixed bugs
- Security updates

### 3. Create Release Branch
```bash
git checkout -b release/vX.Y.Z
git add .
git commit -m "chore: bump version to X.Y.Z with updated documentation"
git push origin release/vX.Y.Z
```

### 4. Create Pull Request
Create the PR using the GitHub CLI:
```bash
gh pr create --base main --head release/vX.Y.Z \
  --title "Release vX.Y.Z" \
  --body "## Changes in vX.Y.Z

$(cat CHANGELOG.md | sed -n '/## \[X.Y.Z\]/,/## \[/p' | head -n -1)"
```

If GitHub CLI is not available, guide the user to create the PR manually at the repository URL.

**⛔ STOP: Human Review Required**

DO NOT proceed further. DO NOT merge the PR locally or via CLI.

The user must:
1. Review the PR on GitHub
2. Address any code reviewer feedback  
3. Wait for CI/CD checks to pass
4. **Merge the PR manually on GitHub** (not via CLI)

Ask the user: "Please review and merge the PR on GitHub when ready, then confirm here so I can continue with tagging and publishing."

### 5. Create Git Tag (After User Confirms PR Merged on GitHub)
```bash
git checkout main
git pull origin main
git tag -a vX.Y.Z -m "Release version X.Y.Z"
git push origin vX.Y.Z
```

### 6. Authenticate with pub.dev
First-time only:
```bash
dart pub login
```

### 7. Final Validation
```bash
dart pub publish --dry-run
```

### 8. Publish
```bash
dart pub publish
```

Confirm when prompted.

### 9. Verify Publication
1. Visit https://pub.dev/packages/pubdev_mcp_bridge
2. Verify all information displays correctly
3. Test installation:
   ```bash
   dart pub global activate pubdev_mcp_bridge
   pubdev_mcp_bridge --version
   ```

## Post-Publication Tasks

### 1. Update Repository
Add pub.dev badges to README.md:
```markdown
[![pub package](https://img.shields.io/pub/v/pubdev_mcp_bridge.svg)](https://pub.dev/packages/pubdev_mcp_bridge)
[![package publisher](https://img.shields.io/pub/publisher/pubdev_mcp_bridge.svg)](https://pub.dev/packages/pubdev_mcp_bridge/publisher)
```

### 2. Create GitHub Release
Create release for vX.Y.Z with CHANGELOG content.

### 3. Announce (Optional)
Share in relevant communities:
- Reddit: r/dartlang, r/FlutterDev
- Twitter/X with #dartlang
- Discord: Dart/Flutter communities

## Troubleshooting

### "Package validation failed"
Run `dart pub publish --dry-run` to see specific issues.

### "Authentication failed"
Ensure you're logged in: `dart pub login`

### "Package already exists"
Increment version number in `pubspec.yaml`.

### "Package too large"
Package must be under 10 MB. Add unnecessary files to `.pubignore`.

## Resources
- [Publishing packages](https://dart.dev/tools/pub/publishing)
- [Package layout conventions](https://dart.dev/tools/pub/package-layout)
- [Pubspec format](https://dart.dev/tools/pub/pubspec)
- [Versioning](https://dart.dev/tools/pub/versioning)

## Pub Points Optimization

Target: 160/160 points

- Follow Dart file conventions (10 pts) - LICENSE, README, CHANGELOG
- Provide documentation (10 pts) - Description, README with examples
- Support multiple platforms (20 pts) - macOS, Linux, Windows
- Pass static analysis (50 pts) - No errors/warnings
- Support latest stable SDK (20 pts) - Current SDK constraint
- Use null safety (10 pts) - All code null-safe
- Format code (10 pts) - `dart format`
- Have examples (10 pts) - example/ directory
- Support dependency lower bounds (20 pts) - All dependencies constrained
