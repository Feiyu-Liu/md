import 'package:flutter/widgets.dart';

import 'animation/animation_config.dart';
import 'markdown.dart' show Markdown;
import 'nodes.dart' show MD$Block;
import 'parser.dart'
    show
        MarkdownBlockId,
        MarkdownSourceBlock,
        MarkdownSourceDocument,
        markdownDecoder;
import 'render.dart' show MarkdownRenderObject;
import 'selection.dart' show MarkdownSelectionDelegate;
import 'theme.dart';

/// {@template markdown_widget}
/// MarkdownWidget widget.
/// {@endtemplate}
class MarkdownWidget extends StatefulWidget {
  /// {@macro markdown_widget}
  const MarkdownWidget({
    required Markdown markdown,
    this.theme,
    this.animationConfig = MarkdownAnimationConfig.disabled,
    this.isStreamingComplete,
    this.onAnimationComplete,
    super.key, // ignore: unused_element
  })  : _markdown = markdown,
        sourceDocument = null,
        replacements = const <MarkdownBlockId, String>{},
        compensateScrollJump = true;

  /// Creates a widget that animates cumulative source-block replacements.
  ///
  /// Each replacement must parse to one root block compatible with its source
  /// block. Keeping that invariant prevents a replacement from changing the
  /// Markdown boundary between neighboring source blocks. Callers that validate
  /// replacements before rendering do not pay for duplicate validation here.
  const MarkdownWidget.contentReplacement({
    required MarkdownSourceDocument document,
    this.replacements = const <MarkdownBlockId, String>{},
    this.theme,
    this.animationConfig = const MarkdownAnimationConfig.contentReplacement(),
    this.onAnimationComplete,
    this.compensateScrollJump = true,
    super.key,
  })  : _markdown = null,
        sourceDocument = document,
        isStreamingComplete = null;

  /// Current markdown entity to render.
  Markdown get markdown => _markdown ?? sourceDocument!.markdown;
  final Markdown? _markdown;

  /// Original source document for [MarkdownAnimationMode.contentReplacement].
  final MarkdownSourceDocument? sourceDocument;

  /// Cumulative replacements keyed by stable IDs from [sourceDocument].
  ///
  /// Each value must parse to one root block compatible with the corresponding
  /// [MarkdownSourceBlock.block]. The renderer remains defensive if this
  /// precondition is violated, but cross-block Markdown semantics are
  /// undefined.
  final Map<MarkdownBlockId, String> replacements;

  /// Compensates height changes for replaced blocks above the viewport.
  final bool compensateScrollJump;

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

  /// Called when all animations complete after streaming finishes.
  /// 当流式完成后所有动画播放完成时调用的回调。
  ///
  /// This is only called when [animationConfig.disableOnComplete] is true.
  /// Use this callback to update state and disable animations for this message.
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
  void didUpdateWidget(MarkdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.compensateScrollJump ||
        widget.sourceDocument == null ||
        oldWidget.sourceDocument != widget.sourceDocument) {
      return;
    }
    final changedIds = <MarkdownBlockId>{
      for (final block in widget.sourceDocument!.blocks)
        if ((oldWidget.replacements[block.id] ?? block.source) !=
            (widget.replacements[block.id] ?? block.source))
          block.id,
    };
    if (changedIds.isEmpty) return;
    final scrollable = Scrollable.maybeOf(context);
    final renderObject = context.findRenderObject();
    final viewportObject = scrollable?.context.findRenderObject();
    final axisDirection = scrollable?.position.axisDirection;
    if (scrollable == null ||
        renderObject is! MarkdownRenderObject ||
        viewportObject is! RenderBox ||
        (axisDirection != AxisDirection.down &&
            axisDirection != AxisDirection.up) ||
        !renderObject.hasSize ||
        !viewportObject.hasSize) {
      return;
    }
    final viewportTop = viewportObject.localToGlobal(Offset.zero).dy;
    final oldHeights = <MarkdownBlockId, double>{};
    for (final id in changedIds) {
      final bounds = renderObject.blockBoundsForId(id);
      if (bounds == null) continue;
      final bottom = renderObject.localToGlobal(bounds.bottomLeft).dy;
      if (bottom <= viewportTop) oldHeights[id] = bounds.height;
    }
    if (oldHeights.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || scrollable.position.isScrollingNotifier.value) return;
      final updatedRenderObject = context.findRenderObject();
      if (updatedRenderObject is! MarkdownRenderObject) return;
      var delta = 0.0;
      for (final entry in oldHeights.entries) {
        delta +=
            (updatedRenderObject.blockBoundsForId(entry.key)?.height ?? 0) -
                entry.value;
      }
      final position = scrollable.position;
      if (delta.abs() < 0.01 || !position.hasContentDimensions) {
        return;
      }
      position.jumpTo(
        (position.pixels +
                (axisDirection == AxisDirection.down ? delta : -delta))
            .clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveMarkdownSource(widget);
    final animationConfig =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false
            ? widget.animationConfig.withoutAnimation()
            : widget.animationConfig;
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
      markdown: resolved.markdown,
      theme: theme,
      animationConfig: animationConfig,
      isStreamingComplete: widget.isStreamingComplete,
      onAnimationComplete: widget.onAnimationComplete,
      blockIds: resolved.blockIds,
      replacementValues: resolved.replacementValues,
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
    required this.blockIds,
    required this.replacementValues,
    required this.selectionDelegate,
    required this.selectionColor,
  });

  final Markdown markdown;
  final MarkdownThemeData theme;
  final MarkdownAnimationConfig animationConfig;
  final ValueNotifier<bool>? isStreamingComplete;
  final VoidCallback? onAnimationComplete;
  final List<MarkdownBlockId>? blockIds;
  final Map<MarkdownBlockId, String>? replacementValues;
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
      blockIds: blockIds,
      replacementValues: replacementValues,
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
      blockIds: blockIds,
      replacementValues: replacementValues,
      selectionDelegate: selectionDelegate,
      selectionColor: selectionColor,
    );
  }
}

({
  Markdown markdown,
  List<MarkdownBlockId>? blockIds,
  Map<MarkdownBlockId, String>? replacementValues,
}) _resolveMarkdownSource(MarkdownWidget widget) {
  final document = widget.sourceDocument;
  if (document == null) {
    return (
      markdown: widget.markdown,
      blockIds: null,
      replacementValues: null,
    );
  }

  final blocks = <MD$Block>[];
  final blockIds = <MarkdownBlockId>[];
  final values = <MarkdownBlockId, String>{};
  for (final sourceBlock in document.blocks) {
    final replacement = widget.replacements[sourceBlock.id];
    final value = replacement ?? sourceBlock.source;
    values[sourceBlock.id] = value;
    if (replacement == null) {
      blocks.add(sourceBlock.block);
      blockIds.add(sourceBlock.id);
      continue;
    }
    final replacementBlocks = markdownDecoder.convert(replacement).blocks;
    blocks.addAll(replacementBlocks);
    blockIds.addAll(
      List<MarkdownBlockId>.filled(
        replacementBlocks.length,
        sourceBlock.id,
      ),
    );
  }
  return (
    markdown: Markdown(
      markdown: document.applyReplacements(widget.replacements),
      blocks: List.unmodifiable(blocks),
    ),
    blockIds: List<MarkdownBlockId>.unmodifiable(blockIds),
    replacementValues: Map<MarkdownBlockId, String>.unmodifiable(values),
  );
}
