# flutter_md - Flutter 的 Markdown 解析器与渲染器

[![Checkout](https://github.com/DoctorinaAI/md/actions/workflows/checkout.yml/badge.svg)](https://github.com/DoctorinaAI/md/actions/workflows/checkout.yml)

[![Pub Package](https://img.shields.io/pub/v/flutter_md.svg)](https://pub.dev/packages/flutter_md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=flat&logo=dart&logoColor=white)](https://dart.dev)

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white)](https://flutter.dev)

一款专为 Flutter 应用程序设计的高性能、轻量级 Markdown 解析器和渲染器。非常适合用于显示来自 ChatGPT、Gemini 和其他 LLM 等 AI 助手的格式化文本。

## 🌟 功能特性

- **🚀 高性能**：优化的解析过程，内存占用极低

- **⚡ 流式支持**：用于实时 LLM 输出的增量解析（[文档](doc/streaming_markdown_decoder.md)）

- **🎨 完全可定制**：基于主题的样式设计，对外观拥有完全控制权

- **📱 Flutter 原生**：从头专为 Flutter 构建，使用自定义渲染对象

- **🔗 交互元素**：可点击链接，支持自定义点击处理程序

- **🌐 跨平台**：适用于所有 Flutter 支持的平台

- **📝 丰富的语法支持**：全面的 Markdown 语法覆盖

- **🎯 AI 优化**：专为 AI 生成的内容显示而设计

- **🔧 可扩展性**：易于通过自定义块（block）和跨度（span）渲染器进行扩展

## 📋 支持的 Markdown 语法

### 文本格式化

- **粗体**：`**text**` 或 `__text__`

- _斜体_：`*text*` 或 `_text_`

- ~~删除线~~：`~~text~~`

- `行内代码`：`` `code` ``

- ==高亮==：`==text==`

- ||剧透||：`||text||`

### 标题

```markdown

# H1 标题

## H2 标题

### H3 标题

#### H4 标题

##### H5 标题

###### H6 标题

```

### 列表

```markdown

- 无序列表项

- 另一项

- 嵌套项

- 深层嵌套项

1. 有序列表项

2. 另一个数字项

1. 嵌套数字项

2. 另一个嵌套项

```

### 引用块

```markdown

> 这是一个引用块

> 它可以跨越多行

>

> 并且可以有多个段落

```

### 代码块

````markdown

```dart

void main() {

print('Hello, Markdown!');

}

```

````

### 表格

```markdown

| 表头 1 | 表头 2 | 表头 3 |

| -------- | -------- | -------- |

| 单元格 1 | 单元格 2 | 单元格 3 |

| **粗体** | _斜体_ | `代码` |

```

### 链接和图片

```markdown

[链接文本](https://example.com)

![图片替代文本](https://example.com/image.png)

```

图片目前不会显示！

### 水平分割线

```markdown

---

```

## 🚀 快速开始

### 安装

将以下内容添加到你的 `pubspec.yaml` 文件中：

```yaml

dependencies:

flutter_md: ^x.x.x # 替换为最新版本

```

然后运行：

```bash

flutter pub get

```

## 🎨 定制化

### 主题配置

```dart

MarkdownTheme(

data: MarkdownThemeData(

textStyle: TextStyle(fontSize: 16.0, color: Colors.black87),

h1Style: TextStyle(

fontSize: 24.0,

fontWeight: FontWeight.bold,

color: Colors.blue,

),

h2Style: TextStyle(

fontSize: 22.0,

fontWeight: FontWeight.bold,

color: Colors.blueGrey,

),

quoteStyle: TextStyle(

fontSize: 14.0,

fontStyle: FontStyle.italic,

color: Colors.grey[600],

),

// 处理链接点击

onLinkTap: (title, url) {

print('点击链接: $title -> $url');

// 启动 URL 或导航

},

// 过滤块（例如，排除图片）

blockFilter: (block) => block is! MD$Image,

// 过滤跨度（例如，排除特定样式）

spanFilter: (span) => !span.style.contains(MD$Style.spoiler),

),

child: MarkdownWidget(

markdown: yourMarkdown,

),

)

```

或者，你可以使用 `MarkdownThemeData.mergeTheme(Theme.of(context))` 工厂方法来创建一个继承自应用程序主题的主题。

这种方法让你轻松支持浅色和深色主题，并保持 Markdown 样式与应用程序其余部分的一致性。

### 自定义块绘制器

对于高级定制，你可以提供自定义块绘制器：

```dart

MarkdownThemeData(

builder: (block, theme) {

if (block is MD$Code && block.language == 'dart') {

// 为 Dart 代码块返回自定义绘制器

return CustomDartCodePainter(block: block, theme: theme);

}

return null; // 使用默认绘制器

},

)

```

### 性能优化

对于大型 Markdown 文档或频繁变化的内容：

```dart

class MyWidget extends StatefulWidget {

@override

_MyWidgetState createState() => _MyWidgetState();

}

class _MyWidgetState extends State<MyWidget> {

late final Markdown _markdown;

@override

void initState() {

super.initState();

// 在初始化期间解析一次 Markdown

_markdown = Markdown.fromString(yourMarkdownString);

}

@override

Widget build(BuildContext context) {

return MarkdownWidget(markdown: _markdown);

}

}

```

## 📊 性能

- **解析**：典型 AI 响应约 300 微秒，比 `markdown` 包快 15 倍

- **渲染**：聊天类界面 120 FPS 流畅滚动

- **内存**：通过高效的跨度过滤实现最小的内存占用

## 🔧 高级功能

### 自定义样式

```dart

// 访问单个样式组件

final span = MD$Span(

text: '自定义文本',

style: MD$Style.bold | MD$Style.italic, // 组合样式

);

// 检查特定样式

if (span.style.contains(MD$Style.link)) {

// 处理链接样式

}

```

### 块过滤

```dart

MarkdownThemeData(

blockFilter: (block) {

// 仅显示段落和标题

return block is MD$Paragraph || block is MD$Heading;

},

)

```

### 跨度过滤

```dart

MarkdownThemeData(

spanFilter: (span) {

// 排除图片和剧透

return !span.style.contains(MD$Style.image) &&

!span.style.contains(MD$Style.spoiler);

},

)

```

### 用于 LLM 输出的流式 Markdown

非常适合实时显示 AI 生成的内容：

```dart

final decoder = StreamingMarkdownDecoder();

// 从 LLM 流式传输

openai.chat.stream(messages: [...]).listen((chunk) {

final content = chunk.choices.first.delta.content;

if (content != null) {

final markdown = decoder.append(content);

setState(() => _displayedMarkdown = markdown);

}

});

// 为新会话重置

decoder.reset();

```

**性能优势：**

- 仅重新解析开放（未完成）的块

- 跳过已关闭的块以获得最佳性能

- 处理部分行和变化的块大小

**[📖 完整文档](doc/streaming_markdown_decoder.md)**

## 📱 平台支持

- ✅ Android

- ✅ iOS

- ✅ Web

- ✅ Windows

- ✅ macOS

- ✅ Linux

## 🤝 贡献

欢迎贡献！请随时提交 Pull Request。

对于重大更改，请先打开 Issue 讨论你想要更改的内容。

### 开发环境设置

```bash

git clone https://github.com/DoctorinaAI/md.git md

cd md

flutter pub get

flutter test

```

### 运行示例

```bash

cd example

flutter run

```

## 📄 许可证

本项目基于 MIT 许可证授权 - 详见 [LICENSE](LICENSE) 文件。

## 🔗 链接

- [文档](https://pub.dev/documentation/flutter_md/latest/)

- [示例应用](https://github.com/DoctorinaAI/md/tree/main/example)

- [问题追踪](https://github.com/DoctorinaAI/md/issues)

- [Pub.dev 包](https://pub.dev/packages/flutter_md)

## 💡 为什么选择 md？

与其他依赖 HTML 渲染或 Web 视图的 Markdown 包不同，`flutter_md` 专为 Flutter 构建，使用自定义渲染对象。这提供了：

- **更好的性能**：无 HTML 解析或 Web 视图开销

- **原生体验**：完全集成于 Flutter 的渲染管线

- **定制化**：对样式和行为的完全控制

- **可靠性**：跨平台一致的渲染

- **体积小**：最小的包体积，无外部依赖

非常适合聊天应用程序、文档查看器、笔记应用，以及任何需要显示来自 AI 助手或用户输入的丰富格式化文本的 Flutter 应用程序。