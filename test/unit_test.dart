import 'package:flutter_test/flutter_test.dart';

import 'parser/parser_test.dart' as parser_test;
import 'render/code_painter_test.dart' as code_painter_test;
import 'render/table_painter_test.dart' as table_painter_test;
import 'theme/markdown_theme_test.dart' as markdown_theme_test;

void main() => group('Unit', () {
      parser_test.main();
      code_painter_test.main();
      table_painter_test.main();
      markdown_theme_test.main();
    });
