import 'dart:collection';

import 'package:flutter/material.dart';

import '../flutter_md.dart';

/// Token-to-style overrides for fenced code blocks.
///
/// Keys should match syntax token class names produced by the `highlight`
/// package, such as `keyword`, `string`, or `title`.
typedef MarkdownCodeTheme = Map<String, TextStyle>;

/// Builds a syntax-highlighted [TextSpan] tree for fenced code blocks.
abstract interface class MarkdownCodeHighlighter {
  /// Creates a syntax-highlighted [TextSpan] tree.
  const MarkdownCodeHighlighter();

  /// Returns a syntax-highlighted span tree for [text].
  TextSpan build({
    required String text,
    required String? language,
    required TextStyle textStyle,
    required MarkdownThemeData theme,
  });
}

/// {@template markdown_theme_data}
/// Theme data for Markdown widgets.
/// {@endtemplate}
class MarkdownThemeData implements ThemeExtension<MarkdownThemeData> {
  /// Creates a [MarkdownThemeData] instance.
  /// {@macro markdown_theme_data}
  MarkdownThemeData({
    required this.textStyle,
    this.textDirection = TextDirection.ltr,
    this.textScaler = TextScaler.noScaling,
    this.h1Style,
    this.h2Style,
    this.h3Style,
    this.h4Style,
    this.h5Style,
    this.h6Style,
    this.quoteStyle,
    this.linkColor = Colors.indigo,
    this.surfaceColor = const Color.fromARGB(255, 235, 235, 235),
    this.highlightBackgroundColor = const Color(0x40FF5722),
    this.monospaceBackgroundColor = const Color(0x409E9E9E),
    this.dividerColor,
    this.codeStyle,
    this.codeLanguageStyle,
    this.codeBackgroundColor,
    this.codePadding = const EdgeInsets.all(8.0),
    MarkdownCodeTheme? codeTheme,
    this.codeHighlighter,
    this.blockFilter,
    this.spanFilter,
    this.spanBuilder,
    this.builder,
    this.onLinkTap,
  })  : codeTheme = codeTheme == null
            ? null
            : Map<String, TextStyle>.unmodifiable(codeTheme),
        _headingStyles = List<TextStyle?>.filled(8, null),
        _textStyles = HashMap<int, TextStyle>();

