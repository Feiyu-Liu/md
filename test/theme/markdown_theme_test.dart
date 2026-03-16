import 'package:flutter/material.dart';
import 'package:flutter_md/flutter_md.dart';
import 'package:flutter_test/flutter_test.dart';

void main() => group('MarkdownThemeData', () {
      const codeStyle = TextStyle(
        fontFamily: 'FiraCode',
        fontSize: 15,
      );
      const codeLanguageStyle = TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
      );
      const keywordStyle = TextStyle(color: Colors.red);

      test('mergeTheme keeps code block configuration', () {
        final data = MarkdownThemeData.mergeTheme(
          ThemeData.light(),
          codeStyle: codeStyle,
          codeLanguageStyle: codeLanguageStyle,
          codeBackgroundColor: Colors.black,
          codePadding: const EdgeInsets.all(12),
          codeTheme: const <String, TextStyle>{
            'keyword': keywordStyle,
          },
          codeHighlighter: const _FakeCodeHighlighter(),
        );

        expect(data.codeStyle, equals(codeStyle));
        expect(data.codeLanguageStyle, equals(codeLanguageStyle));
        expect(data.codeBackgroundColor, equals(Colors.black));
        expect(data.codePadding, const EdgeInsets.all(12));
        expect(data.codeTheme?['keyword'], equals(keywordStyle));
        expect(data.codeHighlighter, isA<_FakeCodeHighlighter>());
      });

      test('copyWith updates code configuration', () {
        final data = MarkdownThemeData(
          textStyle: const TextStyle(fontSize: 14),
        );

        final updated = data.copyWith(
          codeStyle: codeStyle,
          codeLanguageStyle: codeLanguageStyle,
          codeBackgroundColor: Colors.black,
          codePadding: const EdgeInsets.all(10),
          codeTheme: const <String, TextStyle>{
            'keyword': keywordStyle,
          },
          codeHighlighter: const _FakeCodeHighlighter(),
        ) as MarkdownThemeData;

        expect(updated.codeStyle, equals(codeStyle));
        expect(updated.codeLanguageStyle, equals(codeLanguageStyle));
        expect(updated.codeBackgroundColor, equals(Colors.black));
        expect(updated.codePadding, const EdgeInsets.all(10));
        expect(updated.codeTheme?['keyword'], equals(keywordStyle));
        expect(updated.codeHighlighter, isA<_FakeCodeHighlighter>());
      });

      test('lerp carries code configuration at t=1', () {
        final base = MarkdownThemeData(
          textStyle: const TextStyle(fontSize: 14),
        );
        final other = MarkdownThemeData(
          textStyle: const TextStyle(fontSize: 14),
          codeStyle: codeStyle,
          codeLanguageStyle: codeLanguageStyle,
          codeBackgroundColor: Colors.black,
          codePadding: const EdgeInsets.all(16),
          codeTheme: const <String, TextStyle>{
            'keyword': keywordStyle,
          },
          codeHighlighter: const _FakeCodeHighlighter(),
        );

        final lerped = base.lerp(other, 1.0) as MarkdownThemeData;

        expect(lerped.codeStyle, equals(codeStyle));
        expect(lerped.codeLanguageStyle, equals(codeLanguageStyle));
        expect(lerped.codeBackgroundColor, equals(Colors.black));
        expect(lerped.codePadding, const EdgeInsets.all(16));
        expect(lerped.codeTheme?['keyword'], equals(keywordStyle));
        expect(lerped.codeHighlighter, isA<_FakeCodeHighlighter>());
      });

      test('codeTextStyleFor merges configured token styles', () {
        final data = MarkdownThemeData(
          textStyle: const TextStyle(
            color: Colors.black,
            fontSize: 14,
          ),
          codeTheme: const <String, TextStyle>{
            'keyword': keywordStyle,
          },
        );

        final resolved = data.codeTextStyleFor('keyword');

        expect(resolved.color, equals(Colors.red));
        expect(resolved.fontFamily, equals('monospace'));
      });
    });

final class _FakeCodeHighlighter implements MarkdownCodeHighlighter {
  const _FakeCodeHighlighter();

  @override
  TextSpan build({
    required String text,
    required String? language,
    required TextStyle textStyle,
    required MarkdownThemeData theme,
  }) {
    return TextSpan(
      text: '$language:$text',
      style: textStyle,
    );
  }
}
