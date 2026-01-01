# Teaching Claude to Speak Dart: Building MCP Servers from pub.dev Packages

*How Dart's documentation system makes it uniquely suited for AI-first development*

---

When I started using Claude Code for Dart development, I ran into a frustrating limitation: Claude didn't know the APIs for most Dart packages. Sure, it understood the core SDK, but ask it about any of the 40,000+ packages on pub.dev? You'd get hallucinated method names and outdated information.

I needed a way to give Claude accurate, up-to-date API documentation for any Dart package. That's when I realized Dart's documentation system was already perfectly designed for this—it just needed a bridge to AI assistants.

## Dart's Secret Weapon: Structured Documentation

Dart has one of the best documentation ecosystems in any programming language, and it's built into the language itself.

Every Dart package follows the same conventions:
- Doc comments (`///`) are parsed by tooling, not just displayed as text
- Type information is always available (no dynamic typing ambiguity)
- The `analyzer` package can extract complete API signatures programmatically
- pub.dev enforces documentation scores, incentivizing thorough docs

When you write a Dart class:

```dart
/// A musical note with a [NoteName] and [Accidental].
///
/// Example:
/// ```dart
/// final c = Note.c;
/// final cSharp = Note.c.sharp;
/// ```
class Note {
  /// The name of this note (C, D, E, F, G, A, or B).
  final NoteName noteName;
  
  /// The accidental modifier (sharp, flat, natural, etc.).
  final Accidental accidental;
  
  /// Creates a note with the given [noteName] and [accidental].
  const Note(this.noteName, [this.accidental = Accidental.natural]);
}
```

The Dart toolchain knows:
- The class name, its fields, their types
- Constructor signatures with parameter names and defaults
- Documentation for every public member
- Inheritance hierarchies, implemented interfaces, mixins
- Code examples that can be extracted and tested

This structured metadata is exactly what AI assistants need. Unlike languages where documentation is freeform text, Dart's docs are machine-readable by design.

## The Model Context Protocol: Connecting AI to Documentation

The [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) is an open standard that lets AI assistants access external tools and data sources. Instead of relying on training data, Claude can query live documentation through MCP servers.

The architecture is straightforward:
1. An MCP server exposes "tools" (like API endpoints)
2. Claude connects to the server via JSON-RPC over stdio
3. When Claude needs information, it calls the appropriate tool
4. The tool returns accurate, current data

For Dart packages, this means creating an MCP server that exposes tools like `get_class`, `search`, and `list_methods`. Claude queries the actual API documentation instead of guessing.

Dart's structured documentation makes it ideal for MCP:
- **Complete signatures**: Every method's parameters, return types, and modifiers are available
- **Semantic relationships**: Inheritance, interfaces, and mixins are explicit
- **Searchable content**: Doc comments provide natural language descriptions
- **Consistent format**: All 40,000+ pub.dev packages follow the same structure

## A Real Package: music_notes

To demonstrate, I'll use [music_notes](https://github.com/albertms10/music_notes), a comprehensive Dart library for music theory by [Albert Mora Sánchez](https://github.com/albertms10). It's a perfect test case because:

1. It has rich, well-documented APIs
2. It uses advanced Dart features like dot-shorthands
3. Claude has never seen it (it's not in any training data)

Here's what Claude does without documentation:

```
Me: How do I create a C major chord with music_notes?

Claude: Try using Chord.major('C') or new Chord(['C', 'E', 'G'])

Me: Neither of those work.

Claude: I apologize for the confusion...
```

Claude is guessing based on how other music libraries might work. But music_notes has its own elegant API that Claude can't know without documentation.

## The Technical Challenge: Why Not dartdoc_json?

My first approach was to use `dartdoc_json`, a tool that exports Dart documentation as JSON. It seemed perfect—just run it on any package and feed the JSON to an MCP server.

But `dartdoc_json` has a fundamental limitation: it shells out to `dart doc` internally, which invokes the Dart compiler's documentation generator. This works for stable Dart code, but fails on packages using experimental language features.

The `music_notes` package uses **dot-shorthands**, a Dart feature that allows omitting the enum/class name when the type is known:

```dart
// Traditional syntax
const Note(NoteName.c, Accidental.natural);