  /// Creates a [MarkdownThemeData] from the given [ThemeData].
  factory MarkdownThemeData.mergeTheme(
    ThemeData theme, {
    TextStyle? textStyle,
    TextDirection? textDirection,
    TextScaler? textScaler,
    TextStyle? h1Style,
    TextStyle? h2Style,
    TextStyle? h3Style,
    TextStyle? h4Style,
    TextStyle? h5Style,
    TextStyle? h6Style,
    TextStyle? quoteStyle,
    Color? linkColor,
    Color? surfaceColor,
    Color? highlightBackgroundColor,
    Color? monospaceBackgroundColor,
    Color? dividerColor,
    TextStyle? codeStyle,
    TextStyle? codeLanguageStyle,
    Color? codeBackgroundColor,
    EdgeInsets? codePadding,
    MarkdownCodeTheme? codeTheme,
    MarkdownCodeHighlighter? codeHighlighter,
    bool Function(MD$Block block)? blockFilter,
    bool Function(MD$Span span)? spanFilter,
    InlineSpan? Function(
      MD$Span span,
      TextStyle textStyle,
      MarkdownThemeData theme,
    )? spanBuilder,
    BlockPainter? Function(MD$Block block, MarkdownThemeData theme)? builder,
    void Function(String title, String url)? onLinkTap,
  }) {
    return MarkdownThemeData(
      textStyle: textStyle ??
          theme.textTheme.bodyMedium ??
          const TextStyle(color: Colors.black, fontSize: kDefaultFontSize),
      textDirection: textDirection ?? TextDirection.ltr,
      textScaler: textScaler ?? TextScaler.noScaling,
      h1Style: h1Style ?? theme.textTheme.headlineLarge,
      h2Style: h2Style ?? theme.textTheme.headlineMedium,
      h3Style: h3Style ?? theme.textTheme.headlineSmall,
      h4Style: h4Style ?? theme.textTheme.titleLarge,
      h5Style: h5Style ?? theme.textTheme.titleMedium,
      h6Style: h6Style ?? theme.textTheme.titleSmall,
      quoteStyle: quoteStyle ??
          theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
          ),
      linkColor: linkColor ?? theme.colorScheme.primary,
      surfaceColor: surfaceColor ?? theme.colorScheme.surfaceContainerHigh,
      highlightBackgroundColor:
          highlightBackgroundColor ?? theme.colorScheme.errorContainer,
      monospaceBackgroundColor:
          monospaceBackgroundColor ?? theme.colorScheme.surfaceContainerHigh,
      dividerColor: dividerColor ?? theme.dividerColor.withValues(alpha: 0.12),
      codeStyle: codeStyle,
      codeLanguageStyle: codeLanguageStyle,
      codeBackgroundColor: codeBackgroundColor,
      codePadding: codePadding ?? const EdgeInsets.all(8.0),
      codeTheme: codeTheme,
      codeHighlighter: codeHighlighter,
      blockFilter: blockFilter,
      spanFilter: spanFilter,
      spanBuilder: spanBuilder,
      builder: builder,
      onLinkTap: onLinkTap,
    );
  }

  @override
  Object get type => MarkdownThemeData;

  /// The text direction to use for rendering Markdown widgets.
  final TextDirection textDirection;

  /// The text scaler to use for scaling text in Markdown widgets.
  final TextScaler textScaler;

  /// The default text style to use for Markdown widgets.
  final TextStyle textStyle;

  /// Default text style for headings h1.
  final TextStyle? h1Style;

  /// Default text style for headings h2.
  final TextStyle? h2Style;

  /// Default text style for headings h3.
  final TextStyle? h3Style;

  /// Default text style for headings h4.
  final TextStyle? h4Style;

  /// Default text style for headings h5.
  final TextStyle? h5Style;

  /// Default text style for headings h6.
  final TextStyle? h6Style;

  /// Default text style for quote blocks.
  final TextStyle? quoteStyle;

  /// The color to use for link text.
  final Color? linkColor;

  /// The color to use for the background of the quote, block, table and etc.
  final Color? surfaceColor;

  /// The color to use for the background of highlighted text.
  final Color? highlightBackgroundColor;

  /// The color to use for the background of monospace text.
  final Color? monospaceBackgroundColor;

  /// The color to use for the divider.
  final Color? dividerColor;

  /// Base text style for fenced code blocks.
  final TextStyle? codeStyle;

  /// Text style for the optional language label above a code block.
  final TextStyle? codeLanguageStyle;

  /// Background color for fenced code blocks.
  final Color? codeBackgroundColor;

  /// Padding around fenced code blocks.
  final EdgeInsets codePadding;

  /// Token-to-style overrides for syntax-highlighted code blocks.
  final MarkdownCodeTheme? codeTheme;

  /// Custom syntax highlighter for fenced code blocks.
  final MarkdownCodeHighlighter? codeHighlighter;

  /// A filter function to determine whether a block should be rendered.
  /// If the function returns `true`, the block will be rendered.
  ///
  /// For example, you can use this to filter out blocks that are not
  /// relevant to the current context, such as code blocks or tables.
  final bool Function(MD$Block block)? blockFilter;

  /// A filter function to determine whether a span should be rendered.
  /// If the function returns `true`, the span will be rendered.
  ///
  /// For example, you can use this to filter out spans that are not
  /// relevant to the current context, such as links or images.
  /// This can be useful for customizing the rendering of Markdown spans.
  final bool Function(MD$Span span)? spanFilter;

  /// A custom inline span builder function.
  /// It receives the current [MD$Span], the resolved [TextStyle],
  /// and the active [MarkdownThemeData].
  /// If it returns `null`, the default text span will be used.
  final InlineSpan? Function(
    MD$Span span,
    TextStyle textStyle,
    MarkdownThemeData theme,
  )? spanBuilder;

  /// A custom block painter builder function.
  /// It receives a [MD$Block] and returns a [BlockPainter].
  /// If it returns `null`, the default painter will be used.
  /// This allows you to customize the rendering of specific blocks,
  /// such as code blocks, tables, or quote blocks.
  final BlockPainter? Function(
    MD$Block block,
    MarkdownThemeData theme,
  )? builder;

  /// A callback function that is called when a link is tapped.
  /// It receives the link title and URL as parameters.
  final void Function(String title, String url)? onLinkTap;

  final List<TextStyle?> _headingStyles;

  /// Returns a [TextStyle] for the given heading level.
  /// The level should be between 1 and 6, inclusive.
  TextStyle headingStyleFor(int level) =>
      _headingStyles[level] ??= switch (level.clamp(1, 7)) {
        1 => h1Style ??
            textStyle.copyWith(
              fontSize: (textStyle.fontSize ?? kDefaultFontSize) + 10.0,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.solid,
            ),
        2 => h2Style ??
            textStyle.copyWith(
              fontSize: (textStyle.fontSize ?? kDefaultFontSize) + 8.0,
              fontWeight: FontWeight.bold,
            ),
        3 => h3Style ??
            textStyle.copyWith(
              fontSize: (textStyle.fontSize ?? kDefaultFontSize) + 6.0,
              fontWeight: FontWeight.bold,
            ),
        4 => h4Style ??
            textStyle.copyWith(
              fontSize: (textStyle.fontSize ?? kDefaultFontSize) + 4.0,
              fontWeight: FontWeight.bold,
            ),
        5 => h5Style ??
            textStyle.copyWith(
              fontSize: (textStyle.fontSize ?? kDefaultFontSize) + 2.0,
              fontWeight: FontWeight.bold,
            ),
        6 => h6Style ??
            textStyle.copyWith(
              fontSize: (textStyle.fontSize ?? kDefaultFontSize) + 0.0,
              fontWeight: FontWeight.bold,
            ),
        _ => textStyle,
      };

  final HashMap<int, TextStyle> _textStyles;

  /// Returns the resolved base style for fenced code blocks.
  TextStyle get resolvedCodeStyle =>
      codeStyle ??
      textStyle.copyWith(
        fontFamily: 'monospace',
        fontSize: textStyle.fontSize ?? kDefaultFontSize,
        height: 1.45,
      );

  /// Returns the resolved style for the optional code language label.
  TextStyle get resolvedCodeLanguageStyle =>
      codeLanguageStyle ??
      resolvedCodeStyle.copyWith(
        fontSize: (((resolvedCodeStyle.fontSize ?? kDefaultFontSize) - 2.0)
                .clamp(10.0, double.infinity))
            .toDouble(),
        fontWeight: FontWeight.w600,
        color: resolvedCodeStyle.color?.withValues(alpha: 0.72),
      );

  /// Returns the resolved background color for fenced code blocks.
  Color get resolvedCodeBackgroundColor =>
      codeBackgroundColor ??
      surfaceColor ??
      const Color.fromARGB(255, 235, 235, 235);

  /// Returns the resolved syntax theme for fenced code blocks.
  MarkdownCodeTheme get resolvedCodeTheme => <String, TextStyle>{
        ..._defaultCodeTheme(
          baseStyle: resolvedCodeStyle,
          textColor: textStyle.color,
          accentColor: linkColor,
          backgroundColor: resolvedCodeBackgroundColor,
        ),
        ...?codeTheme,
      };

  /// Returns a [TextStyle] for the given syntax [tokenClass].
  TextStyle codeTextStyleFor(
    String? tokenClass, {
    TextStyle? baseStyle,
  }) {
    final resolvedTheme = resolvedCodeTheme;
    var resolvedStyle = baseStyle ?? resolvedCodeStyle;

    if (baseStyle == null) {
      resolvedStyle = resolvedStyle.merge(resolvedTheme['root']);
    }

    if (tokenClass == null || tokenClass.trim().isEmpty) {
      return resolvedStyle;
    }

    final seen = <String>{};

    void mergeToken(String token) {
      if (!seen.add(token)) return;
      resolvedStyle = resolvedStyle.merge(resolvedTheme[token]);
    }

    mergeToken(tokenClass);

    for (final token in tokenClass.split(RegExp(r'[\s.]+'))) {
      if (token.isEmpty) continue;
      mergeToken(token);
    }

    return resolvedStyle;
  }

  /// Returns a [TextStyle] for the given [MD$Style].
  TextStyle textStyleFor(MD$Style style) => _textStyles.putIfAbsent(
        style.hashCode,
        () => textStyle.copyWith(
          fontWeight: switch (style) {
            var s when s.contains(MD$Style.bold) => FontWeight.bold,
            var s when s.contains(MD$Style.link) => FontWeight.bold,
            var s when s.contains(MD$Style.highlight) => FontWeight.bold,
            _ => null,
          },
          fontStyle: style.contains(MD$Style.italic) ? FontStyle.italic : null,
          decoration: switch (style) {
            var s when s.contains(MD$Style.underline) =>
              TextDecoration.underline,
            var s when s.contains(MD$Style.strikethrough) =>
              TextDecoration.lineThrough,
            _ => null,
          },
          fontFamily: style.contains(MD$Style.monospace) ? 'monospace' : null,
          color: switch (style) {
            var s when s.contains(MD$Style.link) => linkColor,
            _ => null,
          },
          backgroundColor: switch (style) {
            var s when s.contains(MD$Style.highlight) =>
              highlightBackgroundColor,
            var s when s.contains(MD$Style.monospace) =>
              monospaceBackgroundColor,
            _ => null,
          },
        ),
      );

  @override
  ThemeExtension<MarkdownThemeData> copyWith({
    TextDirection? textDirection,
    TextScaler? textScaler,
    TextStyle? textStyle,
    TextStyle? h1Style,
    TextStyle? h2Style,
    TextStyle? h3Style,
    TextStyle? h4Style,
    TextStyle? h5Style,
    TextStyle? h6Style,
    TextStyle? quoteStyle,
    Color? linkColor,
    Color? surfaceColor,
    Color? highlightBackgroundColor,
    Color? monospaceBackgroundColor,
    Color? dividerColor,
    TextStyle? codeStyle,
    TextStyle? codeLanguageStyle,
    Color? codeBackgroundColor,
    EdgeInsets? codePadding,
    MarkdownCodeTheme? codeTheme,
    MarkdownCodeHighlighter? codeHighlighter,
    bool Function(MD$Block block)? blockFilter,
    bool Function(MD$Span span)? spanFilter,
    InlineSpan? Function(
      MD$Span span,
      TextStyle textStyle,
      MarkdownThemeData theme,
    )? spanBuilder,
    BlockPainter? Function(MD$Block block, MarkdownThemeData theme)? builder,
    void Function(String title, String url)? onLinkTap,
  }) =>
      MarkdownThemeData(
        textDirection: textDirection ?? this.textDirection,
        textScaler: textScaler ?? this.textScaler,
        textStyle: textStyle ?? this.textStyle,
        h1Style: h1Style ?? this.h1Style,
        h2Style: h2Style ?? this.h2Style,
        h3Style: h3Style ?? this.h3Style,
        h4Style: h4Style ?? this.h4Style,
        h5Style: h5Style ?? this.h5Style,
        h6Style: h6Style ?? this.h6Style,
        quoteStyle: quoteStyle ?? this.quoteStyle,
        linkColor: linkColor ?? this.linkColor,
        surfaceColor: surfaceColor ?? this.surfaceColor,
        highlightBackgroundColor:
            highlightBackgroundColor ?? this.highlightBackgroundColor,
        monospaceBackgroundColor:
            monospaceBackgroundColor ?? this.monospaceBackgroundColor,
        dividerColor: dividerColor ?? this.dividerColor,
        codeStyle: codeStyle ?? this.codeStyle,
        codeLanguageStyle: codeLanguageStyle ?? this.codeLanguageStyle,
        codeBackgroundColor: codeBackgroundColor ?? this.codeBackgroundColor,
        codePadding: codePadding ?? this.codePadding,
        codeTheme: codeTheme ?? this.codeTheme,
        codeHighlighter: codeHighlighter ?? this.codeHighlighter,
        blockFilter: blockFilter ?? this.blockFilter,
        spanFilter: spanFilter ?? this.spanFilter,
        spanBuilder: spanBuilder ?? this.spanBuilder,
        builder: builder ?? this.builder,
        onLinkTap: onLinkTap ?? this.onLinkTap,
      );

  @override
  ThemeExtension<MarkdownThemeData> lerp(
    covariant MarkdownThemeData? other,
    double t,
  ) {
    if (identical(this, other)) return this;

    return MarkdownThemeData(
      textDirection:
          t < 0.5 ? textDirection : other?.textDirection ?? TextDirection.ltr,
      textScaler:
          t < 0.5 ? textScaler : other?.textScaler ?? TextScaler.noScaling,
      textStyle: TextStyle.lerp(textStyle, other?.textStyle, t)!,
      h1Style: TextStyle.lerp(h1Style, other?.h1Style, t),
      h2Style: TextStyle.lerp(h2Style, other?.h2Style, t),
      h3Style: TextStyle.lerp(h3Style, other?.h3Style, t),
      h4Style: TextStyle.lerp(h4Style, other?.h4Style, t),
      h5Style: TextStyle.lerp(h5Style, other?.h5Style, t),
      h6Style: TextStyle.lerp(h6Style, other?.h6Style, t),
      quoteStyle: TextStyle.lerp(quoteStyle, other?.quoteStyle, t),
      linkColor: Color.lerp(linkColor, other?.linkColor, t),
      surfaceColor: Color.lerp(surfaceColor, other?.surfaceColor, t),
      highlightBackgroundColor: Color.lerp(
        highlightBackgroundColor,
        other?.highlightBackgroundColor,
        t,
      ),
      monospaceBackgroundColor: Color.lerp(
        monospaceBackgroundColor,
        other?.monospaceBackgroundColor,
        t,
      ),
      dividerColor: Color.lerp(dividerColor, other?.dividerColor, t),
      codeStyle: TextStyle.lerp(codeStyle, other?.codeStyle, t),
      codeLanguageStyle: TextStyle.lerp(
        codeLanguageStyle,
        other?.codeLanguageStyle,
        t,
      ),
      codeBackgroundColor: Color.lerp(
        codeBackgroundColor,
        other?.codeBackgroundColor,
        t,
      ),
      codePadding:
          EdgeInsets.lerp(codePadding, other?.codePadding, t) ?? codePadding,
      codeTheme: t < 0.5 ? codeTheme : other?.codeTheme,
      codeHighlighter: t < 0.5 ? codeHighlighter : other?.codeHighlighter,
      blockFilter: t < 0.5 ? blockFilter : other?.blockFilter,
      spanFilter: t < 0.5 ? spanFilter : other?.spanFilter,
      spanBuilder: t < 0.5 ? spanBuilder : other?.spanBuilder,
      builder: t < 0.5 ? builder : other?.builder,
      onLinkTap: t < 0.5 ? onLinkTap : other?.onLinkTap,
    );
  }

  @override
  String toString() => 'MarkdownThemeData{}';
}

