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
    this.isStreamingComplete,
    this.onAnimationComplete,
    super.key, // ignore: unused_element
  });

  /// Current markdown entity to render.
  final Markdown markdown;

  /// Current theme for the markdown widget.
  final MarkdownThemeData? theme;

  /// Animation configuration for block fade-in effects.
  /// 块淡入效果的动画配置
  final MarkdownAnimationConfig animationConfig;

  /// Notifier indicating whether streaming is complete.
  /// When streaming is complete, all blocks (including the last one)
  /// are considered closed.
  /// 流式输出是否完成的通知器。
  /// 当流式输出完成时，所有 blocks（包括最后一个）都被视为已闭合。
  final ValueNotifier<bool>? isStreamingComplete;

  /// Callback invoked when all animations have completed after streaming finishes.
  /// 当流式完成后所有动画播放完成时调用的回调。
  ///
  /// This is only called when [animationConfig.disableOnComplete] is true.
  /// Use this callback to update your state and disable animations for this message.
  /// 仅当 [animationConfig.disableOnComplete] 为 true 时才会调用。
  /// 使用此回调更新状态并禁用此消息的动画。
  final VoidCallback? onAnimationComplete;

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
      isStreamingComplete: isStreamingComplete,
      onAnimationComplete: onAnimationComplete,
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
      isStreamingComplete: isStreamingComplete,
      onAnimationComplete: onAnimationComplete,
    );
  }
}
