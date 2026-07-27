import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter/services.dart';
import 'package:flutter_md/flutter_md.dart';
import 'package:flutter_md/src/render.dart' show MarkdownRenderObject;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MarkdownWidget selection', () {
    testWidgets('selects paragraph text with a mouse drag', (tester) async {
      SelectedContent? selection;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              onSelectionChanged: (value) => selection = value,
              child: SizedBox(
                width: 360,
                child: MarkdownWidget(
                  markdown: Markdown.fromString(
                    'Selectable markdown paragraph',
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final rect = tester.getRect(find.byType(MarkdownWidget));
      final gesture = await tester.startGesture(
        rect.centerLeft + const Offset(2, 0),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(rect.centerRight - const Offset(2, 0));
      await gesture.up();
      await tester.pump();

      expect(selection?.plainText, isNotEmpty);
      expect(
        'Selectable markdown paragraph',
        contains(selection!.plainText),
      );
    });

    testWidgets('select all copies rendered structural plain text',
        (tester) async {
      SelectedContent? selection;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              onSelectionChanged: (value) => selection = value,
              child: SizedBox(
                width: 420,
                child: MarkdownWidget(
                  markdown: Markdown.fromString(
                    'Intro [site](https://example.com)\n\n'
                    '- one\n'
                    '  - nested\n\n'
                    '| Name | Value |\n'
                    '| --- | --- |\n'
                    '| A | 1 |\n\n'
                    '```dart\n'
                    'print(1);\n'
                    '```',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final area = tester.state<SelectionAreaState>(
        find.byType(SelectionArea),
      );
      area.selectableRegion.selectAll(SelectionChangedCause.keyboard);
      await tester.pump();

      expect(
        selection?.plainText,
        'Intro site\n\n'
        '• one\n'
        '  • nested\n\n'
        'Name\tValue\n'
        'A\t1\n\n'
        'print(1);',
      );
    });

    testWidgets('selects across Markdown blocks', (tester) async {
      SelectedContent? selection;
      await _pumpMarkdown(
        tester,
        markdown: Markdown.fromString('First block\n\nSecond block'),
        onSelectionChanged: (value) => selection = value,
      );

      final rect = tester.getRect(_renderLeaf);
      final gesture = await tester.startGesture(
        rect.topLeft + const Offset(2, 4),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveTo(rect.bottomRight - const Offset(2, 4));
      await gesture.up();
      await tester.pump();

      expect(selection?.plainText, contains('First block'));
      expect(selection?.plainText, contains('Second block'));
    });

    testWidgets('supports reverse selection and clearing', (tester) async {
      await _pumpMarkdown(
        tester,
        markdown: Markdown.fromString('First block\n\nSecond block'),
      );

      final rect = tester.getRect(_renderLeaf);
      final gesture = await tester.startGesture(
        rect.bottomLeft + const Offset(169, -4),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(-24, -1));
      await tester.pump();
      await gesture.moveTo(rect.topLeft + const Offset(2, 4));
      await gesture.up();
      await tester.pump();

      var renderObject = tester.renderObject<MarkdownRenderObject>(_renderLeaf);
      expect(renderObject.debugSelectedText, contains('First block'));
      expect(renderObject.debugSelectedText, contains('Second block'));

      await tester.tapAt(rect.topLeft + const Offset(5, 5));
      await tester.pump();
      renderObject = tester.renderObject<MarkdownRenderObject>(_renderLeaf);
      expect(renderObject.debugSelectedText, isNull);
    });

    testWidgets('double click selects a word', (tester) async {
      SelectedContent? selection;
      await _pumpMarkdown(
        tester,
        markdown: Markdown.fromString('alpha beta'),
        onSelectionChanged: (value) => selection = value,
      );

      final point =
          tester.getRect(_renderLeaf).centerLeft + const Offset(105, 0);
      final gesture = await tester.startGesture(
        point,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.up();
      await tester.pump();
      await gesture.down(point);
      await gesture.up();
      await tester.pump();

      expect(selection?.plainText, 'beta');
    });

    testWidgets('supports keyboard select all and copy', (tester) async {
      String? clipboardText;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboardText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          case 'Clipboard.getData':
            return <String, Object?>{'text': clipboardText};
          case 'Clipboard.hasStrings':
            return <String, Object?>{'value': clipboardText != null};
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      SelectedContent? selection;
      await tester.pumpWidget(
        MaterialApp(
          home: SelectionArea(
            focusNode: focusNode,
            onSelectionChanged: (value) => selection = value,
            child: MarkdownWidget(
              markdown: Markdown.fromString('keyboard copy'),
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      final modifier = switch (defaultTargetPlatform) {
        TargetPlatform.macOS ||
        TargetPlatform.iOS =>
          LogicalKeyboardKey.metaLeft,
        _ => LogicalKeyboardKey.controlLeft,
      };
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(modifier);
      await tester.pump();
      expect(selection?.plainText, 'keyboard copy');

      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(modifier);
      await tester.pump();
      expect(clipboardText, 'keyboard copy');
    });

    testWidgets('touch long press selects a word', (tester) async {
      SelectedContent? selection;
      await _pumpMarkdown(
        tester,
        markdown: Markdown.fromString('alpha beta'),
        onSelectionChanged: (value) => selection = value,
      );

      final point =
          tester.getRect(_renderLeaf).centerLeft + const Offset(105, 0);
      await tester.longPressAt(point);
      await tester.pumpAndSettle();

      expect(selection?.plainText, 'beta');
    });

    testWidgets('streaming append preserves the current selection',
        (tester) async {
      final markdown = ValueNotifier<Markdown>(
        Markdown.fromString('alpha'),
      );
      addTearDown(markdown.dispose);
      SelectedContent? selection;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              onSelectionChanged: (value) => selection = value,
              child: ValueListenableBuilder<Markdown>(
                valueListenable: markdown,
                builder: (context, value, _) => MarkdownWidget(
                  markdown: value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      _selectAll(tester);
      await tester.pump();
      expect(selection?.plainText, 'alpha');

      markdown.value = Markdown.fromString('alpha\n\nbeta');
      await tester.pump();
      await tester.pump();

      expect(selection?.plainText, 'alpha');
      final renderObject =
          tester.renderObject<MarkdownRenderObject>(_renderLeaf);
      expect(renderObject.debugSelectedText, 'alpha');
    });

    testWidgets('changed selected content clamps or clears the selection',
        (tester) async {
      final markdown = ValueNotifier<Markdown>(
        Markdown.fromString('alpha'),
      );
      addTearDown(markdown.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              child: ValueListenableBuilder<Markdown>(
                valueListenable: markdown,
                builder: (context, value, _) => MarkdownWidget(
                  markdown: value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      _selectAll(tester);
      await tester.pump();

      markdown.value = Markdown.fromString('alphX');
      await tester.pump();
      await tester.pump();
      var renderObject = tester.renderObject<MarkdownRenderObject>(_renderLeaf);
      expect(renderObject.debugSelectedText, 'alph');

      markdown.value = Markdown.fromString('XlphX');
      await tester.pump();
      await tester.pump();
      renderObject = tester.renderObject<MarkdownRenderObject>(_renderLeaf);
      expect(renderObject.debugSelectedText, isNull);
    });

    testWidgets('relayout preserves selection without duplicate fragments',
        (tester) async {
      final width = ValueNotifier<double>(360);
      addTearDown(width.dispose);
      SelectedContent? selection;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              onSelectionChanged: (value) => selection = value,
              child: ValueListenableBuilder<double>(
                valueListenable: width,
                builder: (context, value, _) => SizedBox(
                  width: value,
                  child: MarkdownWidget(
                    markdown: Markdown.fromString(
                      'first paragraph\n\nsecond paragraph',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      _selectAll(tester);
      await tester.pump();
      expect(
        selection?.plainText,
        'first paragraph\n\nsecond paragraph',
      );

      width.value = 120;
      await tester.pump();
      await tester.pump();

      expect(
        selection?.plainText,
        'first paragraph\n\nsecond paragraph',
      );
      final renderObject =
          tester.renderObject<MarkdownRenderObject>(_renderLeaf);
      expect(
        renderObject.debugSelectedText,
        'first paragraph\n\nsecond paragraph',
      );
      expect(renderObject.debugSelectionFragmentCount, 2);
    });

    testWidgets('supports RTL, scaling, and narrow wrapping', (tester) async {
      SelectedContent? selection;
      await _pumpMarkdown(
        tester,
        markdown: Markdown.fromString('مرحبا بالعالم wrapped text'),
        width: 90,
        theme: MarkdownThemeData(
          textStyle: const TextStyle(fontSize: 16),
          textDirection: TextDirection.rtl,
          textScaler: const TextScaler.linear(1.5),
        ),
        onSelectionChanged: (value) => selection = value,
      );

      _selectAll(tester);
      await tester.pump();

      expect(selection?.plainText, 'مرحبا بالعالم wrapped text');
      expect(tester.getSize(_renderLeaf).height, greaterThan(20));
    });

    testWidgets('selection geometry follows animated block offsets',
        (tester) async {
      final isComplete = ValueNotifier<bool>(false);
      addTearDown(isComplete.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              child: MarkdownWidget(
                markdown: Markdown.fromString('animated\n\nopen'),
                animationConfig: const MarkdownAnimationConfig(
                  enabled: true,
                  duration: Duration(seconds: 1),
                  curve: Curves.linear,
                  offsetRange: AnimationRange(start: 40, end: 0),
                ),
                isStreamingComplete: isComplete,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      _selectAll(tester);
      await tester.pump(const Duration(milliseconds: 100));

      var renderObject = tester.renderObject<MarkdownRenderObject>(_renderLeaf);
      final animatedTop = renderObject.debugSelectionPaintRects.first.top;
      expect(animatedTop, greaterThan(0));

      await tester.pump(const Duration(seconds: 2));
      renderObject = tester.renderObject<MarkdownRenderObject>(_renderLeaf);
      final settledTop = renderObject.debugSelectionPaintRects.first.top;
      expect(settledTop, lessThan(animatedTop));

      await tester.pump(const Duration(seconds: 1));
      renderObject = tester.renderObject<MarkdownRenderObject>(_renderLeaf);
      expect(
        renderObject.debugSelectionPaintRects.first.top,
        closeTo(settledTop, 0.01),
      );
    });

    testWidgets('does not create fragments without SelectionArea',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MarkdownWidget(
            markdown: Markdown.fromString('plain text'),
          ),
        ),
      );

      final renderObject =
          tester.renderObject<MarkdownRenderObject>(_renderLeaf);
      expect(renderObject.debugSelectionFragmentCount, 0);
    });

    testWidgets('custom block painters remain non-selectable', (tester) async {
      SelectedContent? selection;
      final theme = MarkdownThemeData(
        textStyle: const TextStyle(fontSize: 14),
        builder: (_, __) => _CustomBlockPainter(),
      );
      await _pumpMarkdown(
        tester,
        markdown: Markdown.fromString('custom painter'),
        theme: theme,
        onSelectionChanged: (value) => selection = value,
      );

      final renderObject =
          tester.renderObject<MarkdownRenderObject>(_renderLeaf);
      expect(renderObject.debugSelectionFragmentCount, 0);
      _selectAll(tester);
      await tester.pump();
      expect(selection, isNull);
    });

    testWidgets('link taps fire once and selection drags do not tap',
        (tester) async {
      var taps = 0;
      final theme = MarkdownThemeData(
        textStyle: const TextStyle(fontSize: 16),
        onLinkTap: (_, __) => taps++,
      );
      await _pumpMarkdown(
        tester,
        markdown: Markdown.fromString('[link](https://example.com) suffix'),
        theme: theme,
      );

      final rect = tester.getRect(_renderLeaf);
      final linkPoint = rect.centerLeft + const Offset(10, 0);
      await tester.tapAt(linkPoint);
      await tester.pump();
      expect(taps, 1);

      await tester.tapAt(rect.centerRight - const Offset(4, 0));
      await tester.pump();
      expect(taps, 1);

      final gesture = await tester.startGesture(
        linkPoint,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(rect.centerRight);
      await gesture.up();
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('removal unregisters fragments without registrar errors',
        (tester) async {
      await _pumpMarkdown(
        tester,
        markdown: Markdown.fromString('temporary'),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}

Finder get _renderLeaf => find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_MarkdownRenderObjectWidget',
    );

Future<void> _pumpMarkdown(
  WidgetTester tester, {
  required Markdown markdown,
  MarkdownThemeData? theme,
  double width = 360,
  ValueChanged<SelectedContent?>? onSelectionChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SelectionArea(
          onSelectionChanged: onSelectionChanged,
          child: SizedBox(
            width: width,
            child: MarkdownWidget(
              markdown: markdown,
              theme: theme,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _selectAll(WidgetTester tester) {
  tester
      .state<SelectionAreaState>(find.byType(SelectionArea))
      .selectableRegion
      .selectAll(SelectionChangedCause.keyboard);
}

class _CustomBlockPainter implements BlockPainter {
  Size _size = Size.zero;

  @override
  Size get size => _size;

  @override
  Size layout(double width) => _size = Size(width, 20);

  @override
  void paint(Canvas canvas, Size size, double offset) {}

  @override
  void handleTapDown(PointerDownEvent event) {}

  @override
  void handleTapUp(PointerUpEvent event) {}

  @override
  void dispose() {}
}