MarkdownCodeTheme _defaultCodeTheme({
  required TextStyle baseStyle,
  required Color? textColor,
  required Color? accentColor,
  required Color backgroundColor,
}) {
  final baseColor = textColor ?? baseStyle.color ?? const Color(0xFF222222);
  final accent = accentColor ?? const Color(0xFF3366CC);
  final warm = Color.lerp(accent, const Color(0xFFD73A49), 0.72)!;
  final cool = Color.lerp(accent, const Color(0xFF005CC5), 0.58)!;
  final mint = Color.lerp(accent, const Color(0xFF22863A), 0.74)!;
  final amber = Color.lerp(accent, const Color(0xFFE36209), 0.78)!;
  final violet = Color.lerp(accent, const Color(0xFF6F42C1), 0.74)!;
  final muted = Color.lerp(baseColor, backgroundColor, 0.44)!;

  return <String, TextStyle>{
    'root': TextStyle(
      color: baseColor,
      backgroundColor: backgroundColor,
    ),
    'comment': TextStyle(
      color: muted,
      fontStyle: FontStyle.italic,
    ),
    'quote': TextStyle(
      color: muted,
      fontStyle: FontStyle.italic,
    ),
    'keyword': TextStyle(
      color: warm,
      fontWeight: FontWeight.w700,
    ),
    'selector-tag': TextStyle(
      color: warm,
      fontWeight: FontWeight.w700,
    ),
    'subst': TextStyle(color: baseColor),
    'number': TextStyle(color: cool),
    'literal': TextStyle(color: cool),
    'variable': TextStyle(color: cool),
    'template-variable': TextStyle(color: cool),
    'string': TextStyle(color: mint),
    'doctag': TextStyle(color: mint),
    'regexp': TextStyle(color: mint),
    'link': TextStyle(color: mint),
    'title': TextStyle(
      color: violet,
      fontWeight: FontWeight.w700,
    ),
    'section': TextStyle(
      color: violet,
      fontWeight: FontWeight.w700,
    ),
    'selector-id': TextStyle(
      color: violet,
      fontWeight: FontWeight.w700,
    ),
    'type': TextStyle(
      color: amber,
      fontWeight: FontWeight.w700,
    ),
    'tag': TextStyle(color: warm),
    'name': TextStyle(color: warm),
    'attribute': TextStyle(color: amber),
    'attr': TextStyle(color: amber),
    'symbol': TextStyle(color: violet),
    'bullet': TextStyle(color: violet),
    'built_in': TextStyle(color: cool),
    'builtin-name': TextStyle(color: cool),
    'meta': TextStyle(
      color: muted,
      fontWeight: FontWeight.w600,
    ),
    'meta-keyword': TextStyle(
      color: warm,
      fontWeight: FontWeight.w700,
    ),
    'addition': TextStyle(
      color: mint,
      backgroundColor: mint.withValues(alpha: 0.12),
    ),
    'deletion': TextStyle(
      color: warm,
      backgroundColor: warm.withValues(alpha: 0.12),
    ),
    'emphasis': const TextStyle(fontStyle: FontStyle.italic),
    'strong': const TextStyle(fontWeight: FontWeight.bold),
  };
}

