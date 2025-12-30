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

# Analyze code
flutter analyze

# Format code
dart format lib/
```

## Architecture

flutter_md is a high-performance Markdown parser and renderer built for Flutter. Key architectural patterns:

### Parser Layer (`lib/src/parser.dart`)
- **MarkdownDecoder**: Batch parser - converts full markdown string to `Markdown`
- **StreamingMarkdownDecoder**: Incremental parser for LLM output - maintains state across `append()` calls, only re-parses open blocks
- Core parsing uses `_parseMarkdownLines()` shared by both decoders
- Inline span parsing uses code unit iteration with bitmask for styles

### AST Layer (`lib/src/nodes.dart`)
- **MD$Block**: Sealed class hierarchy with 8 types: Paragraph, Heading, Quote, Code, List, Divider, Table, Spacer
- All blocks use `map<T>()` and `maybeMap<T>()` pattern for type-safe handling
- **MD$Span**: Inline text with style bitmask
- **MD$Style**: Extension type using bitmask (`MD$Style.bold | MD$Style.italic`) - allows combining styles

### Rendering Layer (`lib/src/render.dart`)
- **MarkdownRenderObject**: RenderBox that owns `MarkdownPainter`
- **MarkdownPainter**: Orchestrates layout/paint, manages `BlockPainter` instances
- **BlockPainter**: Interface with implementations for each block type (`BlockPainter$Paragraph`, `BlockPainter$Heading`, etc.)
- Each block painter handles its own layout and painting via Canvas API
- Theme callbacks: `blockFilter`, `spanFilter`, `builder` for customization

### Theme Layer (`lib/src/theme.dart`)
- **MarkdownThemeData**: Theme configuration with text styles, colors, callbacks
- **MarkdownTheme**: InheritedWidget for theme propagation
- `textStyleFor(MD$Style)` returns appropriate TextStyle based on style bitmask

### Widget Layer (`lib/src/widget.dart`)
- **MarkdownWidget**: LeafRenderObjectWidget that creates `MarkdownRenderObject`
- Integrates with `MarkdownTheme` or falls back to Flutter's `DefaultTextStyle`

## Key Patterns

1. **Style bitmask**: `MD$Style` uses bitwise operations - `style.contains(MD$Style.bold)`, `style.add(MD$Style.italic)`

2. **Type-safe block handling**: Use `block.map(paragraph: ..., heading: ..., ...)` to handle sealed class variants

3. **Custom rendering**: Provide `MarkdownThemeData(builder: (block, theme) => ...)` to replace default painters

4. **Filtering**: Use `blockFilter` to exclude blocks, `spanFilter` to exclude inline elements

5. **Streaming**: `StreamingMarkdownDecoder.append(chunk)` incrementally updates, ideal for real-time LLM display
