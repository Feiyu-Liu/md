# Repository Guidelines

## Project Structure & Module Organization

`lib/flutter_md.dart` is the package's public barrel export. Core implementation
lives in `lib/src/`: parsing and AST types are in `parser.dart`, `markdown.dart`,
and `nodes.dart`; Flutter rendering, widgets, and themes are in `render.dart`,
`widget.dart`, and `theme.dart`; animation support is under
`lib/src/animation/`. Keep public exports deliberate so rendering internals stay
private.

Tests mirror these concerns under `test/parser/`, `test/render/`, and
`test/theme/`, with general coverage in `test/unit_test.dart`. Use `example/`
for manual, cross-platform validation and `benchmark/` for parser performance
checks. Design notes live in `doc/`.

## Build, Test, and Development Commands

- `flutter pub get` installs package dependencies.
- `flutter analyze` runs the repository's strict analyzer and lint rules.
- `dart format --line-length 80 lib test` formats source and tests as CI expects.
- `flutter test` runs the complete test suite.
- `flutter test test/parser/streaming_parser_test.dart` runs one focused file.
- `cd example && flutter run` launches the example application.
- `dart run benchmark/streaming_performance_benchmark.dart` measures incremental
  parsing performance; use it when changing streaming behavior.

## Coding Style & Naming Conventions

Use two-space Dart indentation and an 80-character line width. Follow existing
relative imports inside `lib/src/` and package imports from tests. Public APIs
require `///` documentation. Preserve the established `$` hierarchy naming,
such as `MD$Block`, `MD$Span`, and `BlockPainter$Paragraph`. Prefer immutable
values and `const` constructors where practical. Do not expose implementation
classes from the barrel file without an API-level reason.

## Testing Guidelines

Tests use `flutter_test`. Name files `*_test.dart`, group cases by component,
and describe observable behavior in test names. Parser changes should cover
both complete input and chunked streaming; renderer or theme changes should
add focused widget/painter assertions. Run `flutter analyze` and `flutter test`
before submitting. CI also runs `test/unit_test.dart` with coverage, but no
numeric coverage threshold is configured.

## Commit & Pull Request Guidelines

Recent commits use concise Conventional Commit subjects, for example
`fix: Render closed list items incrementally during streaming` and
`feat: Add tableTextStyle property for table body cells`. Continue with
`feat:`, `fix:`, `test:`, or `docs:` and an imperative summary.

Pull requests should explain the behavior change, link relevant issues, list
verification commands, and include screenshots or recordings for visible
rendering or animation changes. Keep generated platform files and unrelated
formatting out of focused changes.
