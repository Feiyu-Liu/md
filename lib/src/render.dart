//ignore_for_file: unnecessary_import

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart' as meta show internal;

import 'animation/animated_block_painter.dart';
import 'animation/animation_config.dart';
import 'markdown.dart';
import 'nodes.dart';
import 'theme.dart';

@meta.internal
class MarkdownRenderObject extends RenderBox implements TickerProvider {
  MarkdownRenderObject({
    required Markdown markdown,
    required MarkdownThemeData theme,
    MarkdownAnimationConfig animationConfig = MarkdownAnimationConfig.disabled,
    ValueNotifier<bool>? isStreamingComplete,
    VoidCallback? onAnimationComplete,
  })  : _animationConfig = animationConfig,
        _isStreamingComplete = isStreamingComplete,
        _externalOnAnimationComplete = onAnimationComplete,
        _painter = MarkdownPainter(
          markdown: markdown,
          theme: theme,
          animationConfig: animationConfig,
          isStreamingComplete: isStreamingComplete,
        ) {
    // Set the animation complete callback after construction
    // 在构造后设置动画完成回调
    _painter.onAnimationComplete = _handleAnimationComplete;

    // Listen to streaming complete changes
    _isStreamingComplete?.addListener(_handleStreamingCompleteChanged);
  }

  /// Painter for rendering markdown content.
  /// 用于渲染 Markdown 内容的绘制器
  final MarkdownPainter _painter;

  /// Animation configuration.
  /// 动画配置
  MarkdownAnimationConfig _animationConfig;

  /// Notifier indicating whether streaming is complete.
  /// 流式输出是否完成的通知器
  ValueNotifier<bool>? _isStreamingComplete;

  /// Whether animation has been disabled due to streaming completion.
  /// This flag persists across widget rebuilds to prevent animation replay.
  /// 动画是否因流式完成而被禁用。
  /// 此标志在 widget 重建时保持不变，以防止动画重播。
  bool _animationDisabledByCompletion = false;

  /// External callback for animation completion.
  /// 外部动画完成回调
  VoidCallback? _externalOnAnimationComplete;

  /// Set of active tickers for animation.
  /// 用于动画的活动 Ticker 集合
  Set<Ticker>? _tickers;

  /// Handles streaming complete state changes.
  /// 处理流式输出完成状态变化
  void _handleStreamingCompleteChanged() {
    // When streaming complete state changes, request repaint
    // 当流式输出完成状态变化时，请求重绘
    markNeedsPaint();
  }

  /// Handles animation completion callback from the painter.
  /// Disables animations to prevent them from replaying on widget rebuilds.
  /// 处理来自绘制器的动画完成回调
  /// 禁用动画以防止它们在 widget 重建时重播
  void _handleAnimationComplete() {
    if (_animationConfig.enabled && _animationConfig.disableOnComplete) {
      // Mark that animation has been disabled due to completion
      // 标记动画已因完成而被禁用
      _animationDisabledByCompletion = true;

      // Create a disabled version of the current config
      // 创建当前配置的禁用版本
      _animationConfig = MarkdownAnimationConfig(
        enabled: false,
        duration: _animationConfig.duration,
        curve: _animationConfig.curve,
        opacityRange: _animationConfig.opacityRange,
        offsetRange: _animationConfig.offsetRange,
        blurRange: _animationConfig.blurRange,
        disableOnComplete: _animationConfig.disableOnComplete,
      );

      // Update the painter with the disabled config
      // 使用禁用的配置更新绘制器
      _painter.animationConfig = _animationConfig;

      // Notify external listener (Widget layer) about animation completion
      // 通知外部监听器（Widget 层）动画已完成
      _externalOnAnimationComplete?.call();

      // Request repaint to apply the change
      // 请求重绘以应用更改
      markNeedsPaint();
    }
  }

  @override
  Ticker createTicker(TickerCallback onTick) {
    _tickers ??= <Ticker>{};
    final ticker = Ticker(onTick, debugLabel: 'created by $this');
    _tickers!.add(ticker);
    return ticker;
  }

  /// Current size of the render box.
  /// 渲染盒的当前尺寸
  @override
  Size get size => _size;
  Size _size = Size.zero;

  @override
  bool get isRepaintBoundary => false;

  @override
  bool get alwaysNeedsCompositing => false;

  @override
  bool get sizedByParent => false;

  @override
  set size(Size value) {
    final prev = super.hasSize ? super.size : null;
    super.size = value;
    if (prev == value) return;
    _size = value;
  }

  @override
  void debugResetSize() {
    super.debugResetSize();
    if (!super.hasSize) return;
    _size = super.size;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(_painter.layout(maxWidth: constraints.maxWidth));

  @override
  void performLayout() {
    // Set the size of the render box to match the painter's size.
    // 设置渲染盒的尺寸以匹配绘制器的尺寸
    size =
        constraints.constrain(_painter.layout(maxWidth: constraints.maxWidth));
  }

  @override
  // ignore: unnecessary_overrides
  void performResize() {
    size = computeDryLayout(constraints);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(
    BoxHitTestResult result, {
    required Offset position,
  }) =>
      false;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    var hitTarget = false;
    if (size.contains(position)) {
      hitTarget = hitTestSelf(position);
      result.add(BoxHitTestEntry(this, position));
    }
    return hitTarget;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    _painter.handleEvent(event);
  }

  /// Handles system font changes by marking the render object as needing layout
  /// 处理系统字体变化，将渲染对象标记为需要重新布局
  void _handleSystemFontsChange() {
    // Invalidate cached layouts in painter and all block painters
    // 使绘制器和所有块绘制器中的缓存布局失效
    _painter.invalidateLayout();
    // Request new layout and paint
    // 请求新的布局和绘制
    markNeedsLayout();
  }

  @override
  // ignore: unnecessary_overrides
  void attach(PipelineOwner owner) {
    super.attach(owner);
    PaintingBinding.instance.systemFonts.addListener(_handleSystemFontsChange);

    // Initialize the painter with TickerProvider if animation is enabled
    // 如果启用了动画，则使用 TickerProvider 初始化绘制器
    if (_animationConfig.enabled) {
      _painter.initializeAnimations(this);
    }
  }

  /// Updates the render object with a new values.
  /// This method should be called whenever the markdown or theme changes.
  /// 使用新值更新渲染对象
  /// 每当 Markdown 或主题发生变化时都应调用此方法
  @meta.internal
  void update({
    required Markdown markdown,
    required MarkdownThemeData theme,
    MarkdownAnimationConfig animationConfig = MarkdownAnimationConfig.disabled,
    ValueNotifier<bool>? isStreamingComplete,
    VoidCallback? onAnimationComplete,
  }) {
    // Update external animation complete callback
    // 更新外部动画完成回调
    _externalOnAnimationComplete = onAnimationComplete;
    // Update streaming complete notifier
    if (_isStreamingComplete != isStreamingComplete) {
      _isStreamingComplete?.removeListener(_handleStreamingCompleteChanged);
      _isStreamingComplete = isStreamingComplete;
      _isStreamingComplete?.addListener(_handleStreamingCompleteChanged);
    }

    // If animation was disabled due to completion, keep it disabled
    // even if the widget passes enabled: true
    // 如果动画因完成而被禁用，即使 widget 传入 enabled: true 也保持禁用
    MarkdownAnimationConfig effectiveConfig = animationConfig;
    if (_animationDisabledByCompletion && animationConfig.disableOnComplete) {
      effectiveConfig = MarkdownAnimationConfig(
        enabled: false,
        duration: animationConfig.duration,
        curve: animationConfig.curve,
        opacityRange: animationConfig.opacityRange,
        offsetRange: animationConfig.offsetRange,
        blurRange: animationConfig.blurRange,
        disableOnComplete: animationConfig.disableOnComplete,
      );
    }

    _animationConfig = effectiveConfig;

    // Update the painter callback to ensure it always points to the current method
    // 更新绘制器回调以确保它始终指向当前方法
    _painter.onAnimationComplete = _handleAnimationComplete;

    if (_painter.update(
      markdown: markdown,
      theme: theme,
      animationConfig: effectiveConfig,
      isStreamingComplete: isStreamingComplete,
    )) {
      // Mark the render object as needing layout.
      // 将渲染对象标记为需要重新布局
      markNeedsLayout();
    }

    // If there are active animations, request repaint
    // 如果有活动的动画，请求重绘
    if (_painter.hasActiveAnimations) {
      markNeedsPaint();
    }
  }

  @override
  @protected
  void detach() {
    PaintingBinding.instance.systemFonts
        .removeListener(_handleSystemFontsChange);
    _isStreamingComplete?.removeListener(_handleStreamingCompleteChanged);
    super.detach();
  }

  @override
  @protected
  void dispose() {
    _isStreamingComplete?.removeListener(_handleStreamingCompleteChanged);
    // Dispose all tickers
    // 释放所有 tickers
    if (_tickers != null) {
      for (final ticker in _tickers!) {
        ticker.dispose();
      }
      _tickers = null;
    }

    _painter.dispose();
    super.dispose();
  }

  @override
  @protected
  void paint(PaintingContext context, Offset offset) {
    if (_painter.isEmpty)
      return; // If the markdown is empty, do not paint anything.
    // 如果 Markdown 为空，则不绘制任何内容

    // ignore: unused_local_variable
    final canvas = context.canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    //..clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    _painter.paint(canvas, size);

    canvas.restore();

    // If there are active animations, schedule another paint
    // 如果有活动的动画，安排另一次绘制
    if (_painter.hasActiveAnimations) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (attached) {
          markNeedsPaint();
        }
      });
    }
  }
}

