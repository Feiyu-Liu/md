import 'package:meta/meta.dart';

import 'nodes.dart';
import 'parser.dart' show markdownDecoder;

/// {@template markdown}
/// Markdown entity.
/// {@endtemplate}
@immutable
final class Markdown {
  /// Creates a [Markdown] instance with the given text and blocks.
  /// {@macro markdown}
  const Markdown({
    required this.markdown,
    required this.blocks,
    this.closedBlockCount,
  });

  /// Empty markdown.
  /// {@macro markdown}
  const Markdown.empty()
      : markdown = '',
        blocks = const <MD$Block>[],
        closedBlockCount = 0;

  /// Creates a [Markdown] instance from a markdown string.
  /// This method uses the [markdownDecoder] to parse the string
  /// and convert it into a list of [MD$Block] objects.
  ///
  /// This method is relatively expensive and should be used
  /// sparingly, outside build phase, especially for large markdown strings.
  /// {@macro markdown}
  factory Markdown.fromString(String markdown) {
    final result = markdownDecoder.convert(markdown);
    // When parsing from string, all blocks are closed
    return Markdown(
      markdown: result.markdown,
      blocks: result.blocks,
      closedBlockCount: result.blocks.length,
    );
  }

  /// The original markdown string.
  final String markdown;

  /// List of blocks in the markdown.
  final List<MD$Block> blocks;

  /// Number of closed blocks.
  /// - For streaming parsing: only the first [closedBlockCount] blocks are
  ///   fully closed and won't change.
  /// - For batch parsing (fromString): equals [blocks.length] (all closed).
  /// - If null, all blocks are considered closed.
  final int? closedBlockCount;

  /// Returns the list of closed blocks.
  /// Only closed blocks should be rendered during streaming.
  List<MD$Block> get closedBlocks {
    final count = closedBlockCount ?? blocks.length;
    if (count >= blocks.length) return blocks;
    if (count <= 0) return const <MD$Block>[];
    return blocks.sublist(0, count);
  }

  /// Returns true if the markdown contains no blocks.
  bool get isEmpty => blocks.isEmpty;

  /// Returns true if the markdown contains any blocks.
  bool get isNotEmpty => blocks.isNotEmpty;

  /// Plain text representation of the markdown.
  ///
  /// WARNING: This is not the same as the original markdown string
  /// and relatively expensive to compute.
  String get text {
    if (blocks.isEmpty) return markdown;
    final buffer = StringBuffer();
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (i > 0) buffer.writeln();
      switch (block) {
        case MD$Paragraph(:List<MD$Span> spans):
          for (final span in spans) {
            buffer.write(span.text);
          }
        case MD$Heading(:List<MD$Span> spans):
          for (final span in spans) {
            buffer.write(span.text);
          }
        case MD$Quote(:List<MD$Span> spans):
          for (final span in spans) {
            buffer.write(span.text);
          }
        case MD$Code(:String text):
          buffer.write(text);
        case MD$List(:List<MD$ListItem> items):
          for (var j = 0; j < items.length; j++) {
            if (j > 0) buffer.writeln();
            final item = items[j];
            for (final span in item.spans) buffer.write(span.text);
          }
        case MD$Table(:List<MD$TableRow> rows):
          for (var j = 0; j < rows.length; j++) {
            if (j > 0) buffer.writeln();
            final row = rows[j];
            for (var k = 0; k < row.cells.length; k++) {
              //if (k > 0) buffer.write(' | ');
              final spans = row.cells[k];
              for (final span in spans) {
                buffer.write(span.text);
              }
            }
          }
        case MD$Divider():
          buffer.write('---');
        case MD$Spacer(:int count):
          buffer.write('\n' * count);
          break;
      }
    }
    return buffer.toString();
  }

  @override
  String toString() => markdown;
}
