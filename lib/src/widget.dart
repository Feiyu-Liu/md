import 'package:flutter/widgets.dart';

import 'animation/animation_config.dart';
import 'markdown.dart' show Markdown;
import 'nodes.dart' show MD$Block, MD$Divider, MD$Spacer, MD$Table;
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
  final Map<(MarkdownBlockId, int), GlobalKey> _blockRenderKeys = {};

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
    final viewportObject = scrollable?.context.findRenderObject();
    final axisDirection = scrollable?.position.axisDirection;
    if (scrollable == null ||
        viewportObject is! RenderBox ||
        (axisDirection != AxisDirection.down &&
            axisDirection != AxisDirection.up) ||
        !viewportObject.hasSize) {
      return;
    }
    final viewportTop = viewportObject.localToGlobal(Offset.zero).dy;
    final oldHeights = <MarkdownBlockId, double>{};
    for (final id in changedIds) {
      final bounds = _blockBoundsForId(id);
      if (bounds == null) continue;
      if (bounds.bottom <= viewportTop) oldHeights[id] = bounds.height;
    }
    if (oldHeights.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || scrollable.position.isScrollingNotifier.value) return;
      var delta = 0.0;
      for (final entry in oldHeights.entries) {
        delta += (_blockBoundsForId(entry.key)?.height ?? 0) - entry.value;
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
    final selectionColor =
        selectionStyle.selectionColor ?? DefaultSelectionStyle.defaultColor;
    final child = resolved.markdown.blocks.any((block) => block is MD$Table)
        ? _MarkdownBlockLayout(
            markdown: resolved.markdown,
            theme: theme,
            animationConfig: animationConfig,
            isStreamingComplete: widget.isStreamingComplete,
            onAnimationComplete: widget.onAnimationComplete,
            blockIds: resolved.blockIds,
            replacementValues: resolved.replacementValues,
            selectionDelegate: registrar == null ? null : _selectionDelegate,
            selectionColor: selectionColor,
            blockRenderKeys: _keysForBlocks(resolved.blockIds),
          )
        : _MarkdownRenderObjectWidget(
            markdown: resolved.markdown,
            theme: theme,
            animationConfig: animationConfig,
            isStreamingComplete: widget.isStreamingComplete,
            onAnimationComplete: widget.onAnimationComplete,
            blockIds: resolved.blockIds,
            replacementValues: resolved.replacementValues,
            selectionDelegate: registrar == null ? null : _selectionDelegate,
            selectionColor: selectionColor,
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

  List<GlobalKey?> _keysForBlocks(List<MarkdownBlockId>? ids) {
    if (ids == null) return const <GlobalKey?>[];
    final occurrences = <MarkdownBlockId, int>{};
    final active = <(MarkdownBlockId, int)>{};
    final keys = <GlobalKey>[];

    for (final id in ids) {
      final occurrence =
          occurrences.update(id, (value) => value + 1, ifAbsent: () => 0);
      final identity = (id, occurrence);
      active.add(identity);
      keys.add(
        _blockRenderKeys.putIfAbsent(
          identity,
          () => GlobalKey(debugLabel: '${id.value}:$occurrence'),
        ),
      );
    }
    _blockRenderKeys.removeWhere((identity, _) => !active.contains(identity));
    return keys;
  }

  Rect? _blockBoundsForId(MarkdownBlockId id) {
    final root = context.findRenderObject();
    if (root case MarkdownRenderObject()) {
      final bounds = root.blockBoundsForId(id);
      if (bounds == null) return null;
      return MatrixUtils.transformRect(root.getTransformTo(null), bounds);
    }

    Rect? result;
    for (final entry in _blockRenderKeys.entries) {
      if (entry.key.$1 != id) continue;
      final renderObject = entry.value.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;
      final bounds = MatrixUtils.transformRect(
        renderObject.getTransformTo(null),
        Offset.zero & renderObject.size,
      );
      result = result == null ? bounds : result.expandToInclude(bounds);
    }
    return result;
  }
}

class _MarkdownRenderObjectWidget extends LeafRenderObjectWidget {
  const _MarkdownRenderObjectWidget({
    super.key,
    required this.markdown,
    required this.theme,
    required this.animationConfig,
    required this.isStreamingComplete,
    required this.onAnimationComplete,
    required this.blockIds,
    required this.replacementValues,
    required this.selectionDelegate,
    required this.selectionColor,
    this.layoutMaxWidth,
    this.selectionBaseOffset = 0,
    this.selectionPrefix = '',
    this.renderAllBlocks = false,
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
  final double? layoutMaxWidth;
  final int selectionBaseOffset;
  final String selectionPrefix;
  final bool renderAllBlocks;

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
      layoutMaxWidth: layoutMaxWidth,
      selectionBaseOffset: selectionBaseOffset,
      selectionPrefix: selectionPrefix,
      renderAllBlocks: renderAllBlocks,
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
      layoutMaxWidth: layoutMaxWidth,
      selectionBaseOffset: selectionBaseOffset,
      selectionPrefix: selectionPrefix,
      renderAllBlocks: renderAllBlocks,
    );
  }
}

class _MarkdownBlockLayout extends StatelessWidget {
  const _MarkdownBlockLayout({
    required this.markdown,
    required this.theme,
    required this.animationConfig,
    required this.isStreamingComplete,
    required this.onAnimationComplete,
    required this.blockIds,
    required this.replacementValues,
    required this.selectionDelegate,
    required this.selectionColor,
    required this.blockRenderKeys,
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
  final List<GlobalKey?> blockRenderKeys;

  @override
  Widget build(BuildContext context) {
    final selectionPrefixes = _selectionPrefixes();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var index = 0; index < markdown.blocks.length; index++)
          _buildBlock(context, index, selectionPrefixes[index]),
      ],
    );
  }

  Widget _buildBlock(
    BuildContext context,
    int index,
    String selectionPrefix,
  ) {
    final block = markdown.blocks[index];
    final blockId = blockIds?[index];
    final renderKey = blockRenderKeys.isEmpty ? null : blockRenderKeys[index];
    final renderAllBlocks =
        animationConfig.mode == MarkdownAnimationMode.streaming &&
            index < markdown.blocks.length - 1;
    final child = _MarkdownRenderObjectWidget(
      key: renderKey ?? ValueKey<Object>(blockId ?? (index, block.type)),
      markdown: Markdown(markdown: block.text, blocks: <MD$Block>[block]),
      theme: theme,
      animationConfig: animationConfig,
      isStreamingComplete: isStreamingComplete,
      onAnimationComplete: onAnimationComplete,
      blockIds: blockId == null ? null : <MarkdownBlockId>[blockId],
      replacementValues: replacementValues,
      selectionDelegate: selectionDelegate,
      selectionColor: selectionColor,
      selectionBaseOffset: index << 32,
      selectionPrefix: selectionPrefix,
      renderAllBlocks: renderAllBlocks,
    );
    if (block is! MD$Table) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return SingleChildScrollView(
          key: ValueKey<Object>('markdown-table-scroll-${blockId ?? index}'),
          scrollDirection: Axis.horizontal,
          child: _MarkdownRenderObjectWidget(
            key: renderKey ??
                ValueKey<Object>('markdown-table-${blockId ?? index}'),
            markdown: Markdown(
              markdown: block.text,
              blocks: <MD$Block>[block],
            ),
            theme: theme,
            animationConfig: animationConfig,
            isStreamingComplete: isStreamingComplete,
            onAnimationComplete: onAnimationComplete,
            blockIds: blockId == null ? null : <MarkdownBlockId>[blockId],
            replacementValues: replacementValues,
            selectionDelegate: selectionDelegate,
            selectionColor: selectionColor,
            layoutMaxWidth: viewportWidth,
            selectionBaseOffset: index << 32,
            selectionPrefix: selectionPrefix,
            renderAllBlocks: renderAllBlocks,
          ),
        );
      },
    );
  }

  List<String> _selectionPrefixes() {
    final prefixes = List<String>.filled(markdown.blocks.length, '');
    var hasContent = false;
    var pending = '';

    for (var index = 0; index < markdown.blocks.length; index++) {
      final block = markdown.blocks[index];
      if (block case MD$Spacer(:final count)) {
        if (hasContent && pending.isEmpty) pending = '\n';
        pending += '\n' * count;
        continue;
      }
      if (block is MD$Divider) {
        pending += '\n';
        continue;
      }

      if (hasContent && pending.isEmpty) pending = '\n';
      prefixes[index] = pending;
      pending = '';
      hasContent = true;
    }

    return prefixes;
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