/// A painter for rendering markdown content via blocks and spans.
/// 通过块和跨度渲染 Markdown 内容的绘制器
@meta.internal
class MarkdownPainter {
  /// Creates a [MarkdownPainter] instance.
  /// 创建一个 [MarkdownPainter] 实例
  MarkdownPainter({
    required Markdown markdown,
    required MarkdownThemeData theme,
    this.animationConfig = MarkdownAnimationConfig.disabled,
    ValueNotifier<bool>? isStreamingComplete,
    this.onAnimationComplete,
  })  : _markdown = markdown,
        _theme = theme,
        _isStreamingComplete = isStreamingComplete,
        _isEmpty = _getClosedBlocks(markdown, isStreamingComplete).isEmpty,
        _size = Size.zero {
    _rebuild();
  }

  /// Callback invoked when animations should be disabled after streaming completes.
  /// 当流式完成后应禁用动画时调用的回调
  ///
  /// This is called when:
  /// - Streaming is complete (isStreamingComplete.value == true)
  /// - The last block's animation has finished
  /// - [animationConfig.disableOnComplete] is true
  ///
  /// The callback should update the animation config to disable animations,
  /// preventing them from replaying on subsequent widget rebuilds.
  VoidCallback? onAnimationComplete;

  /// Animation configuration.
  /// 动画配置
  MarkdownAnimationConfig animationConfig;

  /// Notifier indicating whether streaming is complete.
  /// 流式输出是否完成的通知器
  ValueNotifier<bool>? _isStreamingComplete;

  /// Get closed blocks based on streaming state.
  /// 根据流式输出状态获取已闭合的块
  static List<MD$Block> _getClosedBlocks(
    Markdown markdown,
    ValueNotifier<bool>? isStreamingComplete,
  ) {
    final blocks = markdown.blocks;
    if (blocks.isEmpty) return blocks;

    // If streaming is complete, all blocks are closed
    // 如果流式输出完成，所有块都是闭合的
    if (isStreamingComplete?.value ?? false) {
      return blocks;
    }

    // Otherwise, all blocks except the last one are closed
    // 否则，除了最后一个块之外的所有块都是闭合的
    if (blocks.length == 1) return const <MD$Block>[];
    return blocks.sublist(0, blocks.length - 1);
  }

  /// TickerProvider for creating AnimationControllers.
  /// 用于创建 AnimationController 的 TickerProvider
  TickerProvider? _vsync;

  /// AnimationControllers for each closed block.
  /// 每个已闭合块的 AnimationController
  List<AnimationController> _controllers = [];

  /// Opacity animations for each closed block.
  /// 每个已闭合块的透明度动画
  List<Animation<double>?> _opacityAnimations = [];

  /// Offset animations for each closed block.
  /// 每个已闭合块的位移动画
  List<Animation<double>?> _offsetAnimations = [];

  /// Blur animations for each closed block.
  /// 每个已闭合块的模糊动画
  List<Animation<double>?> _blurAnimations = [];

  /// Number of closed blocks from the last rebuild.
  /// 上次重建时的已闭合块数量
  int _lastClosedCount = 0;

  /// Whether streaming completion has been detected.
  /// 是否已检测到流式完成
  bool _streamingCompleteDetected = false;

  /// Whether a completion listener has been added to the last animation.
  /// 是否已为最后一个动画添加完成监听器
  bool _lastAnimationCompletionListenerAdded = false;

  /// Whether there are active animations.
  /// 是否有活动的动画
  bool get hasActiveAnimations =>
      animationConfig.enabled && _controllers.any((c) => c.isAnimating);

  /// Is the markdown entity empty?
  /// Markdown 实体是否为空？
  bool get isEmpty => _isEmpty;
  bool _isEmpty;

  /// Current markdown entity to render.
  /// 要渲染的当前 Markdown 实体
  Markdown _markdown;

  /// Current theme for the markdown widget.
  /// Markdown 组件的当前主题
  MarkdownThemeData _theme;

  /// The size of the painted markdown content.
  /// 绘制的 Markdown 内容的尺寸
  Size get size => _size;
  Size _size;

  /// Indicates if the layout needs to be recalculated.
  /// 指示是否需要重新计算布局
  bool _needsLayout = true;

  Float32List _blockOffsets = Float32List(0);
  List<BlockPainter> _blockPainters = const <BlockPainter>[];

  static BlockPainter _defaultBlockBuilder(
    MD$Block block,
    MarkdownThemeData theme,
  ) =>
      block.map<BlockPainter>(
        paragraph: (p) => BlockPainter$Paragraph(
          spans: p.spans,
          theme: theme,
        ),
        heading: (h) => BlockPainter$Heading(
          level: h.level,
          spans: h.spans,
          theme: theme,
        ),
        quote: (q) => BlockPainter$Quote(
          spans: q.spans,
          indent: q.indent,
          theme: theme,
        ),
        code: (c) => BlockPainter$Code(
          language: c.language,
          text: c.text,
          theme: theme,
        ),
        list: (l) => BlockPainter$List(
          items: l.items,
          theme: theme,
        ),
        divider: (d) => BlockPainter$Divider(
          theme: theme,
        ),
        table: (t) => BlockPainter$Table(
          header: t.header,
          rows: t.rows,
          theme: theme,
        ),
        spacer: (s) => BlockPainter$Spacer(
          count: s.count,
          theme: theme,
        ),
      );

  /// Initialize animations with a TickerProvider.
  /// 使用 TickerProvider 初始化动画
  void initializeAnimations(TickerProvider vsync) {
    _vsync = vsync;
    if (animationConfig.enabled) {
      _rebuildAnimations();
    }
  }

  /// Rebuilds the block painters from the markdown blocks.
  /// This method is called whenever the markdown or theme changes.
  /// 从 Markdown 块重建块绘制器
  /// 每当 Markdown 或主题发生变化时都会调用此方法
  void _rebuild() {
    _needsLayout = true; // Mark that layout needs to be recalculated.
    // 标记需要重新计算布局
    _size = Size.zero; // Reset size before rebuilding.
    // 在重建之前重置尺寸

    // Only render closed blocks when animation is enabled
    // 启用动画时只渲染已闭合的块
    final blocksToRender = animationConfig.enabled
        ? _getClosedBlocks(_markdown, _isStreamingComplete)
        : _markdown.blocks;

    _isEmpty = blocksToRender.isEmpty;

    final filter = _theme.blockFilter;
    final filtered =
        filter != null ? blocksToRender.where(filter) : blocksToRender;
    final builder = _theme.builder ?? _defaultBlockBuilder;

    // Create raw painters
    final rawPainters = filtered
        .map<BlockPainter>(
          (block) =>
              builder(block, _theme) ?? _defaultBlockBuilder(block, _theme),
        )
        .toList(growable: false);

    // Wrap with animation if enabled and vsync is available
    if (animationConfig.enabled && _vsync != null) {
      _rebuildWithAnimations(rawPainters);
    } else {
      // Dispose old controllers if any
      for (final controller in _controllers) {
        controller.dispose();
      }
      _controllers = [];
      _opacityAnimations = [];
      _offsetAnimations = [];
      _blurAnimations = [];
      _blockPainters = rawPainters;
    }

    _blockOffsets = Float32List(_blockPainters.length);
  }

