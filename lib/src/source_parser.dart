part of 'parser.dart';

/// Stable, serializable identity for a block in an original Markdown source.
@immutable
final class MarkdownBlockId {
  /// Creates an ID from an inclusive [start] and exclusive [end] source offset.
  const MarkdownBlockId(this.start, this.end)
      : assert(start >= 0),
        assert(end >= start);

  /// Parses the `b:<start>:<end>` representation.
  factory MarkdownBlockId.parse(String value) {
    final parts = value.split(':');
    if (parts.length != 3 || parts.first != 'b') {
      throw FormatException('Invalid Markdown block ID', value);
    }
    final start = int.tryParse(parts[1]);
    final end = int.tryParse(parts[2]);
    if (start == null || end == null || start < 0 || end < start) {
      throw FormatException('Invalid Markdown block ID', value);
    }
    return MarkdownBlockId(start, end);
  }

  /// Restores an ID from its JSON string value.
  factory MarkdownBlockId.fromJson(String value) =>
      MarkdownBlockId.parse(value);

  /// Inclusive UTF-16 offset in the original Dart string.
  final int start;

  /// Exclusive UTF-16 offset in the original Dart string.
  final int end;

  /// Stable `b:<start>:<end>` representation.
  String get value => 'b:$start:$end';

  /// Converts this ID to a JSON-safe string value.
  String toJson() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownBlockId && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => value;
}

/// A Markdown AST block paired with its exact original source range.
@immutable
final class MarkdownSourceBlock {
  /// Creates a source block.
  const MarkdownSourceBlock({
    required this.id,
    required this.start,
    required this.end,
    required this.source,
    required this.block,
  });

  /// Stable identity derived from [start] and [end].
  final MarkdownBlockId id;

  /// Inclusive UTF-16 offset in the original source.
  final int start;

  /// Exclusive UTF-16 offset in the original source.
  final int end;

  /// Exact source substring in the range `[start, end)`.
  final String source;

  /// Parsed AST block produced by the package's shared parser.
  final MD$Block block;
}

/// Parsed Markdown source with exact block ranges and replacement support.
@immutable
final class MarkdownSourceDocument {
  /// Creates a parsed source document.
  const MarkdownSourceDocument({
    required this.source,
    required this.markdown,
    required this.blocks,
  });

  /// Original source, preserved exactly at the Dart string level.
  final String source;

  /// Parsed Markdown representation of [source].
  final Markdown markdown;

  /// Source blocks in document order.
  final List<MarkdownSourceBlock> blocks;

  /// Applies cumulative block replacements while preserving untouched source.
  ///
  /// Line separators and other gaps outside block ranges remain exactly as they
  /// appeared in [source], including CRLF sequences.
  String applyReplacements(Map<MarkdownBlockId, String> replacements) {
    if (replacements.isEmpty) return source;
    final knownIds = blocks.map((block) => block.id).toSet();
    final unknownIds = replacements.keys.where((id) => !knownIds.contains(id));
    if (unknownIds.isNotEmpty) {
      throw ArgumentError.value(
        unknownIds.first,
        'replacements',
        'Unknown Markdown block ID',
      );
    }

    final buffer = StringBuffer();
    var cursor = 0;
    for (final block in blocks) {
      buffer.write(source.substring(cursor, block.start));
      buffer.write(replacements[block.id] ?? block.source);
      cursor = block.end;
    }
    buffer.write(source.substring(cursor));
    return buffer.toString();
  }
}

/// Parses Markdown while retaining the exact source range of each AST block.
final class MarkdownSourceParser {
  /// Creates a source-preserving parser.
  const MarkdownSourceParser();

  /// Parses [source] using the package's shared Markdown block parser.
  MarkdownSourceDocument parse(String source) {
    final lines = LineSplitter.split(source).toList(growable: false);
    if (lines.isEmpty) {
      return const MarkdownSourceDocument(
        source: '',
        markdown: Markdown.empty(),
        blocks: <MarkdownSourceBlock>[],
      );
    }

    final lineRanges = _sourceLineRanges(source, lines);
    final sourceBlocks = <MarkdownSourceBlock>[];
    final result = _parseMarkdownLines(
      length: lines.length,
      lineAt: (index) => lines[index],
      onBlockParsed: (block, startLine, endLine) {
        final start = lineRanges[startLine].start;
        final end = lineRanges[endLine - 1].end;
        sourceBlocks.add(
          MarkdownSourceBlock(
            id: MarkdownBlockId(start, end),
            start: start,
            end: end,
            source: source.substring(start, end),
            block: block,
          ),
        );
      },
    );
    final markdown = Markdown(
      markdown: source,
      blocks: List<MD$Block>.unmodifiable(result.blocks),
    );
    return MarkdownSourceDocument(
      source: source,
      markdown: markdown,
      blocks: List<MarkdownSourceBlock>.unmodifiable(sourceBlocks),
    );
  }
}

List<({int start, int end})> _sourceLineRanges(
  String source,
  List<String> lines,
) {
  final ranges = <({int start, int end})>[];
  var cursor = 0;
  for (final line in lines) {
    final start = cursor;
    final end = start + line.length;
    ranges.add((start: start, end: end));
    cursor = end;
    if (cursor >= source.length) continue;
    if (source.codeUnitAt(cursor) == 0x0D &&
        cursor + 1 < source.length &&
        source.codeUnitAt(cursor + 1) == 0x0A) {
      cursor += 2;
    } else {
      cursor++;
    }
  }
  return ranges;
}
