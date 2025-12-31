import 'package:flutter/animation.dart';

/// Configuration for block fade-in animation in streaming markdown.
///
/// When [enabled] is true, closed blocks will fade in when they become visible.
/// Open blocks (still receiving content) remain invisible until closed.
class MarkdownAnimationConfig {
  /// Creates a new animation configuration.
  const MarkdownAnimationConfig({
    this.enabled = false,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOut,
  });

  /// Whether fade-in animation is enabled.
  ///
  /// When enabled:
  /// - Only closed blocks are rendered
  /// - Newly closed blocks fade in with animation
  /// - Open blocks remain invisible
  ///
  /// When disabled:
  /// - All blocks are rendered immediately (including open blocks)
  final bool enabled;

  /// Duration of the fade-in animation.
  final Duration fadeInDuration;

  /// Animation curve for the fade-in effect.
  final Curve curve;

  /// Disabled animation configuration.
  /// All blocks are rendered immediately without animation.
  static const MarkdownAnimationConfig disabled = MarkdownAnimationConfig();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownAnimationConfig &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          fadeInDuration == other.fadeInDuration &&
          curve == other.curve;

  @override
  int get hashCode => Object.hash(enabled, fadeInDuration, curve);

  @override
  String toString() => 'MarkdownAnimationConfig('
      'enabled: $enabled, '
      'fadeInDuration: $fadeInDuration, '
      'curve: $curve)';
}