  /// Rebuild animations for the painters.
  /// 为绘制器重建动画
  void _rebuildAnimations() {
    if (_vsync == null || !animationConfig.enabled) return;

    final blocksToRender = _getClosedBlocks(_markdown, _isStreamingComplete);
    _isEmpty = blocksToRender.isEmpty;

    final filter = _theme.blockFilter;
    final filtered =
        filter != null ? blocksToRender.where(filter) : blocksToRender;
    final builder = _theme.builder ?? _defaultBlockBuilder;

    final rawPainters = filtered
        .map<BlockPainter>(
          (block) =>
              builder(block, _theme) ?? _defaultBlockBuilder(block, _theme),
        )
        .toList(growable: false);

    _rebuildWithAnimations(rawPainters);
    _blockOffsets = Float32List(_blockPainters.length);
    _needsLayout = true;
  }

  /// Rebuild painters with animation wrappers.
  /// 使用动画包装器重建绘制器
  void _rebuildWithAnimations(List<BlockPainter> rawPainters) {
    final oldCount = _controllers.length;
    final newCount = rawPainters.length;

    // Check if this is a rebuild of an already completed message
    // If streaming is complete and we have no existing controllers,
    // this means the RenderObject was recreated for an already completed message.
    // In this case, we should NOT play animations.
    // 检查这是否是已完成消息的重建
    // 如果流式已完成且没有现有控制器，说明 RenderObject 是为已完成的消息重新创建的
    // 在这种情况下，不应该播放动画
    final isStreamingComplete = _isStreamingComplete?.value ?? false;
    final isRebuildOfCompletedMessage = isStreamingComplete && oldCount == 0 && newCount > 0;

    // Keep old controllers that are still valid
    final oldControllers = List<AnimationController>.from(_controllers);
    final oldOpacityAnimations =
        List<Animation<double>?>.from(_opacityAnimations);
    final oldOffsetAnimations =
        List<Animation<double>?>.from(_offsetAnimations);
    final oldBlurAnimations = List<Animation<double>?>.from(_blurAnimations);

    // Create new controllers list
    _controllers = List.generate(newCount, (i) {
      if (i < oldCount) {
        // Reuse old controller
        return oldControllers[i];
      } else {
        // Create new controller for newly closed block
        final controller = AnimationController(
          duration: animationConfig.duration,
          vsync: _vsync!,
        );
        return controller;
      }
    });

    // Create new animations lists
    _opacityAnimations = List.generate(newCount, (i) {
      if (i < oldCount) {
        // Reuse old animation
        return oldOpacityAnimations[i];
      } else {
        // Create new animation if opacity range is provided
        final opacityRange = animationConfig.opacityRange;
        if (opacityRange != null) {
          return Tween<double>(
            begin: opacityRange.start,
            end: opacityRange.end,
          ).animate(
            CurvedAnimation(
              parent: _controllers[i],
              curve: animationConfig.curve,
            ),
          );
        }
        return null;
      }
    });

    _offsetAnimations = List.generate(newCount, (i) {
      if (i < oldCount) {
        // Reuse old animation
        return oldOffsetAnimations[i];
      } else {
        // Create new animation if offset range is provided
        final offsetRange = animationConfig.offsetRange;
        if (offsetRange != null) {
          return Tween<double>(
            begin: offsetRange.start,
            end: offsetRange.end,
          ).animate(
            CurvedAnimation(
              parent: _controllers[i],
              curve: animationConfig.curve,
            ),
          );
        }
        return null;
      }
    });

    _blurAnimations = List.generate(newCount, (i) {
      if (i < oldCount) {
        // Reuse old animation
        return oldBlurAnimations[i];
      } else {
        // Create new animation if blur range is provided
        final blurRange = animationConfig.blurRange;
        if (blurRange != null) {
          return Tween<double>(
            begin: blurRange.start,
            end: blurRange.end,
          ).animate(
            CurvedAnimation(
              parent: _controllers[i],
              curve: animationConfig.curve,
            ),
          );
        }
        return null;
      }
    });

    // Wrap painters with animation
    _blockPainters = List.generate(newCount, (i) {
      return AnimatedBlockPainter(
        inner: rawPainters[i],
        opacityAnimation: _opacityAnimations[i],
        offsetAnimation: _offsetAnimations[i],
        blurAnimation: _blurAnimations[i],
      );
    });

    // Start animations for newly closed blocks
    // But skip if this is a rebuild of an already completed message
    // 为新闭合的 blocks 启动动画
    // 但如果这是已完成消息的重建，则跳过
    if (isRebuildOfCompletedMessage) {
      // For completed messages being rebuilt, set all controllers to completed state
      // 对于正在重建的已完成消息，将所有控制器设置为完成状态
      for (var i = 0; i < newCount; i++) {
        _controllers[i].value = 1.0; // Set to end value without animation
      }
    } else {
      // Normal case: start animations for newly closed blocks
      // 正常情况：为新闭合的 blocks 启动动画
      for (var i = oldCount; i < newCount; i++) {
        _controllers[i].forward();
      }
    }

    // Dispose excess old controllers
    for (var i = newCount; i < oldCount; i++) {
      oldControllers[i].dispose();
    }

    _lastClosedCount = newCount;

    // Handle streaming completion and auto-disable animation
    // 处理流式完成和自动禁用动画
    _handleStreamingCompletionAndAutoDisable();
  }

  /// Handles streaming completion detection and adds completion listener to last animation.
  /// 处理流式完成检测并向最后一个动画添加完成监听器
  void _handleStreamingCompletionAndAutoDisable() {
    // Check if streaming is complete and disableOnComplete is enabled
    // 检查流式是否完成且启用了 disableOnComplete
    final isStreamingComplete = _isStreamingComplete?.value ?? false;
    final shouldAutoDisable = animationConfig.disableOnComplete;

    if (!shouldAutoDisable) {
      // Reset tracking flags if auto-disable is not enabled
      // 如果未启用自动禁用，重置跟踪标志
      _streamingCompleteDetected = false;
      _lastAnimationCompletionListenerAdded = false;
      return;
    }

    // Detect transition to streaming complete state
    // 检测到流式完成状态的转换
    if (isStreamingComplete && !_streamingCompleteDetected) {
      _streamingCompleteDetected = true;
    }

    // If streaming is complete and we haven't added a listener yet
    // 如果流式完成且尚未添加监听器
    if (_streamingCompleteDetected && !_lastAnimationCompletionListenerAdded) {
      // Get the last controller (the final block's animation)
      // 获取最后一个控制器（最终块的动画）
      if (_controllers.isNotEmpty) {
        final lastController = _controllers.last;

        // Check if animation is already completed
        // 检查动画是否已经完成
        if (lastController.status == AnimationStatus.completed) {
          // Animation already completed, notify immediately
          // 动画已完成，立即通知
          _lastAnimationCompletionListenerAdded = true;
          if (onAnimationComplete != null) {
            onAnimationComplete!();
          }
          return;
        }

        // Add status listener to detect animation completion
        // 添加状态监听器以检测动画完成
        void statusListener(AnimationStatus status) {
          if (status == AnimationStatus.completed && onAnimationComplete != null) {
            // Remove the listener to avoid multiple calls
            // 移除监听器以避免多次调用
            lastController.removeStatusListener(statusListener);

            // Notify the render object to disable animations
            // 通知渲染对象禁用动画
            onAnimationComplete!();
          }
        }

        lastController.addStatusListener(statusListener);
        _lastAnimationCompletionListenerAdded = true;
      }
    }
  }

  /// Update the painter with new values.
  /// If the values are the same,
  /// no update is required and the method returns false.
  /// 使用新值更新绘制器
  /// 如果值相同，则不需要更新，方法返回 false
  bool update({
    required Markdown markdown,
    required MarkdownThemeData theme,
    MarkdownAnimationConfig animationConfig = MarkdownAnimationConfig.disabled,
    ValueNotifier<bool>? isStreamingComplete,
  }) {
    final configChanged = this.animationConfig != animationConfig;
    final streamingCompleteChanged =
        _isStreamingComplete != isStreamingComplete;

    this.animationConfig = animationConfig;
    _isStreamingComplete = isStreamingComplete;

    // Check if closed block count changed (for animation)
    final oldClosedCount = _lastClosedCount;
    final newClosedBlocks = _getClosedBlocks(markdown, isStreamingComplete);
    final newClosedCount = newClosedBlocks.length;
    final closedCountChanged = newClosedCount != oldClosedCount;

    if (identical(_markdown, markdown) &&
        identical(_theme, theme) &&
        !configChanged &&
        !closedCountChanged &&
        !streamingCompleteChanged) {
      return false;
    }

    _lastSize = null;
    _lastPicture = null;
    _markdown = markdown;
    _theme = theme;
    _isEmpty = animationConfig.enabled
        ? newClosedBlocks.isEmpty
        : markdown.isEmpty;

    // If animation is enabled and vsync is available, rebuild with animations
    if (animationConfig.enabled && _vsync != null) {
      _rebuildAnimations();
    } else {
      _rebuild();
    }

    return true; // Indicate that the painter was updated.
    // 指示绘制器已更新
  }

