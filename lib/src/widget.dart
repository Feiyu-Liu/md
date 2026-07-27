import 'package:flutter/widgets.dart';

import 'animation/animation_config.dart';
import 'markdown.dart' show Markdown;
import 'render.dart' show MarkdownRenderObject;
import 'selection.dart' show MarkdownSelectionDelegate;
import 'theme.dart';

/// {@template markdown_widget}
/// MarkdownWidget widget.
/// {@endtemplate}
class MarkdownWidget extends StatefulWidget {
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
  State<MarkdownWidget> createState() => _MarkdownWidgetState();
}

class _MarkdownWidgetState extends State<MarkdownWidget> {
  final MarkdownSelectionDelegate _selectionDelegate =
      MarkdownSelectionDelegate();

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ??
        MarkdownTheme.maybeOf(context) ??
        MarkdownThemeData(
          textStyle: DefaultTextStyle.of(context).style,
          textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
          textScaler:
              MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
        );
    final registrar = SelectionContainer.maybeOf(context);
    final selectionStyle = DefaultSelectionStyle.of(context);
    final child = _MarkdownRenderObjectWidget(
      markdown: widget.markdown,
      theme: theme,
      animationConfig: widget.animationConfig,
      isStreamingComplete: widget.isStreamingComplete,
      onAnimationComplete: widget.onAnimationComplete,
      selectionDelegate: registrar == null ? null : _selectionDelegate,
      selectionColor:
          selectionStyle.selectionColor ?? DefaultSelectionStyle.defaultColor,
    );
    if (registrar == null) return child;

    return MouseRegion(
      cursor: selectionStyle.mouseCursor ?? SystemMouseCursors.text,
      child: SelectionContainer(
        registrar: registrar,
        delegate: _selectionDelegate,
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    _selectionDelegate.dispose();
    super.dispose();
  }
}

class _MarkdownRenderObjectWidget extends LeafRenderObjectWidget {
  const _MarkdownRenderObjectWidget({
    required this.markdown,
    required this.theme,
    required this.animationConfig,
    required this.isStreamingComplete,
    required this.onAnimationComplete,
    required this.selectionDelegate,
    required this.selectionColor,
  });

  final Markdown markdown;
  final MarkdownThemeData theme;
  final MarkdownAnimationConfig animationConfig;
  final ValueNotifier<bool>? isStreamingComplete;
  final VoidCallback? onAnimationComplete;
  final MarkdownSelectionDelegate? selectionDelegate;
  final Color selectionColor;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return MarkdownRenderObject(
      markdown: markdown,
      theme: theme,
      animationConfig: animationConfig,
      isStreamingComplete: isStreamingComplete,
      onAnimationComplete: onAnimationComplete,
      selectionDelegate: selectionDelegate,
      selectionColor: selectionColor,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    MarkdownRenderObject renderObject,
  ) {
    renderObject.update(
      markdown: markdown,
      theme: theme,
      animationConfig: animationConfig,
      isStreamingComplete: isStreamingComplete,
      onAnimationComplete: onAnimationComplete,
      selectionDelegate: selectionDelegate,
      selectionColor: selectionColor,
    );
  }
}
