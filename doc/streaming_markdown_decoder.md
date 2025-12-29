# StreamingMarkdownDecoder - 流式 Markdown 解析器

## 概述

`StreamingMarkdownDecoder` 是专为 LLM 应用流式输出场景设计的增量 Markdown 解析器。与传统的批量解析器 `MarkdownDecoder` 不同，它维护状态并只重新解析尚未闭合的内容块，显著降低了流式场景下的性能开销。

## 背景与动机

### 问题场景

在 LLM（大语言模型）应用中，Markdown 内容通常以流式方式输出：
- 每秒可能有几十次小块文本（chunk）到达
- 每个 chunk 可能只包含几个字符，不一定包含完整的行
- 用户期望实时渲染，需要频繁调用解析器

### 传统方案的瓶颈

使用 `MarkdownDecoder.convert()` 处理流式输出时：

```dart
final buffer = StringBuffer();
Stream<String> llmOutput; // LLM 流式输出

await for (final chunk in llmOutput) {
  buffer.write(chunk);
  final markdown = markdownDecoder.convert(buffer.toString()); // ❌ 全量解析
  updateUI(markdown);
}
```

**性能问题：**
- 100 行 Markdown，追加 1 个字符 → 重新解析 100 行
- 已完成的代码块、表格等 → 每次都重新解析
- 随着内容增长，解析时间线性增长

## 核心设计

### 1. 行状态跟踪

每一行标记为 `open`（未闭合）或 `closed`（已闭合）：

```dart
enum LineState {
  open,   // 可能继续接收内容或所属 block 未闭合
  closed, // 所属 block 已闭合，不再变化
}

class ParsedLine {
  String text;
  LineState state;
}
```

### 2. Block 闭合判断

| Block 类型 | 闭合条件 | 示例 |
|-----------|---------|------|
| `Heading` | 单行，遇到换行即闭合 | `# Title\n` → closed |
| `Code` | 遇到结束 ` ``` ` | ` ```dart...``` ` → closed |
| `Quote` | 后续行不以 `>` 开头 | `> line1\n> line2\ntext` → closed at "text" |
| `List` | 后续行非列表项 | `- item\ntext` → closed at "text" |
| `Table` | 后续行不以 `\|` 开头 | `\| A \| B \|\ntext` → closed at "text" |
| `Paragraph` | 遇到空行或新 block | `text\n\n` → closed |
| `Spacer` | 后续有非空行 | `\n\ntext` → closed at "text" |

### 3. 增量解析策略

```dart
class StreamingMarkdownDecoder {
  final List<ParsedLine> _lines = [];
  final List<MD$Block> _blocks = [];
  int _firstOpenIndex = 0;  // 第一个 open 行的索引