  /// Invalidate cached layouts when system fonts change.
  /// This forces TextPainters to recreate their layouts with new fonts.
  /// 当系统字体更改时使缓存的布局失效
  /// 这会强制 TextPainters 使用新字体重新创建其布局
  void invalidateLayout() {
    _needsLayout = true;
    _lastSize = null;
    _lastPicture = null;
    // Dispose and rebuild all block painters to recreate TextPainters
    // with the new system fonts
    // 释放并重建所有块绘制器，以使用新的系统字体重新创建 TextPainters
    for (final painter in _blockPainters) {
      painter.dispose();
    }
    _rebuild();
  }

  /// Layouts the markdown content with the given width.
  /// 使用给定的宽度布局 Markdown 内容
  Size layout({required double maxWidth}) {
    if (_isEmpty) {
      _size = Size.zero;
      _needsLayout = false; // No need to layout if the markdown is empty.
      // 如果 Markdown 为空，则无需布局
      return _size; // If the markdown is empty, return zero size.
      // 如果 Markdown 为空，则返回零尺寸
    }
    var width = .0, height = .0;
    final blocks = _blockPainters;
    if (_blockOffsets.length != blocks.length) {
      // Resize the block sizes array
      // if it does not match the number of painters.
      // 如果块尺寸数组与绘制器数量不匹配，则调整其大小
      _blockOffsets = Float32List(blocks.length);
    }
    final offsets = _blockOffsets;
    for (var i = 0; i < blocks.length; i++) {
      offsets[i] = height;
      final block = blocks[i];
      final size = block.layout(maxWidth);
      width = math.max(width, size.width);
      height += size.height;
    }
    _needsLayout = false; // No need to layout if the markdown is empty.
    // 如果 Markdown 为空，则无需布局
    return _size = Size(width, height);
  }

  /// Get the painter from the array by the vertical local position (dy).
  /// 通过垂直本地位置 (dy) 从数组中获取绘制器
  /* static BlockPainter? _getPainterByHeight(
    Iterable<BlockPainter> painters,
    double dy,
  ) {
    var offset = .0;
    BlockPainter? result;
    for (var painter in painters) {
      if (dy < offset) break;
      result = painter;
      offset += painter.size.height; // Update the offset for the next block.
    }
    return result;
  } */

  void handleEvent(PointerEvent event) {
    if (_blockPainters.isEmpty) return;
    // event.buttons, event.kind, event.position
    // event.localPosition, event.delta, event.down

    // Only handle pointer down events for now.
    // You can extend this to handle other pointer events if needed.
    // 目前仅处理指针按下事件
    // 如果需要，您可以扩展此功能以处理其他指针事件
    if (event is! PointerDownEvent && event is! PointerUpEvent) return;

    final pos = event.localPosition;
    {
      // Binary search to find the block painter by the vertical position.
      // 通过二分查找根据垂直位置找到块绘制器
      final dy = pos.dy;
      var min = 0;
      var max = _blockPainters.length;
      var idx = 0;
      while (min < max) {
        final mid = min + ((max - min) >> 1);
        final offset = _blockOffsets[mid];
        //final comp = offset.compareTo(dy);
        var comp = 0;
        if (offset > dy) {
          // The offset is greater than the position.
          // 偏移量大于位置
          comp = 1;
        } else {
          idx = mid; // Remember the index of the block painter.
          // 记住块绘制器的索引
          // The offset is less than or equal to the position.
          // 偏移量小于或等于位置
          comp = offset < dy ? -1 : 0;
        }
        if (comp == 0) {
          break; // Found the exact match.
          // 找到精确匹配
        } else if (comp < 0) {
          min = mid + 1;
        } else {
          max = mid;
        }
      }
      switch (event) {
        case PointerDownEvent():
          final blockTapEvent = PointerDownEvent(
            // Adjust the position by the block offset.
            // 根据块偏移量调整位置
            position: Offset(
              pos.dx,
              pos.dy - _blockOffsets[idx],
            ),
            viewId: event.viewId,
            timeStamp: event.timeStamp,
            pointer: event.pointer,
            kind: event.kind,
            device: event.device,
            buttons: event.buttons,
            obscured: event.obscured,
            pressure: event.pressure,
            pressureMin: event.pressureMin,
            pressureMax: event.pressureMax,
            distanceMax: event.distanceMax,
            size: event.size,
            radiusMajor: event.radiusMajor,
            radiusMinor: event.radiusMinor,
            radiusMin: event.radiusMin,
            radiusMax: event.radiusMax,
            orientation: event.orientation,
            tilt: event.tilt,
            embedderId: event.embedderId,
          );
          _blockPainters[idx].handleTapDown(blockTapEvent);
        case PointerUpEvent():
          final blockTapEvent = PointerUpEvent(
            // Adjust the position by the block offset.
            // 根据块偏移量调整位置
            position: Offset(
              pos.dx,
              pos.dy - _blockOffsets[idx],
            ),
            viewId: event.viewId,
            timeStamp: event.timeStamp,
            pointer: event.pointer,
            kind: event.kind,
            device: event.device,
            buttons: event.buttons,
            obscured: event.obscured,
            pressure: event.pressure,
            pressureMin: event.pressureMin,
            pressureMax: event.pressureMax,
            distanceMax: event.distanceMax,
            size: event.size,
            radiusMajor: event.radiusMajor,
            radiusMinor: event.radiusMinor,
            radiusMin: event.radiusMin,
            radiusMax: event.radiusMax,
            orientation: event.orientation,
            tilt: event.tilt,
            embedderId: event.embedderId,
          );
          _blockPainters[idx].handleTapUp(blockTapEvent);
      }
    }

    // We can use the position to determine which block was hit.
    // 我们可以使用位置来确定哪个块被点击
    //_getPainterByHeight(_blockPainters, pos.dy)?.handleEvent(event);

    // Handle taps for the links with urls.
    // 处理带有 URL 的链接的点击
    /* switch (event) {
      case PointerDownEvent(down: true):
      // Handle pointer down events.
      default:
        // Handle other pointer events if needed.
        break;
    } */
  }

  /// The last size and picture used for painting.
  /// This is used to avoid unnecessary recreation of the canvas picture.
  /// If the size is the same as the last painted size,
  /// 用于绘制的最后尺寸和图片
  /// 这用于避免不必要地重新创建画布图片
  /// 如果尺寸与上次绘制的尺寸相同
  Size? _lastSize;

  /// The last picture used for painting,
  /// to avoid unnecessary recreation of the canvas picture.
  /// If the size is the same as the last painted size,
  /// we can reuse the last picture.
  /// 用于绘制的最后图片
  /// 以避免不必要地重新创建画布图片
  /// 如果尺寸与上次绘制的尺寸相同，我们可以重用最后的图片
  Picture? _lastPicture;

  /// The markdown content to paint.
  /// 要绘制的 Markdown 内容
  void paint(Canvas canvas, Size size) {
    assert(
      !_needsLayout,
      'MarkdownPainter.paint() called without layout.',
    );
    assert(
      size.isFinite,
      'MarkdownPainter.paint() called with non-finite size: $size',
    );

    // Do not paint if the markdown is empty,
    // or if the size is empty or infinite.
    // 如果 Markdown 为空，或者尺寸为空或无限，则不绘制
    if (_isEmpty || size.isEmpty || size.isInfinite) return;

    // Disable caching when animations are active
    // 当动画活动时禁用缓存
    final shouldCache = !hasActiveAnimations;

    if (shouldCache && _lastSize == size && _lastPicture != null) {
      // If the size is the same as the last painted size,
      // we can reuse the last picture.
      // 如果尺寸与上次绘制的尺寸相同，我们可以重用最后的图片
      canvas.drawPicture(_lastPicture!);
      return;
    }

    final recorder = PictureRecorder();
    final $canvas = Canvas(recorder);

    // Paint each block painter on the canvas.
    // 在画布上绘制每个块绘制器
    var overflow = _size.height > size.height;
    var offset = .0;

    for (var painter in _blockPainters) {
      if (overflow && offset > size.height) {
        // If the painter's height exceeds the available height,
        // we stop painting further blocks.
        // 如果绘制器的高度超过可用高度，我们停止绘制更多块
        break;
      }
      painter.paint($canvas, size, offset);
      offset += painter.size.height; // Update the offset for the next block.
      // 更新下一个块的偏移量
    }

    final picture = recorder.endRecording();
    canvas.drawPicture(picture);

    // Only cache when no animations are active
    // 仅在没有活动动画时缓存
    if (shouldCache) {
      _lastSize = size;
      _lastPicture = picture;
    } else {
      picture.dispose();
    }
  }

