import 'package:flutter/widgets.dart';

import 'animation/animation_config.dart';
import 'markdown.dart' show Markdown;
import 'render.dart' show MarkdownRenderObject;
import 'theme.dart';

/// {@template markdown_widget}
/// MarkdownWidget widget.
/// {@endtemplate}
class MarkdownWidget extends LeafRenderObjectWidget {
  /// {@macro markdown_widget}
  const MarkdownWidget({
    required this.markdown,
    this.theme,
    this.animationConfig = MarkdownAnimationConfig.disabled,
    super.key, // ignore: unused_element
  });

  /// Current markdown entity to render.
  final Markdown markdown;

  /// Current theme for the markdown widget.
  final MarkdownThemeData? theme;

  /// Animation configuration for block fade-in effects.
  /// 块淡入效果的动画配置
  final MarkdownAnimationConfig animationConfig;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final theme = this.theme ??
        MarkdownTheme.maybeOf(context) ??
        MarkdownThemeData(
          textStyle: DefaultTextStyle.of(context).style,
          textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
          textScaler:
              MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
        );
    return MarkdownRenderObject(
      markdown: markdown,
      theme: theme,
      animationConfig: animationConfig,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    MarkdownRenderObject renderObject,
  ) {
    final theme = this.theme ??
        MarkdownTheme.maybeOf(context) ??
        MarkdownThemeData(
          textStyle: DefaultTextStyle.of(context).style,
          textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
          textScaler:
              MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
        );
    renderObject.update(
      markdown: markdown,
      theme: theme,
      animationConfig: animationConfig,
    );
  }
}
