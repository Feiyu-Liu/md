# Markdown Text Selection: Primary-Source Research

## Conclusion

There is not one universally best implementation independent of the renderer's
future direction.

- **Best incremental architecture for this package:** preserve the custom
  renderer, wrap its selectable content in a `SelectionContainer`, use a custom
  `MultiSelectableSelectionContainerDelegate`, and expose private selectable
  fragments for laid-out text. This follows Flutter's aggregation protocol
  while retaining the package's streaming, animation, table, and custom
  painting behavior.
- **Best long-term architecture for minimizing selection maintenance:** migrate
  text-producing blocks toward native `RichText`/`RenderParagraph`. Flutter then
  owns selection geometry, handles, events, and evolving platform behavior.
  This is a substantially larger renderer rewrite and must first prove that it
  does not regress streaming performance, layout, tables, or animation.

A hand-written pointer-drag and clipboard implementation is not recommended. It
would duplicate Flutter's selection protocol and remain responsible for input
devices, selection handles, keyboard actions, focus, accessibility, bidi text,
text scaling, and future framework changes.

The architecture decision should therefore follow a measured prototype, not be
treated as settled solely from API inspection.

## Flutter's Public Selection Contract

The `RichText` API documentation states that selectable rich text must be under
a `SelectionArea` or `SelectableRegion`, receive the registrar returned by
`SelectionContainer.maybeOf(context)`, and be given a non-null
`selectionColor`.

Source:

- <https://api.flutter.dev/flutter/widgets/RichText-class.html>
- <https://github.com/flutter/flutter/blob/3.41.9/packages/flutter/lib/src/widgets/basic.dart>

Flutter's `Text` widget performs that integration automatically: it consumes
the ambient selection registrar and `DefaultSelectionStyle`, then supplies the
registrar and selection color to its `RichText`. A package widget should aim
for the same caller experience: placing it below `SelectionArea` should be
sufficient.

Source:

- <https://github.com/flutter/flutter/blob/3.41.9/packages/flutter/lib/src/widgets/text.dart>
- <https://api.flutter.dev/flutter/widgets/DefaultSelectionStyle-class.html>

The public low-level protocol is defined by `Selectable` and
`SelectionRegistrant`. The relevant `rendering/selection.dart` source is
byte-identical between Flutter tags `3.29.0` and `3.41.9`, which is useful
evidence that this public seam is stable across those releases. It is still a
protocol that an implementation must maintain correctly, rather than a small
paint-only extension.

Source:

- <https://github.com/flutter/flutter/blob/3.29.0/packages/flutter/lib/src/rendering/selection.dart>
- <https://github.com/flutter/flutter/blob/3.41.9/packages/flutter/lib/src/rendering/selection.dart>
- <https://api.flutter.dev/flutter/rendering/Selectable-mixin.html>
- <https://api.flutter.dev/flutter/rendering/SelectionRegistrant-mixin.html>

## How Flutter Implements Native Text Selection

`RenderParagraph` does not make the entire paragraph one simplistic selectable
surface. It creates and registers private `_SelectableFragment` objects and
uses them to handle selection events, geometry, selected content, and painting.
That is strong precedent for representing the custom Markdown renderer as
laid-out selectable fragments rather than one monolithic coordinator that
reimplements all fragment behavior.

Source:

- <https://github.com/flutter/flutter/blob/3.41.9/packages/flutter/lib/src/rendering/paragraph.dart>

`SelectionContainer` is the framework's aggregation seam.
`MultiSelectableSelectionContainerDelegate` provides the machinery for
coordinating multiple child `Selectable` objects and permits a custom
`compareOrder`, which is important when visual/render order and document order
are not trivially identical.

Its default selected-content behavior concatenates child fragments. Markdown
needs semantic separators such as paragraph newlines, table cell boundaries,
and code-block line breaks, so this package should customize aggregation rather
than assume the default concatenation produces correct clipboard text.

Source:

- <https://api.flutter.dev/flutter/widgets/SelectionContainer-class.html>
- <https://api.flutter.dev/flutter/widgets/MultiSelectableSelectionContainerDelegate-class.html>
- <https://github.com/flutter/flutter/blob/3.41.9/packages/flutter/lib/src/widgets/selectable_region.dart>

## Evidence That Selection Semantics Keep Evolving