  void dispose() {
    _lastPicture?.dispose();
    _lastPicture = null;

    // Dispose all animation controllers
    // 释放所有动画控制器
    for (final controller in _controllers) {
      controller.dispose();
    }
    _controllers = [];
    _opacityAnimations = [];
    _offsetAnimations = [];
    _blurAnimations = [];

    for (final painter in _blockPainters) {
      painter.dispose();
    }
    _blockPainters = const <BlockPainter>[];
  }
}

/* InlineSpan _imageFromMarkdownSpan({
  required MD$Span span,
  required MarkdownThemeData theme,
}) {
  final url = span.extra?['url'];
  if (url is! String || url.isEmpty) return const TextSpan();
  ImageProvider? provider;
  if (url.startsWith('http://') || url.startsWith('https://')) {
    provider = NetworkImage(url);
  } else if (url.startsWith('asset://')) {
    provider = AssetImage(Uri.parse(url).toFilePath());
  } else if (kIsWeb) {
    provider = NetworkImage(url);
  } else {
    return const TextSpan();
  }
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: SizedBox.square(
      dimension: 48, // Fixed size for the image.
      child: Image(
        image: provider,
        width: 48,
        height: 48,
        filterQuality: FilterQuality.medium,
        fit: BoxFit.scaleDown,
      ),
    ),
  );
} */

/// Builds a tap recognizer for the given markdown span.
/// 为给定的 Markdown 跨度构建点击识别器
TapGestureRecognizer? _buildTapRecognizer(
  MD$Span span,
  void Function(String title, String url)? onTap,
) {
  if (onTap == null) return null;
  if (span.extra case <String, Object?>{'url': String url}) {
    return TapGestureRecognizer()
      ..onTap = () {
        onTap(span.extra?['alt']?.toString() ?? span.text, url);
      };
  }
  return null;
}

/// Helper function to create a [TextSpan] from markdown spans.
/// This function filters the spans based on the theme's span filter,
/// and applies the appropriate text style to each span.
/// 从 Markdown 跨度创建 [TextSpan] 的辅助函数
/// 此函数根据主题的跨度过滤器过滤跨度，并将适当的文本样式应用于每个跨度
TextSpan _paragraphFromMarkdownSpans({
  required Iterable<MD$Span> spans,
  required MarkdownThemeData theme,
  TextStyle? textStyle,
}) {
  final style = textStyle ?? theme.textStyle;
  final spanFilter = theme.spanFilter;
  final filtered = spanFilter != null ? spans.where(spanFilter) : spans;
  final mapper = textStyle != null
      ? (MD$Span span) {
          return TextSpan(
            text: span.text,
            style: theme.textStyleFor(span.style).merge(style),
            recognizer: span.style.contains(MD$Style.link)
                ? _buildTapRecognizer(span, theme.onLinkTap)
                : null,
          );
        }
      : (MD$Span span) {
          return TextSpan(
            text: span.text,
            style: theme.textStyleFor(span.style),
            recognizer: span.style.contains(MD$Style.link)
                ? _buildTapRecognizer(span, theme.onLinkTap)
                : null,
          );
        };
  return TextSpan(
    style: textStyle ?? theme.textStyle,
    children: filtered.map<InlineSpan>(mapper).toList(growable: false),
  );
}

/// A class for painting blocks in markdown.
/// You can implement this interface to create custom block painters.
/// 用于在 Markdown 中绘制块的类
/// 您可以实现此接口来创建自定义块绘制器
abstract interface class BlockPainter {
  /// The current size of the block.
  /// Available only after [layout].
  /// 块的当前尺寸
  /// 仅在 [layout] 之后可用
  abstract final Size size;

  /// Handle tap pointer down events for the block.
  /// 处理块的点击指针按下事件
  void handleTapDown(PointerDownEvent event);

  /// Handle tap pointer up events for the block.
  /// 处理块的点击指针抬起事件
  void handleTapUp(PointerUpEvent event);

  /// Measure the block size with the given width.
  /// 使用给定的宽度测量块尺寸
  Size layout(double width);

  /// Paint the block on the canvas at the given offset.
  /// [canvas] is the canvas to paint on
  /// [size] the whole size of the markdown content
  /// [offset] is the vertical offset to paint the block at
  /// 在给定偏移量处在画布上绘制块
  /// [canvas] 是要绘制的画布
  /// [size] 是 Markdown 内容的整体尺寸
  /// [offset] 是绘制块的垂直偏移量
  void paint(Canvas canvas, Size size, double offset);

  /// Dispose all resources used by the painter.
  /// 释放绘制器使用的所有资源
  void dispose();
}

@meta.internal
mixin ParagraphGestureHandler {
  /// Handle tap events with a [TextPainter].
  /// 使用 [TextPainter] 处理点击事件
  @protected
  InlineSpan? hitTestInlineSpanWithPointerEvent(
      PointerEvent event, TextPainter painter) {
    final pos = painter.getPositionForOffset(event.localPosition);
    //final int index = pos.offset;
    final span = painter.text?.getSpanForPosition(pos);
    //final plainText = span?.toPlainText();
    //print('[${pos.offset}] $plainText');
    return span;
  }
}

/// A class for painting a paragraph block in markdown.
/// 用于在 Markdown 中绘制段落块的类
@meta.internal
class BlockPainter$Paragraph
    with ParagraphGestureHandler
    implements BlockPainter {
  BlockPainter$Paragraph({
    required List<MD$Span> spans,
    required this.theme,
  }) : painter = TextPainter(
          text: _paragraphFromMarkdownSpans(
            spans: spans,
            theme: theme,
          ),
          textAlign: TextAlign.start,
          textDirection: theme.textDirection,
          textScaler: theme.textScaler,
        );

  final MarkdownThemeData theme;

  final TextPainter painter;

  @override
  Size get size => _size;
  Size _size = Size.zero;

  /// Last span hit by the tap down event.
  /// 点击按下事件命中的最后一个跨度
  TextSpan? _lastSpan;

  @override
  void handleTapDown(PointerDownEvent event) {
    _lastSpan = null; // Reset the span on tap down.
    // 在点击按下时重置跨度
    final span = hitTestInlineSpanWithPointerEvent(event, painter);
    if (span case TextSpan textSpan) _lastSpan = textSpan;
  }

  @override
  void handleTapUp(PointerUpEvent event) {
    if (_lastSpan == null) return; // No span was hit on tap down.
    // 点击按下时没有命中跨度
    final span = hitTestInlineSpanWithPointerEvent(event, painter);
    if (span != null && _lastSpan == span) {
      // If the span is the same as the one hit on tap down,
      // call the tap recognizer.
      // 如果跨度与点击按下时命中的跨度相同，则调用点击识别器
      if (span case TextSpan(recognizer: TapGestureRecognizer(:var onTap)))
        onTap?.call();
    }
    _lastSpan = null; // Clear the span after handling the tap.
    // 处理点击后清除跨度
  }

  @override
  Size layout(double width) {
    painter.layout(
      minWidth: 0,
      maxWidth: width,
    );
    return _size = painter.size;
  }

  @override
  void paint(Canvas canvas, Size size, double offset) {
    // If the width is less than required do not paint anything.
    // 如果宽度小于所需宽度，则不绘制任何内容
    if (size.width < _size.width) return;
    painter.paint(
      canvas,
      Offset(0, offset),
    );
  }

  @override
  void dispose() {
    painter.dispose();
  }
}

