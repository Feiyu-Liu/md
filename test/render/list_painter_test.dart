import 'package:flutter/material.dart';
import 'package:flutter_md/src/animation/animation_config.dart';
import 'package:flutter_md/src/markdown.dart';
import 'package:flutter_md/src/nodes.dart';
import 'package:flutter_md/src/render.dart';
import 'package:flutter_md/src/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() => group('MarkdownPainter list streaming', () {
      late MarkdownThemeData theme;

      setUp(() {
        theme = MarkdownThemeData(
          textStyle: const TextStyle(
            color: Colors.black,
            fontSize: 14,
          ),
        );
      });

      test('renders closed prefix of trailing list during streaming', () {
        final painter = MarkdownPainter(
          markdown: Markdown(
            markdown: '- A\n- B\n',
            blocks: <MD$Block>[
              MD$List(
                text: '- A\n- B',
                items: <MD$ListItem>[
                  _item('A'),
                  _item('B'),
                ],
                closedItemCount: 1,
              ),
            ],
          ),
          theme: theme,
          animationConfig: const MarkdownAnimationConfig(enabled: true),
          isStreamingComplete: ValueNotifier<bool>(false),
        );
        addTearDown(painter.dispose);

        expect(painter.isEmpty, isFalse);
        final size = painter.layout(maxWidth: 320);
        expect(size.height, greaterThan(0));
      });

      test('update detects visible item growth in trailing list', () {
        final notifier = ValueNotifier<bool>(false);
        final painter = MarkdownPainter(
          markdown: Markdown(
            markdown: '- A\n- B\n',
            blocks: <MD$Block>[
              MD$List(
                text: '- A\n- B',
                items: <MD$ListItem>[
                  _item('A'),
                  _item('B'),
                ],
                closedItemCount: 1,
              ),
            ],
          ),
          theme: theme,
          animationConfig: const MarkdownAnimationConfig(enabled: true),
          isStreamingComplete: notifier,
        );
        addTearDown(() {
          notifier.dispose();
          painter.dispose();
        });

        final firstSize = painter.layout(maxWidth: 320);
        final didUpdate = painter.update(
          markdown: Markdown(
            markdown: '- A\n- B\n- C\n',
            blocks: <MD$Block>[
              MD$List(
                text: '- A\n- B\n- C',
                items: <MD$ListItem>[
                  _item('A'),
                  _item('B'),
                  _item('C'),
                ],
                closedItemCount: 2,
              ),
            ],
          ),
          theme: theme,
          animationConfig: const MarkdownAnimationConfig(enabled: true),
          isStreamingComplete: notifier,
        );

        expect(didUpdate, isTrue);
        final secondSize = painter.layout(maxWidth: 320);
        expect(secondSize.height, greaterThan(firstSize.height));
      });
    });

MD$ListItem _item(String text, {List<MD$ListItem> children = const []}) =>
    MD$ListItem(
      marker: '-',
      text: text,
      spans: <MD$Span>[
        MD$Span(
          start: 0,
          end: text.length,
          text: text,
        ),
      ],
      children: children,
    );
