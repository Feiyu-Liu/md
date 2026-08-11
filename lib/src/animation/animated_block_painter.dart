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
    required BlockPainter inner,
    this.opacityAnimation,
    this.offsetAnimation,
    this.blurAnimation,
  }) : _inner = inner;

  /// The inner block painter to wrap.
  BlockPainter get inner => _inner!;
  BlockPainter? _inner;

  /// Transfers ownership of the wrapped painter to another animation wrapper.
  BlockPainter takeInner() {
    final result = inner;
    _inner = null;
    return result;
  }

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
  void paint(Canvas canvas, Size size, double offset) => paintAnimatedBlock(
        canvas: canvas,
        size: size,
        offset: offset,
        painter: inner,
        opacity: opacityAnimation?.value ?? 1,
        verticalOffset: offsetAnimation?.value ?? 0,
        blurSigma: blurAnimation?.value ?? 0,
      );

  @override
  void dispose() {
    _inner?.dispose();
    _inner = null;
  }
}

/// Paints an outgoing block underneath its incoming replacement.
///
/// Layout and pointer events are always delegated to [incoming]. The outgoing
/// painter is visual-only and is released as soon as its exit interval ends.
class ContentReplacementBlockPainter implements BlockPainter {
  /// Creates a coordinated content replacement transition.
  ContentReplacementBlockPainter({
    required BlockPainter outgoing,
    required BlockPainter incoming,
    required this.exitProgress,
    this.outgoingOpacityAnimation,
    this.outgoingOffsetAnimation,
    this.outgoingBlurAnimation,
    this.incomingOpacityAnimation,
    this.incomingOffsetAnimation,
    this.incomingBlurAnimation,
  })  : _outgoing = outgoing,
        _incoming = incoming;

  BlockPainter? _outgoing;
  BlockPainter? _incoming;

  /// Reaches 1 when the outgoing painter is no longer visible.
  final Animation<double> exitProgress;

  /// Opacity applied to the outgoing painter.
  final Animation<double>? outgoingOpacityAnimation;

  /// Vertical offset applied to the outgoing painter.
  final Animation<double>? outgoingOffsetAnimation;

  /// Gaussian blur applied to the outgoing painter.
  final Animation<double>? outgoingBlurAnimation;

  /// Opacity applied to the incoming painter.
  final Animation<double>? incomingOpacityAnimation;

  /// Vertical offset applied to the incoming painter.
  final Animation<double>? incomingOffsetAnimation;

  /// Gaussian blur applied to the incoming painter.
  final Animation<double>? incomingBlurAnimation;

  /// The current replacement painter used for layout and interactions.
  BlockPainter get incoming => _incoming!;

  /// Whether the outgoing visual is still retained.
  bool get hasOutgoing => _outgoing != null;

  /// Transfers the current painter to a newer replacement transition.
  BlockPainter takeIncoming() {
    final result = incoming;
    _incoming = null;
    return result;
  }

  /// Transfers an in-flight outgoing visual across a harmless rebuild.
  BlockPainter? takeOutgoing() {
    final result = _outgoing;
    _outgoing = null;
    return result;
  }

  @override
  Size get size => incoming.size;

  @override
  void handleTapDown(PointerDownEvent event) => incoming.handleTapDown(event);

  @override
  void handleTapUp(PointerUpEvent event) => incoming.handleTapUp(event);

  @override
  Size layout(double width) {
    _outgoing?.layout(width);
    return incoming.layout(width);
  }

  @override
  void paint(Canvas canvas, Size size, double offset) {
    final outgoing = _outgoing;
    if (outgoing != null) {
      if (exitProgress.value >= 1) {
        outgoing.dispose();
        _outgoing = null;
      } else {
        paintAnimatedBlock(
          canvas: canvas,
          size: size,
          offset: offset,
          painter: outgoing,
          opacity: outgoingOpacityAnimation?.value ?? 1,
          verticalOffset: outgoingOffsetAnimation?.value ?? 0,
          blurSigma: outgoingBlurAnimation?.value ?? 0,
        );
      }
    }
    paintAnimatedBlock(
      canvas: canvas,
      size: size,
      offset: offset,
      painter: incoming,
      opacity: incomingOpacityAnimation?.value ?? 1,
      verticalOffset: incomingOffsetAnimation?.value ?? 0,
      blurSigma: incomingBlurAnimation?.value ?? 0,
    );
  }

  @override
  void dispose() {
    _outgoing?.dispose();
    _outgoing = null;
    _incoming?.dispose();
    _incoming = null;
  }
}

/// Paints one block with the supplied transition values.
void paintAnimatedBlock({
  required Canvas canvas,
  required Size size,
  required double offset,
  required BlockPainter painter,
  required double opacity,
  required double verticalOffset,
  required double blurSigma,
}) {
  if (opacity <= 0) return;

  final needsOpacity = opacity < 1;
  final needsBlur = blurSigma > 0;
  final needsOffset = verticalOffset.abs() > 0.01;
  if (!needsOpacity && !needsBlur && !needsOffset) {
    painter.paint(canvas, size, offset);
    return;
  }

  if (needsOffset) {
    canvas.save();
    canvas.translate(0, verticalOffset);
  }
  if (needsOpacity || needsBlur) {
    final paint = Paint();
    if (needsBlur) {
      paint.imageFilter = ImageFilter.blur(
        sigmaX: blurSigma,
        sigmaY: blurSigma,
      );
    }
    if (needsOpacity) {
      paint.color = Color.fromRGBO(255, 255, 255, opacity);
    }
    final blurOutset = blurSigma * 3;
    final layerBounds = Rect.fromLTRB(
      -blurOutset,
      offset - blurOutset,
      size.width + blurOutset,
      offset + painter.size.height + blurOutset,
    );
    canvas.saveLayer(layerBounds, paint);
    painter.paint(canvas, size, offset);
    canvas.restore();
  } else {
    painter.paint(canvas, size, offset);
  }
  if (needsOffset) canvas.restore();
}