/// A class for painting a paragraph block in markdown.
/// 用于在 Markdown 中绘制段落块的类
@meta.internal
class BlockPainter$Heading
    with ParagraphGestureHandler
    implements BlockPainter {
  BlockPainter$Heading({
    required int level,
    required List<MD$Span> spans,
    required this.theme,
  }) : painter = TextPainter(
          text: _paragraphFromMarkdownSpans(
            spans: spans,
            theme: theme,
            textStyle: theme.headingStyleFor(level),
          ),
          textAlign: TextAlign.start,
          textDirection: theme.textDirection,
          textScaler: theme.textScaler,
        );

  final MarkdownThemeData theme;

  final TextPainter painter;

  @override
  Size get size => _size;
  Size _size = Size.zero;

  /// Last span hit by the tap down event.
  /// 点击按下事件命中的最后一个跨度
  TextSpan? _lastSpan;

  @override
  void handleTapDown(PointerDownEvent event) {
    _lastSpan = null; // Reset the span on tap down.
    // 在点击按下时重置跨度
    final span = hitTestInlineSpanWithPointerEvent(event, painter);
    if (span case TextSpan textSpan) _lastSpan = textSpan;
  }

  @override
  void handleTapUp(PointerUpEvent event) {
    if (_lastSpan == null) return; // No span was hit on tap down.
    // 点击按下时没有命中跨度
    final span = hitTestInlineSpanWithPointerEvent(event, painter);
    if (span != null && _lastSpan == span) {
      // If the span is the same as the one hit on tap down,
      // call the tap recognizer.
      // 如果跨度与点击按下时命中的跨度相同，则调用点击识别器
      if (span case TextSpan(recognizer: TapGestureRecognizer(:var onTap)))
        onTap?.call();
    }
    _lastSpan = null; // Clear the span after handling the tap.
    // 处理点击后清除跨度
  }

  @override
  Size layout(double width) {
    painter.layout(
      minWidth: 0,
      maxWidth: width,
    );
    return _size = painter.size;
  }

  @override
  void paint(Canvas canvas, Size size, double offset) {
    // If the width is less than required do not paint anything.
    // 如果宽度小于所需宽度，则不绘制任何内容
    if (size.width < _size.width) return;
    painter.paint(
      canvas,
      Offset(0, offset),
    );
  }

  @override
  void dispose() {
    painter.dispose();
  }
}

/// A class for painting a quote block in markdown.
/// 用于在 Markdown 中绘制引用块的类
@meta.internal
class BlockPainter$Quote with ParagraphGestureHandler implements BlockPainter {
  BlockPainter$Quote({
    required List<MD$Span> spans,
    required this.indent,
    required this.theme,
  })  : painter = TextPainter(
          text: _paragraphFromMarkdownSpans(
            spans: spans,
            theme: theme,
            textStyle: theme.quoteStyle ?? theme.textStyle,
          ),
          textAlign: TextAlign.start,
          textDirection: theme.textDirection,
          textScaler: theme.textScaler,
        ),
        linePaint = Paint()
          ..color = theme.dividerColor ??
              const Color(0x7F7F7F7F) // Gray color for the line.
          ..isAntiAlias = false
          ..strokeWidth = 4.0
          ..style = PaintingStyle.fill;

  final MarkdownThemeData theme;

  final TextPainter painter;

  final int indent; // Indentation for quote blocks.
  // 引用块的缩进

  static const double lineIndent = 10.0; // Indentation for quote blocks.
  // 引用块的缩进

  final Paint linePaint;

  @override
  Size get size => _size;
  Size _size = Size.zero;

  /// Last span hit by the tap down event.
  /// 点击按下事件命中的最后一个跨度
  TextSpan? _lastSpan;

  @override
  void handleTapDown(PointerDownEvent event) {
    _lastSpan = null; // Reset the span on tap down.
    // 在点击按下时重置跨度
    final span = hitTestInlineSpanWithPointerEvent(event, painter);
    if (span case TextSpan textSpan) _lastSpan = textSpan;
  }

  @override
  void handleTapUp(PointerUpEvent event) {
    if (_lastSpan == null) return; // No span was hit on tap down.
    // 点击按下时没有命中跨度
    final span = hitTestInlineSpanWithPointerEvent(event, painter);
    if (span != null && _lastSpan == span) {
      // If the span is the same as the one hit on tap down,
      // call the tap recognizer.
      // 如果跨度与点击按下时命中的跨度相同，则调用点击识别器
      if (span case TextSpan(recognizer: TapGestureRecognizer(:var onTap)))
        onTap?.call();
    }
    _lastSpan = null; // Clear the span after handling the tap.
    // 处理点击后清除跨度
  }

  @override
  Size layout(double width) {
    // Adjust width for indentation.
    // 调整宽度以适应缩进
    painter.layout(
      minWidth: 0,
      maxWidth: math.max(width - lineIndent - indent * lineIndent, 0),
    );
    return _size = Size(
      painter.size.width + lineIndent + indent * lineIndent,
      painter.size.height,
    );
  }

  @override
  void paint(Canvas canvas, Size size, double offset) {
    // If the width is less than required do not paint anything.
    // 如果宽度小于所需宽度，则不绘制任何内容
    if (size.width < _size.width) return;

    // --- Draw vertical lines --- //
    // --- 绘制垂直线 --- //
    for (var i = 1; i <= indent; i++)
      canvas.drawLine(
        Offset(
          i * lineIndent,
          offset,
        ),
        Offset(
          i * lineIndent,
          offset + _size.height,
        ),
        linePaint,
      );

    painter.paint(
      canvas,
      Offset(
        lineIndent + indent * lineIndent,
        offset,
      ),
    );
  }

  @override
  void dispose() {
    painter.dispose();
  }
}

/// A helper class to store layout information for a single list item.
/// 用于存储单个列表项布局信息的辅助类
class _ListItemMetrics {
  _ListItemMetrics({
    required this.bulletPainter,
    required this.contentPainter,
    required this.offset,
  });

  final TextPainter bulletPainter;
  final TextPainter contentPainter;
  final Offset offset;

  late final double height =
      math.max(bulletPainter.height, contentPainter.height);
  late final Size size =
      Size(bulletPainter.width + contentPainter.width, height);

  void dispose() {
    bulletPainter.dispose();
    contentPainter.dispose();
  }
}

/// A class for painting a list block in markdown.
/// 用于在 Markdown 中绘制列表块的类
@meta.internal
class BlockPainter$List with ParagraphGestureHandler implements BlockPainter {
  BlockPainter$List({
    required List<MD$ListItem> items,
    required this.theme,
  })  : _items = items,
        _painters = <_ListItemMetrics>[];

  final MarkdownThemeData theme;
  final List<MD$ListItem> _items;
  final List<_ListItemMetrics> _painters;

  // Indentation for the entire list block.
  // 整个列表块的缩进
  static const double _baseIndent = 8.0;

  // Indentation for each level of nesting.
  // 每个嵌套级别的缩进
  static const double _levelIndent = 16.0;

  @override
  Size get size => _size;
  Size _size = Size.zero;

  /// Last span hit by the tap down event.
  /// 点击按下事件命中的最后一个跨度
  InlineSpan? _lastSpan;

  InlineSpan? _getSpanForPosition(Offset localPosition) {
    for (final metrics in _painters) {
      final contentOffset =
          metrics.offset + Offset(metrics.bulletPainter.width, 0);
      final contentRect = contentOffset & metrics.contentPainter.size;
      if (contentRect.contains(localPosition)) {
        final painterPosition = localPosition - contentOffset;
        final textPosition =
            metrics.contentPainter.getPositionForOffset(painterPosition);
        return metrics.contentPainter.text?.getSpanForPosition(textPosition);
      }
    }
    return null;
  }

  @override
  void handleTapDown(PointerDownEvent event) {
    _lastSpan = null; // Reset the span on tap down.
    // 在点击按下时重置跨度
    _lastSpan = _getSpanForPosition(event.localPosition);
  }

  @override
  void handleTapUp(PointerUpEvent event) {
    if (_lastSpan == null) return; // No span was hit on tap down.
    // 点击按下时没有命中跨度
    final newSpan = _getSpanForPosition(event.localPosition);
    if (newSpan != null && _lastSpan == newSpan) {
      if (newSpan
          case TextSpan(recognizer: final TapGestureRecognizer recognizer)) {
        recognizer.onTap?.call();
      }
    }

    _lastSpan = null; // Clear the span after handling the tap.
    // 处理点击后清除跨度
  }

  @override
  Size layout(double width) {
    for (final painter in _painters) {
      painter.dispose();
    }
    _painters.clear();

    double currentHeight = 0;
    double maxContentWidth = 0;

    void layoutItems(List<MD$ListItem> items, int level) {
      final indent = _baseIndent + level * _levelIndent;
      for (final item in items) {
        final bulletPainter = TextPainter(
          text: TextSpan(
              text: '${switch (item.marker) {
                '-' => '•',
                '*' => '•',
                '+' => '•',
                _ => item.marker,
              }} ',
              style: theme.textStyle),
          textDirection: theme.textDirection,
          textScaler: theme.textScaler,
        )..layout();

        final contentPainter = TextPainter(
          text: _paragraphFromMarkdownSpans(spans: item.spans, theme: theme),
          textDirection: theme.textDirection,
          textScaler: theme.textScaler,
        )..layout(maxWidth: math.max(0, width - indent - bulletPainter.width));

        final metrics = _ListItemMetrics(
          bulletPainter: bulletPainter,
          contentPainter: contentPainter,
          offset: Offset(indent, currentHeight),
        );
        _painters.add(metrics);

        currentHeight += metrics.height;
        maxContentWidth =
            math.max(maxContentWidth, indent + metrics.size.width);

        if (item.children.isNotEmpty) {
          layoutItems(item.children, level + 1);
        }
      }
    }

    layoutItems(_items, 0);
    return _size = Size(maxContentWidth, currentHeight);
  }

  @override
  void paint(Canvas canvas, Size size, double offset) {
    for (final metrics in _painters) {
      final bulletOffset = metrics.offset + Offset(0, offset);
      metrics.bulletPainter.paint(canvas, bulletOffset);

      final contentOffset =
          bulletOffset + Offset(metrics.bulletPainter.width, 0);
      metrics.contentPainter.paint(canvas, contentOffset);
    }
  }

  @override
  void dispose() {
    for (final metrics in _painters) {
      metrics.dispose();
    }
    _painters.clear();
  }
}

