import 'package:flutter_md/flutter_md.dart';
import 'package:flutter_test/flutter_test.dart';

void main() => group('StreamingMarkdownDecoder', () {
      test('append returns Markdown', () {
        final decoder = StreamingMarkdownDecoder();
        final result = decoder.append('# Hello');
        expect(result, isA<Markdown>());
      });

      test('empty append returns empty blocks', () {
        final decoder = StreamingMarkdownDecoder();
        final result = decoder.append('');
        expect(result.blocks, isEmpty);
      });

      test('build returns current state', () {
        final decoder = StreamingMarkdownDecoder();
        decoder.append('# Hello\n');
        final result = decoder.build();
        expect(result, isA<Markdown>());
        expect(result.blocks, hasLength(1));
      });

      test('reset clears state', () {
        final decoder = StreamingMarkdownDecoder();
        decoder.append('# Hello\n');
        expect(decoder.lineCount, greaterThan(0));
        decoder.reset();
        expect(decoder.lineCount, equals(0));
        expect(decoder.blocks, isEmpty);
        expect(decoder.firstOpenIndex, equals(0));
      });

      group('Streaming simulation', () {
        test('character by character heading', () {
          final decoder = StreamingMarkdownDecoder();
          const input = '# Hello World\n';

          // Simulate character-by-character streaming
          for (var i = 0; i < input.length; i++) {
            decoder.append(input[i]);
          }

          final result = decoder.build();
          expect(result.blocks, hasLength(1));
          expect(result.blocks.first, isA<MD$Heading>());
          expect(
            (result.blocks.first as MD$Heading).text,
            equals('Hello World'),
          );
        });

        test('chunk by chunk code block', () {
          final decoder = StreamingMarkdownDecoder();

          // Simulate chunked streaming like LLM output
          decoder.append('```dart\n');
          expect(decoder.blocks, hasLength(1));
          expect(decoder.blocks.first, isA<MD$Code>());

          decoder.append('void main() {\n');
          decoder.append('  print("Hi");\n');
          decoder.append('}\n');

          // Code block still open (no closing ```)
          expect(decoder.firstOpenIndex, equals(0));

          decoder.append('```\n');

          // Now code block should be closed
          final result = decoder.build();
          expect(result.blocks, hasLength(1));
          expect(result.blocks.first, isA<MD$Code>());
          expect(
            (result.blocks.first as MD$Code).text,
            equals('void main() {\n  print("Hi");\n}'),
          );
        });

        test('mixed content streaming', () {
          final decoder = StreamingMarkdownDecoder();

          decoder.append('# Title\n');
          decoder.append('\n');
          decoder.append('Some paragraph text.\n');
          decoder.append('\n');
          decoder.append('> A quote\n');

          final result = decoder.build();
          expect(result.blocks, hasLength(5));
          expect(result.blocks[0], isA<MD$Heading>());
          expect(result.blocks[1], isA<MD$Spacer>());
          expect(result.blocks[2], isA<MD$Paragraph>());
          expect(result.blocks[3], isA<MD$Spacer>());
          expect(result.blocks[4], isA<MD$Quote>());
        });
      });

      group('Line state tracking', () {
        test('firstOpenIndex advances after closed blocks', () {
          final decoder = StreamingMarkdownDecoder();

          decoder.append('# Heading 1\n');
          decoder.append('# Heading 2\n');

          // After second heading, first heading should be closed
          expect(decoder.firstOpenIndex, greaterThan(0));
        });

        test('code block keeps lines open until closed', () {
          final decoder = StreamingMarkdownDecoder();

          decoder.append('# Heading\n');
          // Heading is closed when next line arrives
          decoder.append('```\n');
          final afterCodeStart = decoder.firstOpenIndex;

          decoder.append('code line 1\n');
          decoder.append('code line 2\n');

          // Code block not closed, firstOpenIndex should not advance
          expect(decoder.firstOpenIndex, equals(afterCodeStart));

          decoder.append('```\n');

          // Now closed
          expect(decoder.firstOpenIndex, greaterThan(afterCodeStart));
        });
      });

      group('Consistency with MarkdownDecoder', () {
        test('produces correct block types for heading', () {
          const input = '# Hello\n';

          final streaming = StreamingMarkdownDecoder();
          streaming.append(input);
          final result = streaming.build();

          expect(result.blocks.first, isA<MD$Heading>());
          expect((result.blocks.first as MD$Heading).text, equals('Hello'));
        });

        test('produces correct block types for paragraph', () {
          const input = 'Some paragraph text.\n';

          final streaming = StreamingMarkdownDecoder();
          streaming.append(input);
          final result = streaming.build();

          expect(result.blocks.first, isA<MD$Paragraph>());
        });

        test('produces correct block types for code', () {
          const input = '```dart\ncode\n```\n';

          final streaming = StreamingMarkdownDecoder();
          streaming.append(input);
          final result = streaming.build();

          expect(result.blocks.first, isA<MD$Code>());
          expect((result.blocks.first as MD$Code).language, equals('dart'));
        });

        test('incremental append produces valid blocks', () {
          const chunks = [
            '# Hello',
            ' World\n',
            '\n',
            'Para',
            'graph.\n',
          ];

          final decoder = StreamingMarkdownDecoder();
          for (final chunk in chunks) {
            decoder.append(chunk);
          }

          final result = decoder.build();

          // Should have Heading, Spacer, Paragraph
          expect(result.blocks.length, greaterThanOrEqualTo(2));
          expect(result.blocks[0], isA<MD$Heading>());
          expect(
            (result.blocks[0] as MD$Heading).text,
            equals('Hello World'),
          );
        });
      });

      group('Edge cases', () {
        test('partial line without newline', () {
          final decoder = StreamingMarkdownDecoder();
          decoder.append('# Hel');
          decoder.append('lo');

          // Still pending, no complete line yet
          final result = decoder.build();
          expect(result.blocks, hasLength(1));
          expect(result.blocks.first, isA<MD$Heading>());
          expect(
            (result.blocks.first as MD$Heading).text,
            equals('Hello'),
          );
        });

        test('multiple newlines in single chunk', () {
          final decoder = StreamingMarkdownDecoder();
          decoder.append('# A\n\n# B\n');

          final result = decoder.build();
          // # A, Spacer, # B, and possibly trailing spacer
          expect(result.blocks.length, greaterThanOrEqualTo(3));
          expect(result.blocks[0], isA<MD$Heading>());
          expect(result.blocks[1], isA<MD$Spacer>());
          expect(result.blocks[2], isA<MD$Heading>());
        });

        test('lineCount increases with content', () {
          final decoder = StreamingMarkdownDecoder();
          decoder.append('# Hello\n');

          // At least 1 line
          expect(decoder.lineCount, greaterThanOrEqualTo(1));
        });

        test('list streaming tracks closed item count', () {
          final decoder = StreamingMarkdownDecoder();

          decoder.append('- Item 1\n');
          decoder.append('- Item 2');
          final second = decoder.build().blocks.whereType<MD$List>().first;
          expect(second.closedItemCount, equals(1));
          expect(second.items.length, equals(2));
          expect(second.visibleItems.length, equals(1));

          decoder.append('\nParagraph');
          final third = decoder.build().blocks.whereType<MD$List>().first;
          expect(third.closedItemCount, equals(2));
          expect(third.visibleItems.length, equals(2));
        });

        test('list visibleItems keeps nested prefix stable', () {
          final decoder = StreamingMarkdownDecoder();
          decoder.append('- Parent\n');
          decoder.append('  - Child 1\n');
          decoder.append('  - Child 2\n');

          final list = decoder.build().blocks.first as MD$List;
          expect(list.closedItemCount, equals(2));
          expect(list.visibleItems, hasLength(1));
          expect(list.visibleItems.first.children, hasLength(1));
          expect(
            list.visibleItems.first.children.first.text,
            equals('Child 1'),
          );
        });

        test('list streaming', () {
          final decoder = StreamingMarkdownDecoder();
          decoder.append('- Item 1\n');
          decoder.append('- Item 2\n');
          decoder.append('\n'); // End list

          final result = decoder.build();
          expect(result.blocks.first, isA<MD$List>());
          expect(
            (result.blocks.first as MD$List).items.length,
            equals(2),
          );
        });

        test('table streaming', () {
          final decoder = StreamingMarkdownDecoder();
          decoder.append('| A | B |\n');
          decoder.append('|---|---|\n');
          decoder.append('| 1 | 2 |\n');
          decoder.append('| 3 | 4 |\n');
          decoder.append('End\n'); // End table with non-table line

          final result = decoder.build();
          // Find the table block
          final tableBlocks = result.blocks.whereType<MD$Table>().toList();
          expect(tableBlocks, isNotEmpty);

          final table = tableBlocks.first;
          expect(table.header.cells.length, equals(2));
        });
      });
    });
