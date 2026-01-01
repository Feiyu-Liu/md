import 'package:flutter/animation.dart';

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
class MarkdownAnimationConfig {
  /// Creates a new animation configuration.
  const MarkdownAnimationConfig({
    this.enabled = false,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOut,
    this.opacityRange,
    this.offsetRange,
    this.blurRange,
  });

  /// Whether animation is enabled.
  ///
  /// When enabled:
  /// - Only closed blocks are rendered
  /// - Newly closed blocks animate in based on configured effects
  /// - Open blocks remain invisible
  ///
  /// When disabled:
  /// - All blocks are rendered immediately (including open blocks)
  final bool enabled;

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

  /// Disabled animation configuration.
  /// All blocks are rendered immediately without animation.
  static const MarkdownAnimationConfig disabled = MarkdownAnimationConfig();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownAnimationConfig &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          duration == other.duration &&
          curve == other.curve &&
          opacityRange == other.opacityRange &&
          offsetRange == other.offsetRange &&
          blurRange == other.blurRange;

  @override
  int get hashCode => Object.hash(
        enabled,
        duration,
        curve,
        opacityRange,
        offsetRange,
        blurRange,
      );

  @override
  String toString() => 'MarkdownAnimationConfig('
      'enabled: $enabled, '
      'duration: $duration, '
      'curve: $curve, '
      'opacityRange: $opacityRange, '
      'offsetRange: $offsetRange, '
      'blurRange: $blurRange)';
}