/// A class for painting a spacer block in markdown.
/// 用于在 Markdown 中绘制间隔块的类
@meta.internal
class BlockPainter$Spacer implements BlockPainter {
  BlockPainter$Spacer({
    required this.count,
    required this.theme,
  });

  final int count;

  final MarkdownThemeData theme;

  @override
  Size get size => _size;
  Size _size = Size.zero;

  @override
  void handleTapDown(PointerDownEvent _) {/* Do nothing */}
  /* 不执行任何操作 */

  @override
  void handleTapUp(PointerUpEvent _) {/* Do nothing */}
  /* 不执行任何操作 */

  @override
  Size layout(double width) {
    final height = theme.textStyle.fontSize ?? kDefaultFontSize;
    return _size = Size(0, height * count);
  }

  @override
  void paint(Canvas canvas, Size size, double offset) {
    // Do not paint anything
    // 不绘制任何内容
    /* canvas.drawRect(
      Rect.fromLTWH(0, offset, size.width, _size.height),
      Paint()..color = theme.textStyle.color ?? const Color(0x00000000),
    ); */
  }

  @override
  void dispose() {
    // Noting to dispose
    // 没有需要释放的内容
  }
}

/// A class for painting a spacer block in markdown.
/// 用于在 Markdown 中绘制间隔块的类
@meta.internal
class BlockPainter$Divider implements BlockPainter {
  BlockPainter$Divider({
    required this.theme,
  }) : _paint = Paint()
          ..color = theme.textStyle.color ?? const Color(0xFF000000)
          ..isAntiAlias = false
          ..strokeWidth = 1.0
          ..style = PaintingStyle.fill;

  final Paint _paint;
  final MarkdownThemeData theme;

  @override
  Size get size => _size;
  Size _size = Size.zero;

  @override
  void handleTapDown(PointerDownEvent _) {/* Do nothing */}
  /* 不执行任何操作 */

  @override
  void handleTapUp(PointerUpEvent _) {/* Do nothing */}
  /* 不执行任何操作 */

  @override
  Size layout(double width) {
    final height = theme.textStyle.fontSize ?? kDefaultFontSize;
    return _size = Size(0, height);
  }

  @override
  void paint(Canvas canvas, Size size, double offset) {
    // Draw a horizontal line across the width of the canvas.
    // 在画布宽度上绘制一条水平线
    final center = offset + _size.height / 2;
    canvas.drawLine(
      Offset(0, center),
      Offset(size.width, center),
      _paint,
    );
  }

  @override
  void dispose() {
    // Noting to dispose
    // 没有需要释放的内容
  }
}

/// A class for painting a code block in markdown.
/// 用于在 Markdown 中绘制代码块的类
@meta.internal
class BlockPainter$Code implements BlockPainter {
  BlockPainter$Code({
    required String text,
    required String? language,
    required this.theme,
  }) : painter = TextPainter(
          text: TextSpan(
            text: text,
            style: theme.textStyle.copyWith(
              fontFamily: 'monospace',
              fontSize: theme.textStyle.fontSize ?? kDefaultFontSize,
            ),
          ),
          textAlign: TextAlign.start,
          textDirection: theme.textDirection,
          textScaler: theme.textScaler,
        );

  static const double padding = 8.0; // Padding for code blocks.
  // 代码块的内边距

  final MarkdownThemeData theme;

  final TextPainter painter;

  @override
  Size get size => _size;
  Size _size = Size.zero;

  @override
  void handleTapDown(PointerDownEvent _) {/* Do nothing */}
  /* 不执行任何操作 */

  @override
  void handleTapUp(PointerUpEvent _) {/* Do nothing */}
  /* 不执行任何操作 */

  @override
  Size layout(double width) {
    if (width <= padding * 2) {
      // If the width is less than or equal to padding, return zero size.
      // 如果宽度小于或等于内边距，则返回零尺寸
      _size = Size.zero;
      return _size;
    }
    painter.layout(
      minWidth: 0,
      maxWidth: width - padding * 2,
    );
    return _size = Size(
      painter.size.width + padding * 2, // Add padding to the width.
      // 将内边距添加到宽度
      painter.size.height + padding * 2, // Add padding to the height.
      // 将内边距添加到高度
    );
  }

  @override
  void paint(Canvas canvas, Size size, double offset) {
    // If the width is less than required do not paint anything.
    // 如果宽度小于所需宽度，则不绘制任何内容
    if (size.width < _size.width) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, offset, size.width, _size.height),
        const Radius.circular(padding),
      ),
      Paint()
        ..color = theme.surfaceColor ?? const Color.fromARGB(255, 235, 235, 235)
        ..isAntiAlias = false
        ..style = PaintingStyle.fill,
    );
    painter.paint(
      canvas,
      Offset(padding, offset + padding),
    );
  }

  @override
  void dispose() {
    painter.dispose();
  }
}

/// A class for painting a table block in markdown.
/// 用于在 Markdown 中绘制表格块的类
@meta.internal
class BlockPainter$Table with ParagraphGestureHandler implements BlockPainter {
  BlockPainter$Table({
    required this.header,
    required this.rows,
    required this.theme,
  })  : columns = header.cells.length,
        _columnWidths = List<double>.filled(header.cells.length, 0.0),
        _rowHeights = List<double>.filled(rows.length + 1, 0.0),
        _borderPaint = Paint()
          ..color = theme.dividerColor ?? const Color(0x1F000000)
          ..style = PaintingStyle.stroke
          ..isAntiAlias = false
          ..strokeWidth = 1.0,
        _rowBackgroundPaint = Paint()
          ..style = PaintingStyle.fill
          ..isAntiAlias = false
          ..color =
              theme.surfaceColor ?? const Color.fromARGB(255, 235, 235, 235);

  /// Padding for table cells.
  /// 表格单元格的内边距
  static const double padding = 8.0;

  /// The theme for the markdown table.
  /// Markdown 表格的主题
  final MarkdownThemeData theme;

  /// The number of columns in the table.
  /// 表格中的列数
  final int columns;

  final List<double> _columnWidths;
  final List<double> _rowHeights;
  final Paint _borderPaint;
  final Paint _rowBackgroundPaint;

  Float32List? _borderPoints;

  /// The header row of the table.
  /// 表格的标题行
  final MD$TableRow header;

  /// The rows of the table.
  /// 表格的行
  final List<MD$TableRow> rows;

  @override
  Size get size => _size;
  Size _size = Size.zero;

  List<List<TextPainter>> _cellPainters = const [];

  /// Last span hit by the tap down event.
  /// 点击按下事件命中的最后一个跨度
  TextSpan? _lastSpan;

  @override
  void handleTapDown(PointerDownEvent event) {
    _lastSpan = null; // Reset the span on tap down.
    // 在点击按下时重置跨度
    final span = _getSpanForOffset(event.localPosition);
    if (span != null) {
      _lastSpan = span;
    }
  }

  @override
  void handleTapUp(PointerUpEvent event) {
    if (_lastSpan == null) return; // No span was hit on tap down.
    // 点击按下时没有命中跨度
    final span = _getSpanForOffset(event.localPosition);
    if (span != null && _lastSpan == span) {
      // If the span is the same as the one hit on tap down,
      // call the tap recognizer.
      // 如果跨度与点击按下时命中的跨度相同，则调用点击识别器
      if (span case TextSpan(recognizer: TapGestureRecognizer(:var onTap)))
        onTap?.call();
    }
    _lastSpan = null; // Clear the span after handling the tap.
    // 处理点击后清除跨度
  }

