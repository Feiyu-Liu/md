import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart' as meta show internal;

/// Layout information for one selectable [TextPainter].
@meta.internal
class MarkdownSelectionFragmentDescriptor {
  MarkdownSelectionFragmentDescriptor({
    required this.painter,
    required this.paintOffset,
    this.prefix = '',
    this.suffix = '',
  });

  final TextPainter painter;
  final Offset Function() paintOffset;
  String prefix;
  String suffix;

  String get visibleText =>
      painter.text?.toPlainText(includeSemanticsLabels: false) ?? '';

  String get text => '$prefix$visibleText$suffix';
}

/// The render-object operations needed by selectable Markdown fragments.
@meta.internal
abstract interface class MarkdownSelectionOwner {
  RenderObject get selectionRenderObject;
  bool get selectionAttached;
  void markSelectionNeedsPaint();
}

/// A document-relative selection used while Markdown painters are rebuilt.
@meta.internal
@immutable
class MarkdownSelectionSnapshot {
  const MarkdownSelectionSnapshot({
    required this.baseOffset,
    required this.extentOffset,
  });

  final int baseOffset;
  final int extentOffset;
}

/// Selection coordinator owned by a single [MarkdownWidget].
@meta.internal
class MarkdownSelectionDelegate extends StaticSelectionContainerDelegate {
  MarkdownSelectionSnapshot? _pendingSelection;
  bool _ignoreRebuildEdgeUpdates = false;

  @override
  Comparator<Selectable> get compareOrder => (a, b) {
        if (a is MarkdownSelectableFragment &&
            b is MarkdownSelectableFragment) {
          return a.documentStart.compareTo(b.documentStart);
        }
        return 0;
      };

  MarkdownSelectionSnapshot? captureSelection() {
    if (currentSelectionStartIndex < 0 ||
        currentSelectionEndIndex < 0 ||
        currentSelectionStartIndex >= selectables.length ||
        currentSelectionEndIndex >= selectables.length) {
      return null;
    }
    final start = selectables[currentSelectionStartIndex];
    final end = selectables[currentSelectionEndIndex];
    if (start is! MarkdownSelectableFragment ||
        end is! MarkdownSelectableFragment) {
      return null;
    }
    final startRange = start.getSelection();
    final endRange = end.getSelection();
    if (startRange == null || endRange == null) return null;
    return MarkdownSelectionSnapshot(
      baseOffset: start.documentStart + startRange.startOffset,
      extentOffset: end.documentStart + endRange.endOffset,
    );
  }

  void unregisterFragments(List<MarkdownSelectableFragment> fragments) {
    _pendingSelection ??= captureSelection();
    for (final fragment in fragments) {
      remove(fragment);
      fragment.dispose();
    }
  }

  void registerFragments({
    required String previousText,
    required String text,
    required List<MarkdownSelectableFragment> fragments,
  }) {
    _ignoreRebuildEdgeUpdates = _pendingSelection != null;
    _pendingSelection = _remapSelection(
      _pendingSelection,
      previousText: previousText,
      text: text,
    );
    for (final fragment in fragments) {
      add(fragment);
    }
  }

  static MarkdownSelectionSnapshot? _remapSelection(
    MarkdownSelectionSnapshot? selection, {
    required String previousText,
    required String text,
  }) {
    if (selection == null || previousText == text) return selection;

    final limit = math.min(previousText.length, text.length);
    var commonPrefix = 0;
    while (commonPrefix < limit &&
        previousText.codeUnitAt(commonPrefix) ==
            text.codeUnitAt(commonPrefix)) {
      commonPrefix++;
    }

    final lower = math.min(selection.baseOffset, selection.extentOffset);
    final upper = math.max(selection.baseOffset, selection.extentOffset);
    if (commonPrefix >= upper) return selection;
    if (commonPrefix <= lower) return null;

    final base = selection.baseOffset > commonPrefix
        ? commonPrefix
        : selection.baseOffset;
    final extent = selection.extentOffset > commonPrefix
        ? commonPrefix
        : selection.extentOffset;
    if (base == extent) return null;
    return MarkdownSelectionSnapshot(
      baseOffset: base,
      extentOffset: extent,
    );
  }

