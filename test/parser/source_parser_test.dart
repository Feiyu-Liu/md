import 'package:flutter_md/flutter_md.dart';
import 'package:flutter_test/flutter_test.dart';

void main() => group('MarkdownSourceParser', () {
      const parser = MarkdownSourceParser();

      test('preserves exact ranges and CRLF gaps', () {
        const source = '# Title\r\n\r\nParagraph  \r\nnext';

        final document = parser.parse(source);

        expect(document.source, source);
        expect(document.markdown.markdown, source);
        expect(document.blocks, hasLength(3));
        expect(document.blocks[0].source, '# Title');
        expect(document.blocks[1].source, '');
        expect(document.blocks[2].source, 'Paragraph  \r\nnext');
        expect(
          document.blocks.map((block) => block.id.value),
          <String>['b:0:7', 'b:9:9', 'b:11:28'],
        );

        final replaced = document.applyReplacements(<MarkdownBlockId, String>{
          document.blocks.first.id: '# New title',
        });
        expect(replaced, '# New title\r\n\r\nParagraph  \r\nnext');
      });

      test('keeps fenced code as one exact source block', () {
        const source = 'before\n```dart\n  print("x");  \n```\nafter';

        final document = parser.parse(source);

        expect(document.blocks, hasLength(3));
        expect(document.blocks[1].block, isA<MD$Code>());
        expect(
          document.blocks[1].source,
          '```dart\n  print("x");  \n```',
        );
      });

      test('supports tilde fences and requires matching closing fences', () {
        const source = '~~~~dart\n'
            '```\n'
            'not prose\n'
            '~~~\n'
            '~~~~\n'
            'after';

        final document = parser.parse(source);

        expect(document.blocks, hasLength(2));
        expect(document.blocks.first.block, isA<MD$Code>());
        expect(
          (document.blocks.first.block as MD$Code).text,
          '```\nnot prose\n~~~',
        );
        expect(document.blocks.first.source, endsWith('~~~~'));
        expect(document.blocks.last.block, isA<MD$Paragraph>());
      });

      test('block IDs serialize and reject invalid values', () {
        const id = MarkdownBlockId(12, 34);

        expect(id.value, 'b:12:34');
        expect(id.toJson(), 'b:12:34');
        expect(MarkdownBlockId.parse(id.value), id);
        expect(MarkdownBlockId.fromJson(id.toJson()), id);
        expect(() => MarkdownBlockId.parse('12:34'), throwsFormatException);
        expect(() => MarkdownBlockId.parse('b:34:12'), throwsFormatException);
      });

      test('rejects replacements for IDs outside the original document', () {
        final document = parser.parse('text');

        expect(
          () => document.applyReplacements(
            <MarkdownBlockId, String>{
              const MarkdownBlockId(99, 100): 'x',
            },
          ),
          throwsArgumentError,
        );
      });
    });