  Markdown append(String chunk) {
    _processChunk(chunk);  // 1. 处理 chunk，拆分行
    _parse();              // 2. 从 _firstOpenIndex 开始解析
    return build();
  }
}
```

**关键优化点：**
1. `_firstOpenIndex` 跳过所有 closed 行
2. 只解析从 `_firstOpenIndex` 到末尾的内容
3. Closed blocks 不再重新生成

## 实现细节

### 1. Chunk 处理（_processChunk）

处理可能不含完整行的 chunk：

```dart
void _processChunk(String chunk) {
  // 确保有 pending line
  if (_lines.isEmpty || _lines.last.state == LineState.closed) {
    _lines.add(ParsedLine('', state: LineState.open));
  }

  final pendingIndex = _lines.length - 1;
  final combined = _lines[pendingIndex].text + chunk;

  // 使用 LineSplitter 正确处理换行符
  final split = LineSplitter.split(combined).toList(growable: false);

  if (split.length > 1) {
    // 有换行符，产生新行
    _lines[pendingIndex] = ParsedLine(split[0], state: LineState.open);
    for (var i = 1; i < split.length; i++) {
      _lines.add(ParsedLine(split[i], state: LineState.open));
    }

    // 如果 chunk 以换行符结尾，添加空 pending line
    if (combined.endsWith('\n') || combined.endsWith('\r')) {
      _lines.add(ParsedLine('', state: LineState.open));
    }
  } else {
    // 无换行符，更新 pending line
    _lines[pendingIndex] = ParsedLine(combined, state: LineState.open);
  }
}
```

### 2. 共享解析核心（_parseMarkdownLines）

提取了通用的解析逻辑，供两个解析器复用：

```dart
_ParseResult _parseMarkdownLines({
  required int length,
  required String Function(int index) lineAt,
  int startIndex = 0,
  List<MD$Block>? existingBlocks,
  OnBlockClosed? onBlockClosed,      // 闭合时的回调
  OnCodeBlockOpen? onCodeBlockOpen,  // 未闭合代码块的回调
});
```

**MarkdownDecoder 调用方式：**
```dart
final result = _parseMarkdownLines(
  length: lines.length,
  lineAt: (i) => lines[i],
);
```

**StreamingMarkdownDecoder 调用方式：**
```dart
final result = _parseMarkdownLines(
  length: _lines.length,
  lineAt: (i) => _lines[i].text,
  startIndex: _firstOpenIndex,  // 跳过 closed 行
  existingBlocks: _blocks,
  onBlockClosed: _closeLines,   // 更新行状态
  onCodeBlockOpen: (_, __) => false,  // 遇到未闭合代码块时停止
);
```

### 3. 行状态更新（_closeLines）

在 block 闭合时标记行状态：

```dart
void _closeLines(int start, int end) {
  for (var k = start; k < end && k < _lines.length; k++) {
    _lines[k].state = LineState.closed;
  }
  if (end <= _lines.length) {
    _firstOpenIndex = end;
  }
}
```

## 性能对比

| 场景 | MarkdownDecoder | StreamingMarkdownDecoder |
|-----|----------------|-------------------------|
| 100 行 MD，追加 1 token | 解析 100 行 | 解析 1-3 open 行 |
| 已闭合的 code block | 重新解析所有内容 | 跳过（不解析） |
| 内存占用 | 每次创建新对象 | 复用 closed blocks |
| 时间复杂度 | O(n) 每次 | O(m) m≪n |

### 性能提升示例

```dart
// 模拟 100 行已闭合内容 + 1 行新内容
final decoder = StreamingMarkdownDecoder();

// 前 100 行（已闭合）
for (var i = 0; i < 100; i++) {
  decoder.append('Line $i\n');
}

// 追加 1 个字符（触发增量解析）
decoder.append('x');  // ✅ 只解析最后一行

// 对比：传统方式
markdownDecoder.convert(fullText);  // ❌ 解析全部 100+ 行
```

## 使用指南

### 基本用法

```dart
final decoder = StreamingMarkdownDecoder();

// 流式追加
decoder.append('# Hel');       // Heading 进行中
decoder.append('lo\n');        // Heading 闭合
decoder.append('\n```dart\n'); // Spacer 闭合，Code 开始
decoder.append('void main()'); // Code 进行中
decoder.append('\n```\n');     // Code 闭合

// 获取结果
final markdown = decoder.build();
print(markdown.blocks.length); // 3: Heading, Spacer, Code
```

### 与 LLM SDK 集成

```dart
// OpenAI Stream 示例
final decoder = StreamingMarkdownDecoder();

openai.chat.stream(messages: [...]).listen((chunk) {
  final content = chunk.choices.first.delta.content;
  if (content != null) {
    final markdown = decoder.append(content);
    setState(() => _displayedMarkdown = markdown);
  }
});
```

### 重置状态

```dart
decoder.reset();  // 清空所有状态，用于新对话
```

## 代码结构

```
parser.dart
├── LineState, ParsedLine              # 行状态（共享）
├── _emptyPattern, _headerPattern...   # 正则（共享）
├── OnBlockClosed, OnCodeBlockOpen     # 回调类型
├── _ParseResult                       # 解析结果
├── _parseMarkdownLines()              # 核心解析函数（共享）
│   ├── 遍历行
│   ├── 识别 block 类型
│   ├── 判断闭合条件
│   └── 调用 onBlockClosed 回调
├── MarkdownDecoder                    # 批量解析器
│   └── convert() → 调用 _parseMarkdownLines
└── StreamingMarkdownDecoder           # 流式解析器
    ├── append() → _processChunk + _parse
    ├── _processChunk() → 处理 chunk 拆分
    ├── _parse() → 调用 _parseMarkdownLines
    └── _closeLines() → 更新行状态
