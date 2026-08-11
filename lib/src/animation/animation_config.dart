import 'package:flutter/animation.dart';

/// Lifecycle used to decide which Markdown blocks should animate.
enum MarkdownAnimationMode {
  /// Animates blocks as they close during incremental streaming.
  streaming,

  /// Replays only source blocks whose replacement value changed.
  contentReplacement,
}

/// Range for animating a property from start to end value.
class AnimationRange {
  /// Creates an animation range.
  const AnimationRange({
    required this.start,
    required this.end,
  });

  /// Start value of the animation.
  final double start;

  /// End value of the animation.
  final double end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnimationRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'AnimationRange(start: $start, end: $end)';
}

/// Configuration for block animation in streaming markdown.
///
/// When [enabled] is true, closed blocks will animate when they become visible.
/// Open blocks (still receiving content) remain invisible until closed.
///
/// You can enable different animation effects by providing their ranges:
/// - [opacityRange]: Fade-in effect (opacity from start to end)
/// - [offsetRange]: Vertical slide effect (offset in pixels, positive = down)
/// - [blurRange]: Gaussian blur effect (blur sigma from start to end)
///
/// When [disableOnComplete] is true, animations will be automatically disabled
/// after streaming completes and the final block finishes animating. This
/// prevents animations from replaying on rebuilds (e.g., when scrolling).
class MarkdownAnimationConfig {
  /// Creates a new animation configuration.
  const MarkdownAnimationConfig({
    this.enabled = false,
    this.mode = MarkdownAnimationMode.streaming,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOutCubic,
    this.opacityRange,
    this.offsetRange,
    this.blurRange,
    this.disableOnComplete = false,
  });

  /// Recommended animation for source-block content replacements.
  const MarkdownAnimationConfig.contentReplacement({
    this.enabled = true,
    this.duration = const Duration(milliseconds: 420),
    this.curve = Curves.easeOutCubic,
    this.opacityRange = const AnimationRange(start: 0, end: 1),
    this.blurRange = const AnimationRange(start: 5, end: 0),
    this.offsetRange,
  })  : mode = MarkdownAnimationMode.contentReplacement,
        disableOnComplete = false;

  /// Whether animation is enabled.
  ///
  /// In [MarkdownAnimationMode.streaming], when enabled:
  /// - Only closed blocks are rendered
  /// - Newly closed blocks animate in based on configured effects
  /// - Open blocks remain invisible
  ///
  /// When disabled:
  /// - All blocks are rendered immediately (including open blocks)
  final bool enabled;

  /// Determines whether streaming closure or replacement changes trigger
  /// motion.
  final MarkdownAnimationMode mode;

  /// Duration of the animation.
  final Duration duration;

  /// Animation curve for all effects.
  final Curve curve;

  /// Opacity animation range.
  ///
  /// If null, opacity animation is disabled.
  /// Example: `AnimationRange(start: 0.0, end: 1.0)` for fade-in effect.
  final AnimationRange? opacityRange;

  /// Vertical offset animation range in pixels.
  ///
  /// If null, offset animation is disabled.
  /// Positive values move down, negative values move up.
  /// Example: `AnimationRange(start: 20.0, end: 0.0)` slides from 20px below.
  final AnimationRange? offsetRange;

  /// Gaussian blur animation range (sigma value).
  ///
  /// If null, blur animation is disabled.
  /// Example: `AnimationRange(start: 5.0, end: 0.0)` blurs from 5.0 to sharp.
  final AnimationRange? blurRange;

  /// Whether to automatically disable animations after streaming completes.
  ///
  /// When true, after [isStreamingComplete] becomes true and the last block's
  /// animation finishes, the animation config will be set to disabled
  /// internally.
  /// This prevents animations from replaying on subsequent widget rebuilds.
  ///
  /// This is useful for preventing animation replays when:
  /// - Scrolling through a message list
  /// - Sending new messages
  /// - Any other widget rebuild scenarios
  ///
  /// Default is false to maintain backward compatibility.
  final bool disableOnComplete;

  /// Disabled animation configuration.
  /// All blocks are rendered immediately without animation.
  static const MarkdownAnimationConfig disabled = MarkdownAnimationConfig();

  /// Returns an equivalent configuration with animation disabled.
  MarkdownAnimationConfig withoutAnimation() => MarkdownAnimationConfig(
        mode: mode,
        duration: duration,
        curve: curve,
        opacityRange: opacityRange,
        offsetRange: offsetRange,
        blurRange: blurRange,
        disableOnComplete: disableOnComplete,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownAnimationConfig &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          mode == other.mode &&
          duration == other.duration &&
          curve == other.curve &&
          opacityRange == other.opacityRange &&
          offsetRange == other.offsetRange &&
          blurRange == other.blurRange &&
          disableOnComplete == other.disableOnComplete;

  @override
  int get hashCode => Object.hash(
        enabled,
        mode,
        duration,
        curve,
        opacityRange,
        offsetRange,
        blurRange,
        disableOnComplete,
      );

  @override
  String toString() => 'MarkdownAnimationConfig('
      'enabled: $enabled, '
      'mode: $mode, '
      'duration: $duration, '
      'curve: $curve, '
      'opacityRange: $opacityRange, '
      'offsetRange: $offsetRange, '
      'blurRange: $blurRange, '
      'disableOnComplete: $disableOnComplete)';
}