  TextSpan? _getSpanForOffset(Offset position) {
    final rowHeights =
        List.generate(_cellPainters.length, (r) => _rowHeights[r]);

    double currentY = 0.0;

    for (int r = 0; r < _cellPainters.length; r++) {
      final rowHeight = rowHeights[r];
      double currentX = 0.0;

      if (position.dy >= currentY && position.dy < currentY + rowHeight) {
        // In this row.
        // 在此行中
        for (int c = 0; c < _cellPainters[r].length; c++) {
          final painter = _cellPainters[r][c];
          if (painter.text == null) {
            currentX += _columnWidths[c];
            continue;
          }
          final columnWidth = _columnWidths[c];

          if (position.dx >= currentX && position.dx < currentX + columnWidth) {
            // In this cell.
            // 在此单元格中
            final verticalPadding = (rowHeight - painter.height) / 2;
            final horizontalPadding =
                (r == 0) ? (columnWidth - painter.width) / 2 : padding;

            final painterOffset = Offset(
                currentX + horizontalPadding, currentY + verticalPadding);
            final localPosition = position - painterOffset;

            // Check if inside the actual painted text area.
            // 检查是否在实际绘制的文本区域内
            if (localPosition.dx < 0 ||
                localPosition.dx > painter.width ||
                localPosition.dy < 0 ||
                localPosition.dy > painter.height) {
              currentX += columnWidth;
              continue;
            }

            final textPosition = painter.getPositionForOffset(localPosition);
            final span = painter.text!.getSpanForPosition(textPosition);
            if (span is TextSpan) {
              return span;
            }
            return null; // Found cell, but no span.
            // 找到单元格，但没有跨度
          }
          currentX += columnWidth;
        }
      }
      currentY += rowHeight;
    }
    return null;
  }

  @override
  Size layout(double width) {
    if (columns < 1) return _size = Size.zero;

    // Dispose old painters
    // 释放旧的绘制器
    for (final row in _cellPainters) {
      for (final painter in row) {
        painter.dispose();
      }
    }

    final allRows = [header, ...rows];
    final naturalWidths = List<double>.filled(columns, 0.0);
    final minWidths = List<double>.filled(columns, 0.0);

    // Create painters for each row and column and calculate natural widths
    // 为每行和每列创建绘制器并计算自然宽度
    _cellPainters = List.generate(allRows.length, (r) {
      final row = allRows[r];
      return List.generate(columns, (c) {
        if (c >= row.cells.length) {
          return TextPainter(textDirection: theme.textDirection);
        }
        final cell = row.cells[c];
        final style = (r == 0)
            ? theme.textStyle.copyWith(fontWeight: FontWeight.bold)
            : null;
        final textPainter = TextPainter(
          text: _paragraphFromMarkdownSpans(
              spans: cell, theme: theme, textStyle: style),
          textAlign: (r == 0) ? TextAlign.center : TextAlign.start,
          textDirection: theme.textDirection,
          textScaler: theme.textScaler,
        );

        // Calculate natural width
        // 计算自然宽度
        textPainter.layout(maxWidth: double.infinity);
        naturalWidths[c] =
            math.max(naturalWidths[c], textPainter.width + padding * 2);

        // Calculate min width (longest word)
        // 计算最小宽度（最长单词）
        final cellText = cell.map((s) => s.text).join();
        final words = cellText.split(RegExp(r'\s+'));
        if (words.isNotEmpty) {
          final longestWord =
              words.reduce((a, b) => a.length > b.length ? a : b);
          final wordPainter = TextPainter(
            text: TextSpan(text: longestWord, style: style),
            textDirection: theme.textDirection,
          )..layout();
          minWidths[c] =
              math.max(minWidths[c], wordPainter.width + padding * 2);
          wordPainter.dispose();
        }

        return textPainter;
      });
    });

    _columnWidths.setAll(0, _distributeWidths(naturalWidths, minWidths, width));

    final totalWidth = _columnWidths.reduce((a, b) => a + b);

    // Layout painters with final widths and calculate row heights
    // 使用最终宽度布局绘制器并计算行高

    double totalHeight = 0.0;
    for (int r = 0; r < allRows.length; r++) {
      double rowHeight = 0.0;
      for (int c = 0; c < columns; c++) {
        final painter = _cellPainters[r][c];
        if (painter.text == null) continue;
        painter.layout(maxWidth: math.max(0.0, _columnWidths[c] - padding * 2));
        rowHeight = math.max(
          rowHeight,
          painter.height,
        );
      }

      _rowHeights[r] = rowHeight + padding * 2;
      totalHeight += _rowHeights[r];
    }

    // Cache border points
    // 缓存边框点
    final points = Float32List(((allRows.length - 1) + (columns - 1)) * 4);
    var pointIndex = 0;
    // Horizontal lines
    // 水平线
    double lineY = 0;
    for (int r = 0; r < allRows.length - 1; r++) {
      lineY += _rowHeights[r];
      points[pointIndex++] = 0;
      points[pointIndex++] = lineY;
      points[pointIndex++] = totalWidth;
      points[pointIndex++] = lineY;
    }
    // Vertical lines
    // 垂直线
    double lineX = 0;
    for (int c = 0; c < columns - 1; c++) {
      lineX += _columnWidths[c];
      points[pointIndex++] = lineX;
      points[pointIndex++] = 0;
      points[pointIndex++] = lineX;
      points[pointIndex++] = totalHeight;
    }
    _borderPoints = points;

    return _size = Size(totalWidth, totalHeight);
  }

  @override
  void paint(Canvas canvas, Size size, double offset) {
    // If the width is less than required do not paint anything.
    // 如果宽度小于所需宽度，则不绘制任何内容
    if (columns < 1) return;

    double currentY = offset;
    final rowHeights =
        List.generate(_cellPainters.length, (r) => _rowHeights[r]);

    for (int r = 0; r < _cellPainters.length; r++) {
      double currentX = 0;

      // Draw background for even data rows.
      // 为偶数数据行绘制背景
      if (r % 2 == 0 && r != 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, currentY, _size.width, rowHeights[r]),
          _rowBackgroundPaint,
        );
      }

      for (int c = 0; c < columns; c++) {
        final painter = _cellPainters[r][c];
        if (painter.text == null) {
          currentX += _cellPainters[r].length > c ? _columnWidths[c] : 0;
          continue;
        }

        final verticalPadding = (rowHeights[r] - painter.height) / 2;
        final horizontalPadding = (r == 0)
            ? (_columnWidths[c] - painter.width) / 2 // Center for header rows
            // 标题行居中
            : padding; // Left align for data rows
        // 数据行左对齐

        painter.paint(
          canvas,
          Offset(
            currentX + horizontalPadding,
            currentY + verticalPadding,
          ),
        );
        currentX += _columnWidths[c];
      }
      currentY += rowHeights[r];
    }

    // Draw inner borders
    // 绘制内部边框
    if (_borderPoints != null) {
      canvas.save();
      canvas.translate(0, offset);
      canvas.drawRawPoints(PointMode.lines, _borderPoints!, _borderPaint);
      canvas.restore();
    }

    // Draw outer borders
    // 绘制外部边框
    canvas.drawRect(
      Rect.fromLTRB(
        0,
        offset,
        _size.width,
        offset + _size.height,
      ),
      _borderPaint,
    );
  }

  @override
  void dispose() {
    for (final row in _cellPainters) {
      for (final painter in row) {
        painter.dispose();
      }
    }
    _cellPainters = const [];
  }

  /// Helper function to distribute widths among columns, respecting minimums.
  /// If total minimum width exceeds availableWidth,
  /// it returns the minimum widths as-is,
  /// implying that the content will overflow and require scrolling.
  /// 在列之间分配宽度的辅助函数，遵守最小值
  /// 如果总最小宽度超过可用宽度，则按原样返回最小宽度
  /// 这意味着内容将溢出并需要滚动
  List<double> _distributeWidths(
      List<double> natural, List<double> min, double availableWidth) {
    final totalNatural = natural.reduce((a, b) => a + b);
    final totalMin = min.reduce((a, b) => a + b);

    if (totalNatural <= availableWidth) {
      return natural;
    }

    if (totalMin <= availableWidth) {
      final remainingSpace = availableWidth - totalMin;
      final extraSpacePerColumn = [
        for (var i = 0; i < natural.length; i++) natural[i] - min[i]
      ];
      final totalExtraSpace = extraSpacePerColumn.reduce((a, b) => a + b);

      if (totalExtraSpace <= 0.001) return min;

      return [
        for (var i = 0; i < natural.length; i++)
          min[i] + remainingSpace * (extraSpacePerColumn[i] / totalExtraSpace)
      ];
    }
    return min;
  }
}