  @override
  void didChangeSelectables() {
    clearInternalSelectionState();
    super.didChangeSelectables();

    final pending = _pendingSelection;
    _pendingSelection = null;
    if (pending == null || selectables.isEmpty) {
      _finishRebuild();
      return;
    }

    final fragments = selectables.whereType<MarkdownSelectableFragment>();
    final start = _findFragment(
      fragments,
      pending.baseOffset,
      preferPreviousBoundary: true,
    );
    final end = _findFragment(
      fragments,
      pending.extentOffset,
      preferPreviousBoundary: false,
    );
    if (start == null || end == null) {
      _finishRebuild();
      return;
    }

    final startIndex = selectables.indexOf(start);
    final endIndex = selectables.indexOf(end);
    final forward = pending.baseOffset <= pending.extentOffset;
    final lowerIndex = math.min(startIndex, endIndex);
    final upperIndex = math.max(startIndex, endIndex);

    for (var index = lowerIndex; index <= upperIndex; index++) {
      final selectable = selectables[index];
      if (selectable is! MarkdownSelectableFragment) continue;
      if (forward) {
        selectable.restoreSelection(
          startOffset: index == startIndex
              ? pending.baseOffset - selectable.documentStart
              : 0,
          endOffset: index == endIndex
              ? pending.extentOffset - selectable.documentStart
              : selectable.contentLength,
        );
      } else {
        selectable.restoreSelection(
          startOffset: index == startIndex
              ? pending.baseOffset - selectable.documentStart
              : selectable.contentLength,
          endOffset: index == endIndex
              ? pending.extentOffset - selectable.documentStart
              : 0,
        );
      }
    }

    currentSelectionStartIndex = startIndex;
    currentSelectionEndIndex = endIndex;
    didReceiveSelectionBoundaryEvents();
    layoutDidChange();
    notifyListeners();
    _finishRebuild();
  }

  void _finishRebuild() {
    if (!_ignoreRebuildEdgeUpdates) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ignoreRebuildEdgeUpdates = false;
    });
  }

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    if (_ignoreRebuildEdgeUpdates &&
        (event.type == SelectionEventType.startEdgeUpdate ||
            event.type == SelectionEventType.endEdgeUpdate)) {
      return SelectionResult.end;
    }
    return super.dispatchSelectionEvent(event);
  }

  static MarkdownSelectableFragment? _findFragment(
    Iterable<MarkdownSelectableFragment> fragments,
    int offset, {
    required bool preferPreviousBoundary,
  }) {
    MarkdownSelectableFragment? previous;
    for (final fragment in fragments) {
      final end = fragment.documentStart + fragment.contentLength;
      if (offset < fragment.documentStart) return previous;
      if (offset < end) return fragment;
      if (offset == end) {
        if (preferPreviousBoundary) return fragment;
        previous = fragment;
        continue;
      }
      previous = fragment;
    }
    return previous;
  }
}

