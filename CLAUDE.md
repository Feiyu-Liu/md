# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run all tests
flutter test

# Run a single test file
flutter test test/parser/streaming_parser_test.dart

# Run tests with coverage
flutter test --coverage

# Analyze code (strict mode: strict-casts, strict-inference, strict-raw-types)
flutter analyze

# Format code (80-char line width enforced)
dart format lib/

# Run benchmarks
dart run benchmark/parse_benchmark.dart
dart run benchmark/streaming_performance_benchmark.dart

# Run the example app
cd example && flutter run
```

## Code Style

- 80-character line width (enforced by `analysis_options.yaml`)
- `public_member_api_docs: true` — all public members must have doc comments
- Strict analysis: `strict-casts`, `strict-inference`, `strict-raw-types`
- Naming convention uses `$` separator for type hierarchies: `MD$Block`, `MD$Span`, `MD$Style`, `BlockPainter$Paragraph`, etc.
- `always_use_package_imports` is an error — use `package:flutter_md/...` not relative paths for imports

## Architecture

`flutter_md` is a streaming-first Markdown parser and renderer for Flutter, optimized for displaying LLM output in real time.

### Library Entry Point (`lib/flutter_md.dart`)

Barrel file that exports all public API. Notable: `render.dart` exports only `BlockPainter` (the interface), keeping rendering internals private.

### Parser Layer (`lib/src/parser.dart`)
- **MarkdownDecoder**: Batch parser — converts full markdown string to `Markdown`
- **StreamingMarkdownDecoder**: Incremental parser for LLM output — maintains state across `append()` calls, only re-parses open blocks
- Core parsing uses `_parseMarkdownLines()` shared by both decoders
- Inline span parsing uses code unit iteration with bitmask for styles

### AST Layer (`lib/src/nodes.dart`)
- **MD$Block**: Sealed class hierarchy with 8 types: Paragraph, Heading, Quote, Code, List, Divider, Table, Spacer
- All blocks use `map<T>()` and `maybeMap<T>()` pattern for type-safe handling
- **MD$Span**: Inline text with style bitmask
- **MD$Style**: Extension type using bitmask (`MD$Style.bold | MD$Style.italic`) — allows combining styles

### Markdown Entity (`lib/src/markdown.dart`)
- **Markdown**: Immutable value class holding the list of `MD$Block` nodes
- Created by both `MarkdownDecoder.convert()` and `StreamingMarkdownDecoder.append()`

### Theme Layer (`lib/src/theme.dart`)
- **MarkdownThemeData**: Theme configuration implementing `ThemeExtension<MarkdownThemeData>` — text styles, colors, callbacks, filters, custom builders
- **MarkdownTheme**: InheritedWidget for theme propagation
- `textStyleFor(MD$Style)` returns appropriate TextStyle based on style bitmask

### Animation Layer (`lib/src/animation/`)
- **MarkdownAnimationConfig**: Configurable block animations (opacity, offset, blur) with auto-disable on streaming completion
- **AnimatedBlockPainter**: Decorator wrapping any `BlockPainter` with animation effects via Canvas saveLayer/translate

### Rendering Layer (`lib/src/render.dart`, ~2500 lines)
- **MarkdownRenderObject**: RenderBox that owns `MarkdownPainter`
- **MarkdownPainter**: Orchestrates layout/paint, manages `BlockPainter` instances and animation lifecycle
- **BlockPainter**: Interface with implementations for each block type (`BlockPainter$Paragraph`, `BlockPainter$Heading`, etc.)
- Each block painter handles its own layout and painting via Canvas API
- Theme callbacks: `blockFilter`, `spanFilter`, `builder` for customization

### Widget Layer (`lib/src/widget.dart`)
- **MarkdownWidget**: LeafRenderObjectWidget that creates `MarkdownRenderObject`
- Accepts `MarkdownAnimationConfig` and `isStreamingComplete` `ValueNotifier` for animation control
- Integrates with `MarkdownTheme` or falls back to Flutter's `DefaultTextStyle`

## Key Patterns

1. **Style bitmask**: `MD$Style` uses bitwise operations — `style.contains(MD$Style.bold)`, `style.add(MD$Style.italic)`

2. **Type-safe block handling**: Use `block.map(paragraph: ..., heading: ..., ...)` to handle sealed class variants

3. **Custom rendering**: Provide `MarkdownThemeData(builder: (block, theme) => ...)` to replace default painters

4. **Filtering**: Use `blockFilter` to exclude blocks, `spanFilter` to exclude inline elements

5. **Streaming**: `StreamingMarkdownDecoder.append(chunk)` incrementally updates — tracks line states (open/closed), only re-parses from `_firstOpenIndex`

6. **Decorator pattern**: `AnimatedBlockPainter` wraps any `BlockPainter` to add animation without modifying the inner painter

## Dependencies

- `highlight` — syntax highlighting for fenced code blocks (Dart, JS, TS, JSON, YAML, XML, Bash)
- `meta` — `@internal` annotations
- Dev: `markdown` package used solely for benchmarking comparison

## Test Structure

```
test/
├── unit_test.dart                          # General tests
├── parser/
│   ├── parser_test.dart                    # Batch parsing
│   └── streaming_parser_test.dart          # Streaming parser (18 tests)
├── render/
│   ├── code_painter_test.dart              # Code block rendering
│   └── table_painter_test.dart             # Table rendering
└── theme/
    └── markdown_theme_test.dart            # Theme system
```
