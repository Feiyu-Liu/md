// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_md/flutter_md.dart';
import 'package:flutter_test/flutter_test.dart';

const _updateCount = 200;
const _runCount = 10;

void main() {
  testWidgets('markdown render selection benchmark', (tester) async {
    final updates = _buildUpdates();

    final noSelection = await _measure(
      tester,
      updates,
      selectionEnabled: false,
    );
    final selectionEnabled = await _measure(
      tester,
      updates,
      selectionEnabled: true,
    );

    final noSelectionMedian = _median(noSelection);
    final selectionMedian = _median(selectionEnabled);
    final overhead = (selectionMedian / noSelectionMedian - 1) * 100;

    print('Markdown render benchmark (500 lines, 200 updates, 10 runs)');
    print('No selection median: ${noSelectionMedian.toStringAsFixed(1)} ms');
    print(
      'Selection enabled median: '
      '${selectionMedian.toStringAsFixed(1)} ms',
    );
    print('Selection overhead: ${overhead.toStringAsFixed(1)}%');
  });
}

Future<List<double>> _measure(
  WidgetTester tester,
  List<Markdown> updates, {
  required bool selectionEnabled,
}) async {
  final markdown = ValueNotifier<Markdown>(updates.first);
  addTearDown(markdown.dispose);

  Widget child = SizedBox(
    width: 720,
    child: ValueListenableBuilder<Markdown>(
      valueListenable: markdown,
      builder: (context, value, _) => MarkdownWidget(markdown: value),
    ),
  );
  if (selectionEnabled) {
    child = SelectionArea(child: child);
  }

  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: child)),
  );

  for (var i = 0; i < 10; i++) {
    markdown.value = updates[i + 1];
    await tester.pump();
  }

  final samples = <double>[];
  for (var run = 0; run < _runCount; run++) {
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < updates.length; i++) {
      markdown.value = updates[i];
      await tester.pump();
    }
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds / 1000);
  }

  await tester.pumpWidget(const SizedBox.shrink());
  return samples;
}

List<Markdown> _buildUpdates() {
  final lines = <String>[
    for (var i = 0; i < 500; i++)
      switch (i % 10) {
        0 => '## Heading $i',
        1 => '- List item $i',
        2 => '> Quote line $i',
        _ => 'Paragraph $i with **bold** and [link](https://example.com).',
      },
  ];
  final content = lines.join('\n\n');

  return <Markdown>[
    for (var i = 1; i <= _updateCount; i++)
      Markdown.fromString(
        content.substring(0, content.length * i ~/ _updateCount),
      ),
  ];
}

double _median(List<double> values) {
  final sorted = values.toList()..sort();
  final middle = sorted.length ~/ 2;
  return (sorted[middle - 1] + sorted[middle]) / 2;
}