// Dot-shorthand syntax (music_notes uses this)
const Note(.c, .natural);
```

When `dartdoc_json` encounters this:

```
Error: This requires the experimental 'dot-shorthands' language feature to be enabled.
```

The entire extraction fails. No partial output, no fallback—just an error.

This isn't a bug in `dartdoc_json`; it's an architectural limitation. Any tool that relies on `dart doc` will fail on experimental features until those features are stabilized and the Dart SDK is updated.

### The Solution: Direct Analyzer Access

The `analyzer` package is Dart's official static analysis library. It's what powers:
- IDE features (autocomplete, go-to-definition, refactoring)
- `dart analyze` command
- Linting tools like `dart fix`

Unlike `dart doc`, the analyzer can be configured to accept experimental features. You can create an `analysis_options.yaml` that enables any experiment:

```yaml
analyzer:
  enable-experiment:
    - dot-shorthands
    - macros
    - enhanced-enums
```

By using the analyzer directly, `pubdev_mcp_bridge` can extract documentation from any package, regardless of what language features it uses.

Here's the core extraction logic:

```dart
final collection = AnalysisContextCollection(
  includedPaths: [packagePath],
  resourceProvider: PhysicalResourceProvider.INSTANCE,
);

for (final context in collection.contexts) {
  for (final filePath in context.contextRoot.analyzedFiles()) {
    if (!filePath.endsWith('.dart')) continue;
    
    final result = await context.currentSession.getResolvedLibrary(filePath);
    if (result is ResolvedLibraryResult) {
      final library = result.element;
      
      // Extract classes
      for (final cls in library.classes) {
        extractClass(cls);  // Gets constructors, methods, fields, docs
      }
      
      // Extract top-level functions, enums, extensions...
    }
  }
}
```

The analyzer gives us everything:
- Full type information (generics, nullable types, function types)
- Doc comments as structured data
- Default parameter values (including dot-shorthands like `.natural`)
- Inheritance chains, mixins, implemented interfaces
- Annotations and metadata

### Comparison: dartdoc_json vs Direct Analyzer

| Aspect | dartdoc_json | Direct Analyzer |
|--------|--------------|-----------------|
| Experimental features | Fails | Full support |
| External dependency | Requires global install | Built-in to project |
| Extraction speed | Slower (spawns process) | Faster (in-process) |
| Control | Limited configuration | Full API access |
| Output format | Fixed JSON schema | Custom extraction |
| Error handling | All-or-nothing | Graceful degradation |

The direct analyzer approach is more work to implement, but it's robust against the entire spectrum of Dart language evolution.

## Building pubdev_mcp_bridge

With the analyzer approach working, I built `pubdev_mcp_bridge`—a CLI that creates MCP servers for any pub.dev package.

### Installation

```bash
git clone https://github.com/yourusername/pubdev_mcp_bridge.git
cd pubdev_mcp_bridge
dart pub get
dart pub global activate --source path .
```

### Creating an MCP Server

```bash
pubdev_mcp_bridge serve music_notes
```

The first run:
1. Downloads `music_notes` from pub.dev
2. Extracts the source code
3. Runs the analyzer on every public API
4. Caches the documentation as JSON
5. Starts an MCP server on stdio

Subsequent runs load from cache instantly.

### Connecting to Claude Code

```bash
claude mcp add music-notes pubdev_mcp_bridge serve music_notes
```

Verify it's working:

```bash
claude mcp list
```

## Claude + music_notes in Action

Now Claude can query the actual documentation:

**Searching for APIs:**
```
Me: Search music_notes for chord-related classes

Claude uses: search(query: "chord")

Results:
- Chord: A musical chord.
- ChordPattern: A musical chord pattern.
- ChordPatternNotation: A notation system for ChordPattern.
```

**Getting class details:**
```
Me: Show me the Note class

Claude uses: get_class(class_name: "Note")

class Note
  extends Scalable<Note>
  implements Comparable<Note>
  with RespellableScalable<Note>

A musical note.

