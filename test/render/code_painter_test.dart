import 'package:flutter/material.dart';
import 'package:flutter_md/src/render.dart';
import 'package:flutter_md/src/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() => group('BlockPainter\$Code', () {
      late MarkdownThemeData theme;

      setUp(() {
        theme = MarkdownThemeData(
          textStyle: const TextStyle(
            color: Colors.black,
            fontSize: 14,
          ),
        );
      });

      test('applies syntax highlighting for known languages', () {
        final painter = BlockPainter$Code(
          text: 'const value = "hello";',
          language: 'dart',
          theme: theme,
        );
        addTearDown(painter.dispose);

        painter.layout(320);

        final leaves = _textLeaves(painter.painter.text!);
        final colors = leaves.map((span) => span.style?.color).toSet();

        expect(leaves.length, greaterThan(1));
        expect(colors.length, greaterThan(1));
      });

      test('falls back to plain monospace when highlighting is disabled', () {
        final painter = BlockPainter$Code(
          text: 'const value = "hello";',
          language: 'dart',
          theme: theme,
          highlightSyntax: false,
        );
        addTearDown(painter.dispose);

        painter.layout(320);

        final leaves = _textLeaves(painter.painter.text!);
        final colors = leaves.map((span) => span.style?.color).toSet();

        expect(colors.length, equals(1));
      });

      test('falls back to plain monospace for unknown languages', () {
        final painter = BlockPainter$Code(
          text: 'const value = "hello";',
          language: 'made-up-language',
          theme: theme,
        );
        addTearDown(painter.dispose);

        painter.layout(320);

        final leaves = _textLeaves(painter.painter.text!);
        final colors = leaves.map((span) => span.style?.color).toSet();

        expect(colors.length, equals(1));
      });

      test('builds a language label when a language is present', () {
        final painter = BlockPainter$Code(
          text: '{"message":"hello"}',
          language: 'json',
          theme: theme,
        );
        addTearDown(painter.dispose);

        painter.layout(320);

        expect(painter.languagePainter, isNotNull);
        expect(
          painter.languagePainter!.text!.toPlainText(),
          equals('json'),
        );
      });

      test('includes configured top spacing in layout size', () {
        theme = MarkdownThemeData(
          textStyle: const TextStyle(
            color: Colors.black,
            fontSize: 14,
          ),
          codePadding: const EdgeInsets.all(10),
          codeTopSpacing: 12,
          codeBorderRadius: BorderRadius.circular(10),
          codeBorder: const BorderSide(color: Colors.blueGrey),
        );

        final painter = BlockPainter$Code(
          text: 'final answer = 42;',
          language: null,
          theme: theme,
        );
        addTearDown(painter.dispose);

        final size = painter.layout(240);
        final textPainter = TextPainter(
          text: TextSpan(
            text: 'final answer = 42;',
            style:
                theme.resolvedCodeStyle.merge(theme.resolvedCodeTheme['root']),
          ),
          textDirection: theme.textDirection,
          textScaler: theme.textScaler,
        )..layout(maxWidth: 220);
        addTearDown(textPainter.dispose);

        expect(size.height, closeTo(textPainter.height + 32, 0.001));
      });
    });

List<TextSpan> _textLeaves(InlineSpan span) {
  final leaves = <TextSpan>[];

  void visit(InlineSpan current) {
    switch (current) {
      case TextSpan(children: final children?) when children.isNotEmpty:
        for (final child in children) {
          visit(child);
        }
      case TextSpan(text: final text?) when text.isNotEmpty:
        leaves.add(current);
      case TextSpan():
        break;
      case WidgetSpan():
        break;
    }
  }

  visit(span);
  return leaves;
}