/// A selectable projection of one laid-out Markdown [TextPainter].
@meta.internal
class MarkdownSelectableFragment
    with Selectable, ChangeNotifier, Diagnosticable {
  MarkdownSelectableFragment({
    required this.owner,
    required this.descriptor,
    required this.documentStart,
    required this.selectionColor,
  }) : _geometry = const SelectionGeometry(
          status: SelectionStatus.none,
          hasContent: true,
        );

  final MarkdownSelectionOwner owner;
  final MarkdownSelectionFragmentDescriptor descriptor;
  final int documentStart;
  final Color selectionColor;

  TextPosition? _selectionStart;
  TextPosition? _selectionEnd;
  LayerLink? _startHandle;
  LayerLink? _endHandle;
  SelectionGeometry _geometry;

  int get _prefixLength => descriptor.prefix.length;
  int get _visibleLength => descriptor.visibleText.length;

  @override
  int get contentLength => descriptor.text.length;

  @override
  SelectionGeometry get value => _geometry;

  @override
  Size get size => descriptor.painter.size;

  @override
  List<Rect> get boundingBoxes {
    final boxes = descriptor.painter.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: _visibleLength),
      boxHeightStyle: ui.BoxHeightStyle.max,
    );
    if (boxes.isNotEmpty) {
      return <Rect>[for (final box in boxes) box.toRect()];
    }
    return <Rect>[
      Rect.fromLTWH(
        0,
        0,
        math.max(size.width, 1),
        math.max(size.height, descriptor.painter.preferredLineHeight),
      ),
    ];
  }

  @override
  Matrix4 getTransformTo(RenderObject? ancestor) {
    return owner.selectionRenderObject.getTransformTo(ancestor)
      ..translateByDouble(
        descriptor.paintOffset().dx,
        descriptor.paintOffset().dy,
        0,
        1,
      );
  }

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    final oldStart = _selectionStart;
    final oldEnd = _selectionEnd;
    late final SelectionResult result;

    switch (event.type) {
      case SelectionEventType.startEdgeUpdate:
      case SelectionEventType.endEdgeUpdate:
        result = _handleEdgeUpdate(event as SelectionEdgeUpdateEvent);
      case SelectionEventType.clear:
        _selectionStart = null;
        _selectionEnd = null;
        result = SelectionResult.none;
      case SelectionEventType.selectAll:
        _selectionStart = const TextPosition(offset: 0);
        _selectionEnd = TextPosition(offset: contentLength);
        result = SelectionResult.none;
      case SelectionEventType.selectWord:
        result = _handleSelectWord(
          (event as SelectWordSelectionEvent).globalPosition,
        );
      case SelectionEventType.selectParagraph:
        final paragraph = event as SelectParagraphSelectionEvent;
        if (paragraph.absorb) {
          _selectionStart = const TextPosition(offset: 0);
          _selectionEnd = TextPosition(offset: contentLength);
          result = SelectionResult.next;
        } else {
          result = _handleSelectWord(paragraph.globalPosition, selectAll: true);
        }
      case SelectionEventType.granularlyExtendSelection:
        result = _handleGranularExtension(
          event as GranularlyExtendSelectionEvent,
        );
      case SelectionEventType.directionallyExtendSelection:
        result = _handleDirectionalExtension(
          event as DirectionallyExtendSelectionEvent,
        );
    }

    if (oldStart != _selectionStart || oldEnd != _selectionEnd) {
      _didChangeSelection();
    }
    return result;
  }

  SelectionResult _handleEdgeUpdate(SelectionEdgeUpdateEvent event) {
    final isEnd = event.type == SelectionEventType.endEdgeUpdate;
    final localPosition = _toLocal(event.globalPosition);
    final rect = _selectionRect;
    final result = SelectionUtils.getResultBasedOnRect(rect, localPosition);
    final logicalOffset = switch (result) {
      SelectionResult.previous => 0,
      SelectionResult.next => contentLength,
      _ => _logicalOffsetForLocalPosition(localPosition),
    };

    var position = TextPosition(offset: logicalOffset);
    if (event.granularity == TextGranularity.word &&
        result == SelectionResult.end) {
      final visualOffset = _visualOffset(logicalOffset);
      final boundary = descriptor.painter.getWordBoundary(
        TextPosition(offset: visualOffset),
      );
      final other = isEnd ? _selectionStart : _selectionEnd;
      final boundaryStart = _prefixLength + boundary.start;
      final boundaryEnd = _prefixLength + boundary.end;
      position = TextPosition(
        offset: other != null && logicalOffset < other.offset
            ? boundaryStart
            : boundaryEnd,
      );
    }

    if (isEnd) {
      _selectionEnd = position;
    } else {
      _selectionStart = position;
    }
    return result;
  }

  SelectionResult _handleSelectWord(
    Offset globalPosition, {
    bool selectAll = false,
  }) {
    final local = _toLocal(globalPosition);
    if (!_selectionRect.contains(local)) {
      return SelectionUtils.getResultBasedOnRect(_selectionRect, local);
    }
    if (selectAll) {
      _selectionStart = const TextPosition(offset: 0);
      _selectionEnd = TextPosition(offset: contentLength);
      return SelectionResult.end;
    }
    final visualPosition = descriptor.painter.getPositionForOffset(local);
    final boundary = descriptor.painter.getWordBoundary(visualPosition);
    _selectionStart = TextPosition(
      offset: (_prefixLength + boundary.start).clamp(0, contentLength),
    );
    _selectionEnd = TextPosition(
      offset: (_prefixLength + boundary.end).clamp(0, contentLength),
    );
    return SelectionResult.end;
  }

  SelectionResult _handleGranularExtension(
    GranularlyExtendSelectionEvent event,
  ) {
    final current = event.isEnd ? _selectionEnd : _selectionStart;
    final fallback = event.forward ? 0 : contentLength;
    final offset = current?.offset ?? fallback;
    final next = switch (event.granularity) {
      TextGranularity.character => offset + (event.forward ? 1 : -1),
      TextGranularity.word => _nextWordOffset(offset, event.forward),
      TextGranularity.paragraph ||
      TextGranularity.line ||
      TextGranularity.document =>
        event.forward ? contentLength : 0,
    };
    final clamped = next.clamp(0, contentLength);
    if (event.isEnd) {
      _selectionEnd = TextPosition(offset: clamped);
      _selectionStart ??= TextPosition(offset: offset);
    } else {
      _selectionStart = TextPosition(offset: clamped);
      _selectionEnd ??= TextPosition(offset: offset);
    }
    if (clamped == 0) return SelectionResult.previous;
    if (clamped == contentLength) return SelectionResult.next;
    return SelectionResult.end;
  }

  SelectionResult _handleDirectionalExtension(
    DirectionallyExtendSelectionEvent event,
  ) {
    final forward = switch (event.direction) {
      SelectionExtendDirection.nextLine ||
      SelectionExtendDirection.forward =>
        true,
      SelectionExtendDirection.previousLine ||
      SelectionExtendDirection.backward =>
        false,
    };
    final result = _handleGranularExtension(
      GranularlyExtendSelectionEvent(
        forward: forward,
        isEnd: event.isEnd,
        granularity: TextGranularity.character,
      ),
    );
    if (event.direction == SelectionExtendDirection.forward ||
        event.direction == SelectionExtendDirection.backward) {
      return SelectionResult.end;
    }
    return result;
  }

  int _nextWordOffset(int logicalOffset, bool forward) {
    final visual = _visualOffset(logicalOffset);
    if (forward && visual >= _visibleLength) return contentLength;
    if (!forward && visual <= 0) return 0;
    final lookup = forward ? visual : visual - 1;
    final boundary = descriptor.painter.getWordBoundary(
      TextPosition(offset: lookup.clamp(0, _visibleLength)),
    );
    return _prefixLength + (forward ? boundary.end : boundary.start);
  }

  Offset _toLocal(Offset globalPosition) {
    final transform = getTransformTo(null)..invert();
    return MatrixUtils.transformPoint(transform, globalPosition);
  }

  Rect get _selectionRect {
    final boxes = boundingBoxes;
    var rect = boxes.first;
    for (final box in boxes.skip(1)) {
      rect = rect.expandToInclude(box);
    }
    return rect;
  }

  int _logicalOffsetForLocalPosition(Offset position) {
    final adjusted = SelectionUtils.adjustDragOffset(
      _selectionRect,
      position,
      direction: descriptor.painter.textDirection ?? TextDirection.ltr,
    );
    final visual = descriptor.painter.getPositionForOffset(adjusted).offset;
    return (_prefixLength + visual).clamp(0, contentLength);
  }

  int _visualOffset(int logicalOffset) =>
      (logicalOffset - _prefixLength).clamp(0, _visibleLength);

  Offset _selectionPoint(int logicalOffset) {
    final position = TextPosition(offset: _visualOffset(logicalOffset));
    return descriptor.painter.getOffsetForCaret(position, Rect.zero) +
        Offset(
          0,
          descriptor.painter.getFullHeightForCaret(position, Rect.zero),
        );
  }

  SelectionGeometry _buildGeometry() {
    final start = _selectionStart;
    final end = _selectionEnd;
    if (start == null || end == null) {
      return const SelectionGeometry(
        status: SelectionStatus.none,
        hasContent: true,
      );
    }

    final reversed = start.offset > end.offset;
    final collapsed = start.offset == end.offset;
    final rtl = descriptor.painter.textDirection == TextDirection.rtl;
    final flipHandles = reversed != rtl;
    final handleTypes = switch ((collapsed, flipHandles)) {
      (true, _) => (
          TextSelectionHandleType.collapsed,
          TextSelectionHandleType.collapsed,
        ),
      (false, true) => (
          TextSelectionHandleType.right,
          TextSelectionHandleType.left,
        ),
      (false, false) => (
          TextSelectionHandleType.left,
          TextSelectionHandleType.right,
        ),
    };
    final visualStart = _visualOffset(start.offset);
    final visualEnd = _visualOffset(end.offset);
    final boxes = descriptor.painter.getBoxesForSelection(
      TextSelection(
        baseOffset: visualStart,
        extentOffset: visualEnd,
      ),
    );

    return SelectionGeometry(
      startSelectionPoint: SelectionPoint(
        localPosition: _selectionPoint(start.offset),
        lineHeight: descriptor.painter.preferredLineHeight,
        handleType: handleTypes.$1,
      ),
      endSelectionPoint: SelectionPoint(
        localPosition: _selectionPoint(end.offset),
        lineHeight: descriptor.painter.preferredLineHeight,
        handleType: handleTypes.$2,
      ),
      selectionRects: <Rect>[for (final box in boxes) box.toRect()],
      status:
          collapsed ? SelectionStatus.collapsed : SelectionStatus.uncollapsed,
      hasContent: true,
    );
  }

  void _didChangeSelection() {
    _geometry = _buildGeometry();
    owner.markSelectionNeedsPaint();
    notifyListeners();
  }

  void restoreSelection({
    required int startOffset,
    required int endOffset,
  }) {
    _selectionStart = TextPosition(
      offset: startOffset.clamp(0, contentLength),
    );
    _selectionEnd = TextPosition(
      offset: endOffset.clamp(0, contentLength),
    );
    _didChangeSelection();
  }

  @override
  SelectedContent? getSelectedContent() {
    final start = _selectionStart;
    final end = _selectionEnd;
    if (start == null || end == null || start.offset == end.offset) {
      return null;
    }
    final lower = math.min(start.offset, end.offset);
    final upper = math.max(start.offset, end.offset);
    return SelectedContent(
      plainText: descriptor.text.substring(lower, upper),
    );
  }

  @override
  SelectedContentRange? getSelection() {
    final start = _selectionStart;
    final end = _selectionEnd;
    if (start == null || end == null) return null;
    return SelectedContentRange(
      startOffset: start.offset,
      endOffset: end.offset,
    );
  }

  @override
  void pushHandleLayers(LayerLink? startHandle, LayerLink? endHandle) {
    if (!owner.selectionAttached) {
      assert(startHandle == null && endHandle == null);
      return;
    }
    if (_startHandle == startHandle && _endHandle == endHandle) return;
    _startHandle = startHandle;
    _endHandle = endHandle;
    owner.markSelectionNeedsPaint();
  }

  void paintSelection(PaintingContext context, Offset renderOffset) {
    final start = _selectionStart;
    final end = _selectionEnd;
    if (start == null || end == null) return;
    final painter = Paint()
      ..style = PaintingStyle.fill
      ..color = selectionColor;
    final visualStart = _visualOffset(start.offset);
    final visualEnd = _visualOffset(end.offset);
    final offset = renderOffset + descriptor.paintOffset();
    for (final box in descriptor.painter.getBoxesForSelection(
      TextSelection(
        baseOffset: visualStart,
        extentOffset: visualEnd,
      ),
    )) {
      context.canvas.drawRect(box.toRect().shift(offset), painter);
    }
  }

  void paintHandleLayers(PaintingContext context, Offset renderOffset) {
    final offset = renderOffset + descriptor.paintOffset();
    if (_startHandle != null && value.startSelectionPoint != null) {
      context.pushLayer(
        LeaderLayer(
          link: _startHandle!,
          offset: offset + value.startSelectionPoint!.localPosition,
        ),
        (_, __) {},
        Offset.zero,
      );
    }
    if (_endHandle != null && value.endSelectionPoint != null) {
      context.pushLayer(
        LeaderLayer(
          link: _endHandle!,
          offset: offset + value.endSelectionPoint!.localPosition,
        ),
        (_, __) {},
        Offset.zero,
      );
    }
  }
}