Constructors:
  const Note(NoteName noteName, [Accidental accidental = .natural])
  factory Note.parse(String source)

Fields:
  NoteName noteName
  Accidental accidental
  
Static Fields:
  Note c, Note d, Note e, Note f, Note g, Note a, Note b

Methods:
  Note get sharp
  Note get flat
  Chord<Note> get majorTriad
  Chord<Note> get minorTriad
  Key get major
  Key get minor
  Pitch inOctave(int octave)
  Interval interval(Note other)
  Note transposeBy(Interval interval)
  ...
```

**Now Claude can answer correctly:**
```
Me: How do I create a C major chord with music_notes?

Claude: Based on the music_notes API, there are two ways:

1. Using the Note getter:
   Note.c.majorTriad  // Returns Chord<Note>

2. Constructing directly:
   Chord<Note>([Note.c, Note.e, Note.g])

The Note class has static getters for each note (c, d, e, f, g, a, b)
and properties like .majorTriad, .minorTriad, .diminishedTriad, 
.augmentedTriad for building chords.
```

That's the real API. Claude found it by querying the documentation, not guessing.

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   pub.dev   │────▶│  Extractor  │────▶│    Cache    │
│   (HTTP)    │     │  Pipeline   │     │   (JSON)    │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                               ▼
                    ┌─────────────┐     ┌─────────────┐
                    │   Claude    │◀────│ MCP Server  │
                    │             │     │  (stdio)    │
                    └─────────────┘     └─────────────┘
```

**Extraction Pipeline:**
1. `PubdevClient` downloads the .tar.gz archive from pub.dev
2. `ArchiveHandler` extracts it locally
3. `DartMetadataExtractor` uses `package:analyzer` v9.x to parse every .dart file
4. Documentation is serialized to JSON and cached at `~/.pubdev_mcp_cache/`

**MCP Server:**
- Built on `dart_mcp`, the official Dart MCP SDK
- 11 tools: search, get_class, get_function, get_enum, get_library, get_methods, list_classes, list_functions, list_enums, list_libraries, get_package_info
- JSON-RPC 2.0 over stdio

**Three-Level Caching:**
- `archives/` - Downloaded .tar.gz (skip re-downloading)
- `extracted/` - Unpacked source (skip re-extracting)  
- `docs/` - Parsed JSON (skip re-analyzing)

## Why Dart is Perfect for AI-First Development

This project reinforced my belief that Dart is uniquely positioned for AI-assisted development:

**1. Machine-readable documentation**

Every Dart package has extractable, structured docs. No scraping HTML, no parsing markdown, no guessing at signatures.

**2. Strong typing everywhere**

Claude never has to guess types. Parameters, return values, generics—it's all explicit.

**3. Consistent ecosystem**

pub.dev enforces standards. Every package looks the same to tooling.

**4. Analyzer as a library**

The same tool that powers IDEs is available as a package. You can build anything on top of it.

**5. Growing experimental features**

Dart is evolving rapidly (dot-shorthands, macros, records, patterns). The analyzer keeps up; external tools often don't.

## Get Started

```bash
# Install
git clone https://github.com/yourusername/pubdev_mcp_bridge.git
cd pubdev_mcp_bridge
dart pub get
dart pub global activate --source path .

# Create a server for any package
pubdev_mcp_bridge serve music_notes

# Connect to Claude Code
claude mcp add music-notes pubdev_mcp_bridge serve music_notes
```

The code is open source. Try it with your favorite packages:

```bash
claude mcp add riverpod pubdev_mcp_bridge serve riverpod
claude mcp add freezed pubdev_mcp_bridge serve freezed
claude mcp add drift pubdev_mcp_bridge serve drift
```

---

## Acknowledgments

- [music_notes](https://github.com/albertms10/music_notes) by [Albert Mora Sánchez](https://github.com/albertms10) - the package that inspired this tool's experimental feature support
- [dart_mcp](https://pub.dev/packages/dart_mcp) - official Dart MCP SDK from the Dart team
- [analyzer](https://pub.dev/packages/analyzer) - the foundation that makes this possible

---

*Questions or feedback? Open an issue on GitHub.*
