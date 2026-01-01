import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter/gestures.dart';

import '../render.dart';

/// A wrapper around [BlockPainter] that applies animation effects.
///
/// This painter can apply multiple animation effects:
/// - Opacity (fade-in/out)
/// - Vertical offset (slide up/down)
/// - Gaussian blur
class AnimatedBlockPainter implements BlockPainter {
  /// Creates an animated block painter.
  AnimatedBlockPainter({
    required this.inner,
    this.opacityAnimation,
    this.offsetAnimation,
    this.blurAnimation,
  });

  /// The inner block painter to wrap.
  final BlockPainter inner;

  /// The opacity animation (0.0 to 1.0).
  final Animation<double>? opacityAnimation;

  /// The vertical offset animation in pixels.
  /// Positive values move the block down, negative values move it up.
  final Animation<double>? offsetAnimation;

  /// The Gaussian blur animation (sigma value).
  final Animation<double>? blurAnimation;

  @override
  Size get size => inner.size;

  @override
  void handleTapDown(PointerDownEvent event) {
    // Adjust event position if offset animation is active
    if (offsetAnimation != null) {
      final adjustedEvent = PointerDownEvent(
        timeStamp: event.timeStamp,
        pointer: event.pointer,
        kind: event.kind,
        device: event.device,
        position: event.position - Offset(0, offsetAnimation!.value),
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
      );
      inner.handleTapDown(adjustedEvent);
    } else {
      inner.handleTapDown(event);
    }
  }

  @override
  void handleTapUp(PointerUpEvent event) {
    // Adjust event position if offset animation is active
    if (offsetAnimation != null) {
      final adjustedEvent = PointerUpEvent(
        timeStamp: event.timeStamp,
        pointer: event.pointer,
        kind: event.kind,
        device: event.device,
        position: event.position - Offset(0, offsetAnimation!.value),
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
      );
      inner.handleTapUp(adjustedEvent);
    } else {
      inner.handleTapUp(event);
    }
  }

  @override
  Size layout(double width) => inner.layout(width);

  @override
  void paint(Canvas canvas, Size size, double offset) {
    final opacity = opacityAnimation?.value ?? 1.0;
    final verticalOffset = offsetAnimation?.value ?? 0.0;
    final blurSigma = blurAnimation?.value ?? 0.0;

    // If fully transparent, don't paint anything
    if (opacity <= 0.0) return;

    // Check if we need any special effects
    final needsOpacity = opacity < 1.0;
    final needsBlur = blurSigma > 0.0;
    final needsOffset = verticalOffset.abs() > 0.01;

    // If no effects needed, paint directly
    if (!needsOpacity && !needsBlur && !needsOffset) {
      inner.paint(canvas, size, offset);
      return;
    }

    // Apply vertical offset if needed
    if (needsOffset) {
      canvas.save();
      canvas.translate(0, verticalOffset);
    }

    // Apply opacity and/or blur using saveLayer
    if (needsOpacity || needsBlur) {
      final paint = Paint();

      // Apply blur effect
      if (needsBlur) {
        paint.imageFilter = ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
        );
      }

      // Apply opacity effect
      if (needsOpacity) {
        paint.color = Color.fromRGBO(255, 255, 255, opacity);
      }

      // Use bounds to optimize the layer size
      canvas.saveLayer(Offset.zero & size, paint);
      inner.paint(canvas, size, offset);
      canvas.restore();
    } else {
      inner.paint(canvas, size, offset);
    }

    // Restore offset transformation
    if (needsOffset) {
      canvas.restore();
    }
  }

  @override
  void dispose() => inner.dispose();
}