Flutter PR #95226 introduced the global selection system. Later work continued
to evolve the protocol:

- PR #154202 added selection ranges and `contentLength`.
- Issue #154253 records newline-copy behavior that required further framework
  maintenance.
- PR #184421 addresses newline handling, but is merged to `master` and is not
  present in stable tag `3.41.9`.
- Open issue #153004 covers difficult selection behavior in complex,
  multi-column layouts.

These are reasons to reuse framework aggregation and native paragraph behavior
where possible. They are also a warning that a custom implementation needs
explicit compatibility tests across the package's supported Flutter versions.

Sources:

- <https://github.com/flutter/flutter/pull/95226>
- <https://github.com/flutter/flutter/pull/154202>
- <https://github.com/flutter/flutter/issues/154253>
- <https://github.com/flutter/flutter/pull/184421>
- <https://github.com/flutter/flutter/issues/153004>

## Comparison of Implementation Options

### 1. Refactor Blocks to Native `RichText` / `RenderParagraph`

This has the lowest long-term selection-maintenance risk because Flutter owns
the paragraph selection implementation. It also aligns with
`flutter_markdown` `0.7.7+1`, which renders generated rich-text blocks with
`SelectableText.rich` when selection is enabled.

Source:

- <https://pub.dev/packages/flutter_markdown/versions/0.7.7%2B1>
- <https://github.com/flutter/packages/tree/flutter_markdown-v0.7.7%2B1/packages/flutter_markdown>

Tradeoff: this package currently has a custom renderer for streaming,
block-level layout, tables, animation, and painter extensibility. Moving these
behaviors into a widget/paragraph tree is a large rewrite with meaningful
layout and performance risk. `flutter_markdown` is evidence that native
selectable rich text works for a block-generated renderer; it is not evidence
that the same migration preserves this package's streaming characteristics.

### 2. Keep the Renderer and Use Framework Selection Aggregation

Use:

1. An ambient registrar consumed in the same manner as `Text`.
2. A package-owned `SelectionContainer`.
3. A custom `MultiSelectableSelectionContainerDelegate`.
4. Private selectable fragments backed by each laid-out `TextPainter`.
5. Document-order metadata and semantic clipboard separators.

This is the best incremental fit. It confines selection complexity to a
private module and avoids changing the public `BlockPainter` contract. Custom
painters that do not expose text fragments can remain non-selectable until they
opt into an internal capability.

The implementation must still cover fragment registration, transforms,
selection geometry, selected-content ranges, repainting, disposal, bidi,
scaling, animation offsets, link gesture competition, and streaming document
updates. Framework APIs reduce this work; they do not eliminate it.

### 3. One Monolithic Custom `Selectable`

A single `Selectable` over the full Markdown surface can appear simpler, but it
must internally reproduce fragment ordering, hit testing, geometry, range
mapping, and semantic content assembly. It is harder to align with the
framework's paragraph model and harder to test in isolation. It should not be
the default architecture unless a prototype demonstrates a clear performance
or correctness advantage.

### 4. Manual Drag Detection and Clipboard Copy

Reject this option. It bypasses the selection system and will be incomplete
across touch, mouse, keyboard, context menus, accessibility, platform
adaptation, and cross-widget selection.

## Recommended Prototype Before the Final Decision

Build two narrow prototypes against representative package content:

1. **Incremental prototype:** paragraph, link, list, table, and code fragments
   under a custom `MultiSelectableSelectionContainerDelegate`.
2. **Native-block prototype:** render the same content with native
   `RichText`/`SelectableText.rich` blocks while preserving the streaming update
   cadence.

Measure:

- frame build, layout, and paint time during token streaming;
- allocations and retained objects during a long response;
- selection across paragraph, list, table, and code boundaries;
- clipboard text and semantic separators;
- link tap versus drag-selection behavior;
- animation-coordinate correctness;
- bidi, text scaling, desktop mouse, mobile handles, keyboard selection, and
  select-all;
- selection behavior when new streaming content is appended;
- compatibility on the package's minimum Flutter version and current stable.

Adopt the custom-container approach if it passes correctness tests and avoids a
renderer rewrite. Prefer gradual migration toward native paragraphs if the
native prototype preserves the package's defining streaming and layout
performance. This makes the immediate recommendation evidence-based while
leaving a lower-maintenance long-term path open.