```

### 代码复用统计

| 组件 | 重构前 | 重构后 | 复用率 |
|-----|-------|-------|--------|
| 正则表达式 | 2 × 定义 | 1 × 定义 | 50% |
| 解析循环 | 2 × ~200 行 | 1 × ~300 行 | ~67% |
| `StreamingMarkdownDecoder._parse()` | ~300 行 | ~30 行 | 90% |

## 测试覆盖

位置：`test/parser/streaming_parser_test.dart`

### 测试组（共 18 个测试）

1. **基础功能**
   - `append()` 返回 `Markdown` 对象
   - 空输入处理
   - `build()` 返回当前状态
   - `reset()` 清空状态

2. **流式模拟**
   - 逐字符输入 heading
   - 分块输入 code block
   - 混合内容流式输出

3. **行状态跟踪**
   - `firstOpenIndex` 随闭合递增
   - 未闭合 code block 保持 open 状态

4. **Block 类型正确性**
   - Heading、Paragraph、Code 等
   - 与 `MarkdownDecoder` 一致性

5. **边界情况**
   - 部分行（无换行符）
   - 单 chunk 多换行
   - List、Table 流式处理

### 运行测试

```bash
flutter test test/parser/streaming_parser_test.dart
```

## 演示应用

位置：`example/lib/main.dart`

### 启动方式

```bash
cd example
flutter run
```

### 功能

1. 点击 AppBar 的流式图标进入演示页面
2. 点击播放按钮开始模拟 LLM 流式输出
3. 实时观察：
   - **Chars**: 已输出字符数
   - **Lines**: 当前行数
   - **Blocks**: 已解析 block 数
   - **First Open**: 第一个 open 行索引（验证优化效果）

### 关键代码

```dart
class _StreamingDemoScreenState extends State<StreamingDemoScreen> {
  final StreamingMarkdownDecoder _decoder = StreamingMarkdownDecoder();

  void _startStreaming() {
    _decoder.reset();

    // 模拟 LLM：每 20ms 输出 1-5 个字符
    _streamTimer = Timer.periodic(Duration(milliseconds: 20), (timer) {
      final chunk = content.substring(start, end);
      _decoder.append(chunk);
      _outputController.value = _decoder.build();
    });
  }
}
```

## 最佳实践

### ✅ 推荐

1. **流式场景统一使用 `StreamingMarkdownDecoder`**
   ```dart
   final decoder = StreamingMarkdownDecoder();
   // 持续 append，避免重复创建
   ```

2. **批量场景使用 `MarkdownDecoder`**
   ```dart
   final markdown = markdownDecoder.convert(fullText);
   ```

3. **对话切换时重置状态**
   ```dart
   decoder.reset(); // 新对话开始
   ```

### ❌ 避免

1. **混用两种解析器**
   ```dart
   // ❌ 每次都创建新解析器
   for (final chunk in chunks) {
     final decoder = StreamingMarkdownDecoder();
     decoder.append(chunk);
   }
   ```

2. **在非流式场景使用流式解析器**
   ```dart
   // ❌ 已有完整文本，应直接用 MarkdownDecoder
   final decoder = StreamingMarkdownDecoder();
   decoder.append(fullText);
   ```

## 未来优化方向

1. **精确的 Block-Line 映射**
   - 当前使用 `_estimateBlockLines()` 估算
   - 可改为精确记录每个 block 对应的行范围

2. **Inline Span 缓存**
   - 对于 closed block，缓存 `_parseInlineSpans()` 结果
   - 避免重复解析内联样式

3. **增量渲染优化**
   - 只重绘 open blocks
   - Closed blocks 使用缓存的 render object

4. **支持回退**
   - 记录状态快照
   - 支持 LLM 输出回退（如用户中断）

## 参考

- 源码：`md/lib/src/parser.dart`
- 测试：`md/test/parser/streaming_parser_test.dart`
- 演示：`md/example/lib/main.dart`
- Issue: [flutter_streaming_markdown/issues](https://github.com/anthropics/claude-code/issues)

---

**创建时间：** 2025-12-30
**版本：** 1.0.0
