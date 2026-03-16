import 'package:flutter/material.dart';
import 'package:flutter_md/src/nodes.dart';
import 'package:flutter_md/src/render.dart';
import 'package:flutter_md/src/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() => group('BlockPainter\$Table', () {
      test('includes configured top spacing and cell padding in layout size',
          () {
        final theme = MarkdownThemeData(
          textStyle: const TextStyle(
            color: Colors.black,
            fontSize: 14,
          ),
          tableHeaderStyle: const TextStyle(
            color: Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tableHeaderBackgroundColor: Colors.white,
          tableRowBackgroundColor: Colors.white,
          tableAlternateRowBackgroundColor: const Color(0xFFF5F5F5),
          tableBorder: const BorderSide(color: Colors.blueGrey),
          tableBorderRadius: BorderRadius.circular(10),
          tableCellPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          tableTopSpacing: 8,
        );

        final painter = BlockPainter$Table(
          header: _tableRow(const <String>['Name', 'Value']),
          rows: <MD$TableRow>[
            _tableRow(const <String>['Alpha', '42']),
          ],
          theme: theme,
        );
        addTearDown(painter.dispose);

        final size = painter.layout(320);
        final headerPainter = TextPainter(
          text: const TextSpan(
            text: 'Name',
            style: TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: theme.textDirection,
          textScaler: theme.textScaler,
        )..layout();
        addTearDown(headerPainter.dispose);
        final rowPainter = TextPainter(
          text: const TextSpan(
            text: 'Alpha',
            style: TextStyle(
              color: Colors.black,
              fontSize: 14,
            ),
          ),
          textDirection: theme.textDirection,
          textScaler: theme.textScaler,
        )..layout();
        addTearDown(rowPainter.dispose);

        expect(
          size.height,
          closeTo(headerPainter.height + rowPainter.height + 48, 0.001),
        );
      });
    });

MD$TableRow _tableRow(List<String> values) => MD$TableRow(
      text: values.join(' | '),
      cells: <List<MD$Span>>[
        for (final value in values)
          <MD$Span>[
            MD$Span(
              start: 0,
              end: value.length,
              text: value,
            ),
          ],
      ],
    );
