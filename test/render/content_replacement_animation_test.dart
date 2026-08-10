import 'package:flutter/material.dart';
import 'package:flutter_md/flutter_md.dart';
import 'package:flutter_md/src/render.dart' show MarkdownRenderObject;
import 'package:flutter_test/flutter_test.dart';

void main() => group('content replacement animation', () {
      const parser = MarkdownSourceParser();

      test('uses the replacement motion defaults', () {
        const config = MarkdownAnimationConfig.contentReplacement();

        expect(config.mode, MarkdownAnimationMode.contentReplacement);
        expect(config.duration, const Duration(milliseconds: 420));
        expect(config.curve, Curves.easeOutCubic);
        expect(config.opacityRange, const AnimationRange(start: 0.72, end: 1));
        expect(config.blurRange, const AnimationRange(start: 5, end: 0));
        expect(config.offsetRange, isNull);
      });

      testWidgets('initial render is static and only changed blocks replay',
          (tester) async {
        final document = parser.parse('# One\n\n# Two');
        final firstId = document.blocks.first.id;
        final secondId = document.blocks.last.id;
        const key = ValueKey<String>('markdown');

        await tester.pumpWidget(
          _app(
            MarkdownWidget.contentReplacement(
              key: key,
              document: document,
            ),
          ),
        );
        var renderObject = _renderObject(tester, key);
        expect(renderObject.debugAnimatingBlockIds, isEmpty);
        expect(renderObject.debugAnimationValueForBlock(firstId), 1);
        expect(renderObject.debugAnimationValueForBlock(secondId), 1);

        await tester.pumpWidget(
          _app(
            MarkdownWidget.contentReplacement(
              key: key,
              document: document,
              replacements: <MarkdownBlockId, String>{firstId: '# Changed'},
            ),
          ),
        );
        renderObject = _renderObject(tester, key);
        expect(renderObject.debugAnimatingBlockIds, <MarkdownBlockId>{firstId});
        expect(renderObject.debugAnimationValueForBlock(firstId), 0);
        expect(renderObject.debugAnimationValueForBlock(secondId), 1);

        await tester.pump(const Duration(milliseconds: 220));
        final midway = renderObject.debugAnimationValueForBlock(firstId)!;
        expect(midway, inExclusiveRange(0, 1));
        await tester.pump(const Duration(milliseconds: 210));
        expect(renderObject.debugAnimatingBlockIds, isEmpty);

        await tester.pumpWidget(
          _app(
            MarkdownWidget.contentReplacement(
              key: key,
              document: document,
              replacements: <MarkdownBlockId, String>{
                firstId: '# Changed',
                secondId: '# Changed too',
              },
            ),
          ),
        );
        expect(
          renderObject.debugAnimatingBlockIds,
          <MarkdownBlockId>{secondId},
        );
      });

      testWidgets('cached replacements do not animate on first render',
          (tester) async {
        final document = parser.parse('Original');
        final id = document.blocks.single.id;
        const key = ValueKey<String>('markdown');

        await tester.pumpWidget(
          _app(
            MarkdownWidget.contentReplacement(
              key: key,
              document: document,
              replacements: <MarkdownBlockId, String>{id: 'Cached'},
            ),
          ),
        );

        final renderObject = _renderObject(tester, key);
        expect(renderObject.debugAnimatingBlockIds, isEmpty);
        expect(renderObject.debugAnimationValueForBlock(id), 1);
      });

      testWidgets('mode changes reset aliased controllers safely',
          (tester) async {
        final document = parser.parse('Original');
        final id = document.blocks.single.id;
        const key = ValueKey<String>('markdown');
        final replacements = <MarkdownBlockId, String>{
          id: 'First\n\nSecond',
        };

        await tester.pumpWidget(
          _app(
            MarkdownWidget.contentReplacement(
              key: key,
              document: document,
              replacements: replacements,
            ),
          ),
        );
        var renderObject = _renderObject(tester, key);
        expect(renderObject.debugAnimationControllerCount, 3);
        expect(renderObject.debugUniqueAnimationControllerCount, 1);

        await tester.pumpWidget(
          _app(
            MarkdownWidget.contentReplacement(
              key: key,
              document: document,
              replacements: replacements,
              animationConfig: const MarkdownAnimationConfig(
                enabled: true,
                duration: Duration(milliseconds: 20),
              ),
            ),
          ),
        );
        renderObject = _renderObject(tester, key);
        expect(renderObject.debugAnimationControllerCount, 2);
        expect(renderObject.debugUniqueAnimationControllerCount, 2);

        await tester.pumpWidget(
          _app(
            MarkdownWidget.contentReplacement(
              key: key,
              document: document,
              replacements: replacements,
            ),
          ),
        );
        renderObject = _renderObject(tester, key);
        expect(renderObject.debugAnimationControllerCount, 3);
        expect(renderObject.debugUniqueAnimationControllerCount, 1);
      });

      testWidgets('list and table replacements animate as whole blocks',
          (tester) async {
        final document = parser.parse(
          '- One\n- Two\n\n'
          '| A | B |\n|---|---|\n| 1 | 2 |',
        );
        final listBlock = document.blocks.firstWhere((b) => b.block is MD$List);
        final tableBlock =
            document.blocks.firstWhere((b) => b.block is MD$Table);
        const key = ValueKey<String>('markdown');

        await tester.pumpWidget(
          _app(MarkdownWidget.contentReplacement(key: key, document: document)),
        );
        await tester.pumpWidget(
          _app(
            MarkdownWidget.contentReplacement(
              key: key,
              document: document,
              replacements: <MarkdownBlockId, String>{
                listBlock.id: '- Eins\n- Zwei',
                tableBlock.id: '| A | B |\n|---|---|\n| 3 | 4 |',
              },
            ),
          ),
        );

        expect(
          _renderObject(tester, key).debugAnimatingBlockIds,
          <MarkdownBlockId>{listBlock.id, tableBlock.id},
        );
      });

      testWidgets('MediaQuery.disableAnimations applies replacements instantly',
          (tester) async {
        final document = parser.parse('Original');
        final id = document.blocks.single.id;
        const key = ValueKey<String>('markdown');

        await tester.pumpWidget(
          _app(
            MarkdownWidget.contentReplacement(key: key, document: document),
            disableAnimations: true,
          ),
        );
        await tester.pumpWidget(
          _app(
            MarkdownWidget.contentReplacement(
              key: key,
              document: document,
              replacements: <MarkdownBlockId, String>{id: 'Replacement'},
            ),
            disableAnimations: true,
          ),
        );

        final renderObject = _renderObject(tester, key);
        expect(renderObject.debugAnimatingBlockIds, isEmpty);
        expect(renderObject.debugPlainText, 'Replacement');
      });

      testWidgets('compensates height changes for blocks above the viewport',
          (tester) async {
        final source = <String>[
          'Short',
          for (var index = 0; index < 30; index++) '# Heading $index',
        ].join('\n\n');
        final document = parser.parse(source);
        final id = document.blocks.first.id;
        final controller = ScrollController();
        addTearDown(controller.dispose);
        const key = ValueKey<String>('markdown');

        Widget scrollApp(Map<MarkdownBlockId, String> replacements) =>
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 180,
                  child: SingleChildScrollView(
                    controller: controller,
                    child: SizedBox(
                      width: 180,
                      child: MarkdownWidget.contentReplacement(
                        key: key,
                        document: document,
                        replacements: replacements,
                      ),
                    ),
                  ),
                ),
              ),
            );

        await tester.pumpWidget(scrollApp(const <MarkdownBlockId, String>{}));
        controller.jumpTo(100);
        await tester.pump();
        final renderObject = _renderObject(tester, key);
        final oldHeight = renderObject.blockBoundsForId(id)!.height;
        final oldPixels = controller.position.pixels;

        await tester.pumpWidget(
          scrollApp(<MarkdownBlockId, String>{
            id: List<String>.filled(12, 'A much longer replacement line.')
                .join(' '),
          }),
        );
        await tester.pump();

        final newHeight = renderObject.blockBoundsForId(id)!.height;
        expect(newHeight, greaterThan(oldHeight));
        expect(
          controller.position.pixels,
          closeTo(oldPixels + newHeight - oldHeight, 0.01),
        );
      });

      testWidgets('reverse scroll compensation uses the opposite direction',
          (tester) async {
        final source = <String>[
          for (var index = 0; index < 50; index++) '# Heading $index',
        ].join('\n\n');
        final document = parser.parse(source);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        const key = ValueKey<String>('markdown');

        Widget reverseApp(Map<MarkdownBlockId, String> replacements) =>
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 180,
                  child: SingleChildScrollView(
                    reverse: true,
                    controller: controller,
                    child: SizedBox(
                      width: 180,
                      child: MarkdownWidget.contentReplacement(
                        key: key,
                        document: document,
                        replacements: replacements,
                      ),
                    ),
                  ),
                ),
              ),
            );

        await tester.pumpWidget(reverseApp(const <MarkdownBlockId, String>{}));
        controller.jumpTo(controller.position.maxScrollExtent / 2);
        await tester.pump();
        final renderObject = _renderObject(tester, key);
        final viewportTop =
            tester.getTopLeft(find.byType(SingleChildScrollView)).dy;
        final block = document.blocks.where((block) {
          if (block.block is! MD$Heading) return false;
          final bounds = renderObject.blockBoundsForId(block.id);
          return bounds != null &&
              renderObject.localToGlobal(bounds.bottomLeft).dy <= viewportTop;
        }).first;
        final oldHeight = renderObject.blockBoundsForId(block.id)!.height;
        final oldPixels = controller.position.pixels;

        await tester.pumpWidget(
          reverseApp(<MarkdownBlockId, String>{
            block.id: '# ${List<String>.filled(30, 'longer').join(' ')}',
          }),
        );
        await tester.pump();

        final newHeight = renderObject.blockBoundsForId(block.id)!.height;
        expect(newHeight, greaterThan(oldHeight));
        expect(
          controller.position.pixels,
          closeTo(oldPixels - (newHeight - oldHeight), 0.01),
        );
      });

      testWidgets('horizontal scroll positions are never compensated',
          (tester) async {
        final document = parser.parse('# Short\n\n# Tail');
        final id = document.blocks.first.id;
        final controller = ScrollController();
        addTearDown(controller.dispose);
        const key = ValueKey<String>('markdown');

        Widget horizontalApp(Map<MarkdownBlockId, String> replacements) =>
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 80,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: controller,
                    child: SizedBox(
                      width: 1000,
                      child: Transform.translate(
                        offset: const Offset(0, -100),
                        child: SizedBox(
                          width: 180,
                          child: MarkdownWidget.contentReplacement(
                            key: key,
                            document: document,
                            replacements: replacements,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

        await tester
            .pumpWidget(horizontalApp(const <MarkdownBlockId, String>{}));
        controller.jumpTo(100);
        await tester.pump();
        final oldPixels = controller.position.pixels;

        await tester.pumpWidget(
          horizontalApp(<MarkdownBlockId, String>{
            id: '# ${List<String>.filled(30, 'longer').join(' ')}',
          }),
        );
        await tester.pump();

        expect(controller.position.pixels, oldPixels);
      });

      testWidgets('rebuild disposes painters that are no longer rendered',
          (tester) async {
        final document = parser.parse('Original');
        final id = document.blocks.single.id;
        final painters = <_TrackingBlockPainter>[];
        final theme = MarkdownThemeData(
          textStyle: const TextStyle(),
          builder: (block, theme) {
            final painter = _TrackingBlockPainter();
            painters.add(painter);
            return painter;
          },
        );
        const key = ValueKey<String>('markdown');

        await tester.pumpWidget(
          _app(
            MarkdownWidget.contentReplacement(
              key: key,
              document: document,
              theme: theme,
            ),
          ),
        );
        expect(painters, hasLength(2));
        expect(painters.first.disposed, isTrue);
        expect(painters.last.disposed, isFalse);

        await tester.pumpWidget(
          _app(
            MarkdownWidget.contentReplacement(
              key: key,
              document: document,
              replacements: <MarkdownBlockId, String>{id: 'Changed'},
              theme: theme,
            ),
          ),
        );
        expect(painters[painters.length - 2].disposed, isTrue);
        expect(painters.last.disposed, isFalse);

        await tester.pumpWidget(const SizedBox());
        expect(painters.last.disposed, isTrue);
      });
    });

Widget _app(Widget child, {bool disableAnimations = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: child),
      ),
    );

MarkdownRenderObject _renderObject(
  WidgetTester tester,
  Key key,
) =>
    tester.renderObject<MarkdownRenderObject>(find.byKey(key));

final class _TrackingBlockPainter implements BlockPainter {
  bool disposed = false;

  @override
  Size get size => const Size(100, 20);

  @override
  void dispose() => disposed = true;

  @override
  void handleTapDown(PointerDownEvent event) {}

  @override
  void handleTapUp(PointerUpEvent event) {}

  @override
  Size layout(double width) => Size(width, 20);

  @override
  void paint(Canvas canvas, Size size, double offset) {}
}
