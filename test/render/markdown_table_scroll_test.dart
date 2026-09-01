import 'package:flutter/material.dart';
import 'package:flutter_md/flutter_md.dart';
import 'package:flutter_test/flutter_test.dart';

void main() => group('Markdown table scrolling', () {
      testWidgets('wide tables scroll horizontally', (tester) async {
        await tester.pumpWidget(
          _app(
            width: 220,
            markdown: 'Before\n\n'
                '| Provider | Model | Notes |\n'
                '| --- | --- | --- |\n'
                '| OpenAI | openai/gpt-4.1 | Long capability description |\n'
                '| Anthropic | anthropic/claude-sonnet-4 | Another long capability description |\n\n'
                'After',
          ),
        );

        final scrollView = find.byType(SingleChildScrollView);
        expect(scrollView, findsOneWidget);

        final scrollable = find.descendant(
          of: scrollView,
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(position.maxScrollExtent, greaterThan(0));

        await tester.drag(scrollView, const Offset(-180, 0));
        await tester.pumpAndSettle();

        expect(position.pixels, greaterThan(0));
      });

      testWidgets('narrow tables do not create horizontal overflow',
          (tester) async {
        await tester.pumpWidget(
          _app(
            width: 320,
            markdown: '| A | B |\n| --- | --- |\n| 1 | 2 |',
          ),
        );

        final scrollView = find.byType(SingleChildScrollView);
        expect(scrollView, findsOneWidget);
        final scrollable = find.descendant(
          of: scrollView,
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scrollable).position;

        expect(position.maxScrollExtent, 0);
        expect(
          tester
              .getSize(
                find.byKey(const ValueKey<Object>('markdown-table-0')),
              )
              .width,
          320,
        );
      });

      testWidgets('streaming tables stay hidden until complete',
          (tester) async {
        final complete = ValueNotifier<bool>(false);
        addTearDown(complete.dispose);
        final markdown = Markdown.fromString(
          '| Provider | Model | Notes |\n'
          '| --- | --- | --- |\n'
          '| Anthropic | anthropic/claude-sonnet-4 | Long capability description |',
        );

        Widget subject() => _frame(
              width: 220,
              child: MarkdownWidget(
                markdown: markdown,
                animationConfig: const MarkdownAnimationConfig(enabled: true),
                isStreamingComplete: complete,
              ),
            );

        await tester.pumpWidget(subject());

        final scrollView = find.byType(SingleChildScrollView);
        expect(tester.getSize(scrollView).height, 0);

        complete.value = true;
        await tester.pumpWidget(subject());
        await tester.pumpAndSettle();

        expect(tester.getSize(scrollView).height, greaterThan(0));
        final scrollable = find.descendant(
          of: scrollView,
          matching: find.byType(Scrollable),
        );
        expect(
          tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
          greaterThan(0),
        );
      });

      testWidgets('table replacements retain their horizontal position',
          (tester) async {
        const parser = MarkdownSourceParser();
        final document = parser.parse(
          '| Provider | Model | Notes |\n'
          '| --- | --- | --- |\n'
          '| OpenAI | openai/gpt-4.1 | Long capability description |',
        );
        final blockId = document.blocks.single.id;

        await tester.pumpWidget(
          _frame(
            width: 220,
            child: MarkdownWidget.contentReplacement(document: document),
          ),
        );

        final scrollView = find.byType(SingleChildScrollView);
        await tester.drag(scrollView, const Offset(-120, 0));
        await tester.pumpAndSettle();
        var scrollable = find.descendant(
          of: scrollView,
          matching: find.byType(Scrollable),
        );
        final oldOffset =
            tester.state<ScrollableState>(scrollable).position.pixels;
        expect(oldOffset, greaterThan(0));

        await tester.pumpWidget(
          _frame(
            width: 220,
            child: MarkdownWidget.contentReplacement(
              document: document,
              replacements: <MarkdownBlockId, String>{
                blockId: '| Provider | Model | Notes |\n'
                    '| --- | --- | --- |\n'
                    '| Anthropic | anthropic/claude-sonnet-4 | Another long capability description |',
              },
            ),
          ),
        );

        scrollable = find.descendant(
          of: scrollView,
          matching: find.byType(Scrollable),
        );
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          oldOffset,
        );
      });
    });

Widget _app({required double width, required String markdown}) => MaterialApp(
      home: _body(
        width: width,
        child: MarkdownWidget(markdown: Markdown.fromString(markdown)),
      ),
    );

Widget _frame({required double width, required Widget child}) => MaterialApp(
      home: _body(width: width, child: child),
    );

Widget _body({required double width, required Widget child}) => Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    );
