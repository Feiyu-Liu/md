import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter/gestures.dart';

import '../render.dart';

/// A wrapper around [BlockPainter] that applies fade-in animation.
///
/// This painter reads the current value from [opacityAnimation] and applies
/// it as opacity when painting the inner block.
class AnimatedBlockPainter implements BlockPainter {
  /// Creates an animated block painter.
  AnimatedBlockPainter({
    required this.inner,
    required this.opacityAnimation,
  });

  /// The inner block painter to wrap.
  final BlockPainter inner;

  /// The opacity animation driven by an external [AnimationController].
  final Animation<double> opacityAnimation;

  @override
  Size get size => inner.size;

  @override
  void handleTapDown(PointerDownEvent event) => inner.handleTapDown(event);

  @override
  void handleTapUp(PointerUpEvent event) => inner.handleTapUp(event);

  @override
  Size layout(double width) => inner.layout(width);

  @override
  void paint(Canvas canvas, Size size, double offset) {
    final opacity = opacityAnimation.value;

    // If fully transparent, don't paint anything
    if (opacity <= 0.0) return;

    // If fully opaque, paint directly without layer
    if (opacity >= 1.0) {
      inner.paint(canvas, size, offset);
      return;
    }

    // Apply fade-in effect using saveLayer with opacity
    canvas.save();

    final paint = Paint()..color = Color.fromRGBO(255, 255, 255, opacity);
    canvas.saveLayer(null, paint);
    inner.paint(canvas, size, offset);
    canvas.restore();

    canvas.restore();
  }

  @override
  void dispose() => inner.dispose();
}