/// {@template theme}
/// MarkdownTheme widget.
/// {@endtemplate}
class MarkdownTheme extends InheritedWidget {
  /// {@macro theme}
  const MarkdownTheme({
    required this.data,
    required super.child,
    super.key, // ignore: unused_element
  });

  /// The state from the closest instance of this class
  /// that encloses the given context, if any.
  /// e.g. `Theme.maybeOf(context)`.
  static MarkdownThemeData? maybeOf(
    BuildContext context, {
    bool listen = true,
  }) =>
      listen
          ? context.dependOnInheritedWidgetOfExactType<MarkdownTheme>()?.data
          : context.getInheritedWidgetOfExactType<MarkdownTheme>()?.data;

  static Never _notFoundInheritedWidgetOfExactType() => throw ArgumentError(
        'Out of scope, not found inherited widget '
            'a MarkdownTheme of the exact type',
        'out_of_scope',
      );

  /// The state from the closest instance of this class
  /// that encloses the given context.
  /// e.g. `Theme.of(context)`
  static MarkdownThemeData of(BuildContext context, {bool listen = true}) =>
      maybeOf(context, listen: listen) ?? _notFoundInheritedWidgetOfExactType();

  /// The current theme data for Markdown widgets.
  final MarkdownThemeData data;

  @override
  bool updateShouldNotify(covariant MarkdownTheme oldWidget) =>
      !identical(data, oldWidget.data);
}
