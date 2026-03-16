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
      const codeBorder = BorderSide(color: Colors.blueGrey);
      const codeBorderRadius = BorderRadius.all(Radius.circular(10));
      const keywordStyle = TextStyle(color: Colors.red);
      const tableTextStyle = TextStyle(
        fontSize: 12,
        color: Colors.black87,
      );
      const tableHeaderStyle = TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      );
      const tableBorder = BorderSide(color: Colors.green);
      const tableBorderRadius = BorderRadius.all(Radius.circular(12));

      test('mergeTheme keeps code block configuration', () {
        final data = MarkdownThemeData.mergeTheme(
          ThemeData.light(),
          codeStyle: codeStyle,
          codeLanguageStyle: codeLanguageStyle,
          codeBackgroundColor: Colors.black,
          codePadding: const EdgeInsets.all(12),
          codeBorder: codeBorder,
          codeBorderRadius: codeBorderRadius,
          codeTopSpacing: 14,
          codeTheme: const <String, TextStyle>{
            'keyword': keywordStyle,
          },
          codeHighlighter: const _FakeCodeHighlighter(),
          tableTextStyle: tableTextStyle,
          tableHeaderStyle: tableHeaderStyle,
          tableHeaderBackgroundColor: Colors.amber,
          tableRowBackgroundColor: Colors.white,
          tableAlternateRowBackgroundColor: Colors.grey,
          tableBorder: tableBorder,
          tableBorderRadius: tableBorderRadius,
          tableCellPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          tableTopSpacing: 10,
        );

        expect(data.codeStyle, equals(codeStyle));
        expect(data.codeLanguageStyle, equals(codeLanguageStyle));
        expect(data.codeBackgroundColor, equals(Colors.black));
        expect(data.codePadding, const EdgeInsets.all(12));
        expect(data.codeBorder, equals(codeBorder));
        expect(data.codeBorderRadius, equals(codeBorderRadius));
        expect(data.codeTopSpacing, 14);
        expect(data.codeTheme?['keyword'], equals(keywordStyle));
        expect(data.codeHighlighter, isA<_FakeCodeHighlighter>());
        expect(data.tableTextStyle, equals(tableTextStyle));
        expect(data.tableHeaderStyle, equals(tableHeaderStyle));
        expect(data.tableHeaderBackgroundColor, equals(Colors.amber));
        expect(data.tableRowBackgroundColor, equals(Colors.white));
        expect(data.tableAlternateRowBackgroundColor, equals(Colors.grey));
        expect(data.tableBorder, equals(tableBorder));
        expect(data.tableBorderRadius, equals(tableBorderRadius));
        expect(
          data.tableCellPadding,
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
        expect(data.tableTopSpacing, 10);
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
          codeBorder: codeBorder,
          codeBorderRadius: codeBorderRadius,
          codeTopSpacing: 14,
          codeTheme: const <String, TextStyle>{
            'keyword': keywordStyle,
          },
          codeHighlighter: const _FakeCodeHighlighter(),
          tableTextStyle: tableTextStyle,
          tableHeaderStyle: tableHeaderStyle,
          tableHeaderBackgroundColor: Colors.amber,
          tableRowBackgroundColor: Colors.white,
          tableAlternateRowBackgroundColor: Colors.grey,
          tableBorder: tableBorder,
          tableBorderRadius: tableBorderRadius,
          tableCellPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          tableTopSpacing: 10,
        ) as MarkdownThemeData;

        expect(updated.codeStyle, equals(codeStyle));
        expect(updated.codeLanguageStyle, equals(codeLanguageStyle));
        expect(updated.codeBackgroundColor, equals(Colors.black));
        expect(updated.codePadding, const EdgeInsets.all(10));
        expect(updated.codeBorder, equals(codeBorder));
        expect(updated.codeBorderRadius, equals(codeBorderRadius));
        expect(updated.codeTopSpacing, 14);
        expect(updated.codeTheme?['keyword'], equals(keywordStyle));
        expect(updated.codeHighlighter, isA<_FakeCodeHighlighter>());
        expect(updated.tableTextStyle, equals(tableTextStyle));
        expect(updated.tableHeaderStyle, equals(tableHeaderStyle));
        expect(updated.tableHeaderBackgroundColor, equals(Colors.amber));
        expect(updated.tableRowBackgroundColor, equals(Colors.white));
        expect(updated.tableAlternateRowBackgroundColor, equals(Colors.grey));
        expect(updated.tableBorder, equals(tableBorder));
        expect(updated.tableBorderRadius, equals(tableBorderRadius));
        expect(
          updated.tableCellPadding,
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
        expect(updated.tableTopSpacing, 10);
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
          codeBorder: codeBorder,
          codeBorderRadius: codeBorderRadius,
          codeTopSpacing: 14,
          codeTheme: const <String, TextStyle>{
            'keyword': keywordStyle,
          },
          codeHighlighter: const _FakeCodeHighlighter(),
          tableTextStyle: tableTextStyle,
          tableHeaderStyle: tableHeaderStyle,
          tableHeaderBackgroundColor: Colors.amber,
          tableRowBackgroundColor: Colors.white,
          tableAlternateRowBackgroundColor: Colors.grey,
          tableBorder: tableBorder,
          tableBorderRadius: tableBorderRadius,
          tableCellPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          tableTopSpacing: 10,
        );

        final lerped = base.lerp(other, 1.0) as MarkdownThemeData;

        expect(lerped.codeStyle, equals(codeStyle));
        expect(lerped.codeLanguageStyle, equals(codeLanguageStyle));
        expect(lerped.codeBackgroundColor, equals(Colors.black));
        expect(lerped.codePadding, const EdgeInsets.all(16));
        expect(lerped.codeBorder, equals(codeBorder));
        expect(lerped.codeBorderRadius, equals(codeBorderRadius));
        expect(lerped.codeTopSpacing, 14);
        expect(lerped.codeTheme?['keyword'], equals(keywordStyle));
        expect(lerped.codeHighlighter, isA<_FakeCodeHighlighter>());
        expect(lerped.tableTextStyle, equals(tableTextStyle));
        expect(lerped.tableHeaderStyle, equals(tableHeaderStyle));
        expect(
          lerped.tableHeaderBackgroundColor,
          equals(const Color(0xFFFFC107)),
        );
        expect(lerped.tableRowBackgroundColor, equals(Colors.white));
        expect(
          lerped.tableAlternateRowBackgroundColor,
          equals(const Color(0xFF9E9E9E)),
        );
        expect(lerped.tableBorder, equals(tableBorder));
        expect(lerped.tableBorderRadius, equals(tableBorderRadius));
        expect(
          lerped.tableCellPadding,
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
        expect(lerped.tableTopSpacing, 10);
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
