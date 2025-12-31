// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_md/flutter_md.dart';

void main() => runZonedGuarded<void>(
      () => runApp(ThemeModel(
          notifier: ValueNotifier<ThemeMode>(ThemeMode.dark),
          child: const App())),
      (e, s) => print(e),
    );

/// {@template app}
/// App widget.
/// {@endtemplate}
class App extends StatelessWidget {
  /// {@macro app}
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Markdown',
        themeMode: ThemeModel.of(context).value,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: const HomeScreen(),
        builder: (context, child) => MarkdownTheme(
          data: MarkdownThemeData.mergeTheme(
            Theme.of(context),
            // Exclude images from the markdown rendering,
            // so they are not rendered in the output.
            // Because image spans are not supported yet.
            spanFilter: (span) => !span.style.contains(MD$Style.image),
            onLinkTap: (title, url) {
              ScaffoldMessenger.maybeOf(context)
                ?..clearSnackBars()
                ..showSnackBar(
                  SnackBar(
                    content: Text('Link "$title" tapped: $url'),
                    duration: const Duration(seconds: 2),
                  ),
                );
            },
          ),
          child: child!,
        ),
      );
}

/// {@template theme_model}
/// A widget that provides the [ThemeMode] to its descendants.
/// {@endtemplate}
class ThemeModel extends InheritedNotifier<ValueNotifier<ThemeMode>> {
  /// {@macro theme_model}
  const ThemeModel({super.key, super.notifier, required super.child});

  /// The state from the closest instance of this class
  /// that encloses the given context, if any.
  /// e.g. `Theme.maybeOf(context)`.
  static ValueNotifier<ThemeMode>? maybeOf(BuildContext context,
          {bool listen = true}) =>
      listen
          ? context.dependOnInheritedWidgetOfExactType<ThemeModel>()?.notifier
          : context.getInheritedWidgetOfExactType<ThemeModel>()?.notifier;

  static Never _notFoundInheritedWidgetOfExactType() => throw ArgumentError(
        'Out of scope, not found inherited widget '
            'a ThemeModel of the exact type',
        'out_of_scope',
      );

  /// The state from the closest instance of this class
  /// that encloses the given context.
  /// e.g. `Theme.of(context)`
  static ValueNotifier<ThemeMode> of(BuildContext context,
          {bool listen = true}) =>
      maybeOf(context, listen: listen) ?? _notFoundInheritedWidgetOfExactType();

  @override
  bool updateShouldNotify(
      covariant InheritedNotifier<ValueNotifier<ThemeMode>> oldWidget) {
    return !identical(notifier, oldWidget.notifier);
  }
}

/// {@template home_screen}
/// HomeScreen widget.
/// {@endtemplate}
class HomeScreen extends StatefulWidget {
  /// {@macro home_screen}
  const HomeScreen({
    super.key, // ignore: unused_element
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// State for widget HomeScreen.
class _HomeScreenState extends State<HomeScreen> {
  final MultiChildLayoutDelegate _layoutDelegate = _HomeScreenLayoutDelegate();
  final TextEditingController _inputController =
      TextEditingController(text: _markdownExample);
  final ValueNotifier<Markdown> _outputController =
      ValueNotifier<Markdown>(const Markdown.empty());

  @override
  void initState() {
    super.initState();
    final initialMarkdown = Markdown.fromString(_inputController.text);
    _outputController.value = initialMarkdown;
    _inputController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    super.dispose();
    _inputController.dispose();
    _outputController.dispose();
  }

  void _onInputChanged() {
    // Handle input changes
    final text = _inputController.text;
    if (text.isEmpty && _outputController.value.isNotEmpty) {
      _outputController.value = const Markdown.empty();
    } else if (text == _outputController.value.markdown) {
      return; // No change, no need to update
    } else {
      final markdown = Markdown.fromString(text);
      _outputController.value = markdown;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            centerTitle: true,
            title: const Text('Markdown'),
            actions: <Widget>[
              // Navigate to streaming demo
              IconButton(
                icon: const Icon(Icons.stream),
                tooltip: 'Streaming Demo',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const StreamingDemoScreen(),
                  ),
                ),
              ),
              // theme switch widget
              Switch.adaptive(
                  value: ThemeModel.of(context).value == ThemeMode.dark,
                  onChanged: (value) {
                    ThemeModel.of(context).value =
                        value ? ThemeMode.dark : ThemeMode.light;
                  }),
            ]),
        body: SafeArea(
          child: CustomMultiChildLayout(
            delegate: _layoutDelegate,
            children: <Widget>[
              LayoutId(
                id: 0,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Positioned.fill(
                          child: TextField(
                            controller: _inputController,
                            expands: true,
                            maxLines: null,
                            minLines: null,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: '____________________________________\n'
                                  '______________________________\n'
                                  '__________________________\n'
                                  '______________________________\n'
                                  '____________________________________\n'
                                  '________________________\n'
                                  '________________________________________\n'
                                  '______________________________\n'
                                  '________________________\n'
                                  '__________________________________________\n'
                                  '______________________________\n',
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                IconButton.filledTonal(
                                  icon: const Icon(
                                    Icons.refresh,
                                  ),
                                  onPressed: () =>
                                      _inputController.text = _markdownExample,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              LayoutId(
                id: 1,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Card(
                    child: SingleChildScrollView(
                      primary: false,
                      padding: const EdgeInsets.all(8.0),
                      child: ValueListenableBuilder(
                        valueListenable: _outputController,
                        builder: (context, value, child) => MarkdownWidget(
                          markdown: value,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _HomeScreenLayoutDelegate extends MultiChildLayoutDelegate {
  _HomeScreenLayoutDelegate();

  @override
  void performLayout(Size size) {
    if (size.width >= size.height) {
      final width = size.width / 2;
      final constraints =
          BoxConstraints.tightFor(width: width, height: size.height);
      layoutChild(0, constraints);
      layoutChild(1, constraints);
      positionChild(0, Offset.zero);
      positionChild(1, Offset(width, 0));
    } else {
      final height = size.height / 2;
      final constraints =
          BoxConstraints.tightFor(width: size.width, height: height);
      layoutChild(0, constraints);
      layoutChild(1, constraints);
      positionChild(0, Offset.zero);
      positionChild(1, Offset(0, height));
    }
  }

  @override
  bool shouldRelayout(covariant _HomeScreenLayoutDelegate oldDelegate) => false;
}

const String _markdownExample = r'''
# Markdown syntax guide

## Headers

# This is a Heading h1
## This is a Heading h2
### This is a Heading h3
#### This is a Heading h4
##### This is a Heading h5
###### This is a Heading h6

---

## Emphasis

*This text will be italic*
_This will also be italic_

**This text will be bold**

__This will be underline__

`This is inline code`

~~This text will be strikethrough~~

==This text will be highlighted==

_`You` **can** __combine__ ~~them~~_

---

## Paragraphs

  **Lorem ipsum** dolor sit amet, consectetur adipiscing elit.
Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
Ut enim ad minim veniam, quis ~~nostrud exercitation~~ ullamco laboris nisi ut aliquip ex ea commodo consequat.
Duis aute irure dolor in _reprehenderit in voluptate velit esse_ cillum dolore eu fugiat nulla pariatur.
**Excepteur sint occaecat cupidatat non proident**, sunt in culpa qui __officia deserunt mollit__ anim id `est laborum`.

---

## Lists

### Unordered

* Item 1
* Item 2
* Item 2a
* Item 2b
    * Item 3a
    * Item 3b

### Ordered

1. Item **1**
2. Item **2**
3. Item **3**
    1. Item **3a** with [link](https://example.com)
    2. Item **3b**

---

## Links

You may be using [Markdown Live Preview](https://markdownlivepreview.com/).

---

## Blockquotes

> Markdown is a lightweight markup language with plain-text-formatting syntax, created in 2004 by John Gruber with Aaron Swartz.
>
> Markdown is often used to format readme files, for writing messages in online discussion forums, and to create rich text using a plain text editor.

---

## Tables

| Left columns  | Right columns |
| ------------- |:-------------:|
| left foo      | right foo     |
| left bar      | right bar     |
| left baz      | right baz     |

---

## Blocks of code

```
let message = 'Hello world';
alert(message);
```

---

## Inline code

This example is using `package:flutter_md/flutter_md.dart`.

---

## Special symbols

> "Quotes" and 'single quotes' with 👉 <, >, &, ©, ®, ™, €, £, ¥, •, …, ±, §, ¶, †, ‡, ‰, µ, °

''';

// ============================================================================
// Streaming Demo Screen
// ============================================================================

/// {@template streaming_demo_screen}
/// Demonstrates StreamingMarkdownDecoder with simulated LLM output.
/// {@endtemplate}
class StreamingDemoScreen extends StatefulWidget {
  /// {@macro streaming_demo_screen}
  const StreamingDemoScreen({super.key});

  @override
  State<StreamingDemoScreen> createState() => _StreamingDemoScreenState();
}

class _StreamingDemoScreenState extends State<StreamingDemoScreen> {
  final StreamingMarkdownDecoder _decoder = StreamingMarkdownDecoder();
  final ValueNotifier<Markdown> _outputController =
      ValueNotifier<Markdown>(const Markdown.empty());

  Timer? _streamTimer;
  int _charIndex = 0;
  bool _isStreaming = false;
  bool _animationEnabled = true;

  // Animation configuration
  MarkdownAnimationConfig get _animationConfig => MarkdownAnimationConfig(
        enabled: _animationEnabled,
        fadeInDuration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

  // Sample markdown content to stream
  static const String _streamingContent = '''
# Markdown syntax guide

## Headers

# This is a Heading h1
## This is a Heading h2
### This is a Heading h3
#### This is a Heading h4
##### This is a Heading h5
###### This is a Heading h6

---

## Emphasis

*This text will be italic*
_This will also be italic_

**This text will be bold**

__This will be underline__

`This is inline code`

~~This text will be strikethrough~~

==This text will be highlighted==

_`You` **can** __combine__ ~~them~~_

---

## Paragraphs

  **Lorem ipsum** dolor sit amet, consectetur adipiscing elit.
Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
Ut enim ad minim veniam, quis ~~nostrud exercitation~~ ullamco laboris nisi ut aliquip ex ea commodo consequat.
Duis aute irure dolor in _reprehenderit in voluptate velit esse_ cillum dolore eu fugiat nulla pariatur.
**Excepteur sint occaecat cupidatat non proident**, sunt in culpa qui __officia deserunt mollit__ anim id `est laborum`.

---

## Lists

### Unordered

* Item 1
* Item 2
* Item 2a
* Item 2b
    * Item 3a
    * Item 3b

### Ordered

1. Item **1**
2. Item **2**
3. Item **3**
    1. Item **3a** with [link](https://example.com)
    2. Item **3b**

---

## Links

You may be using [Markdown Live Preview](https://markdownlivepreview.com/).

---

## Blockquotes

> Markdown is a lightweight markup language with plain-text-formatting syntax, created in 2004 by John Gruber with Aaron Swartz.
>
> Markdown is often used to format readme files, for writing messages in online discussion forums, and to create rich text using a plain text editor.

---

## Tables

| Left columns  | Right columns |
| ------------- |:-------------:|
| left foo      | right foo     |
| left bar      | right bar     |
| left baz      | right baz     |

---

## Blocks of code

```
let message = 'Hello world';
alert(message);
```

---

## Inline code

This example is using `package:flutter_md/flutter_md.dart`.

---

## Special symbols

> "Quotes" and 'single quotes' with 👉 <, >, &, ©, ®, ™, €, £, ¥, •, …, ±, §, ¶, †, ‡, ‰, µ, °

''';

  @override
  void dispose() {
    _streamTimer?.cancel();
    _outputController.dispose();
    super.dispose();
  }

  void _startStreaming() {
    if (_isStreaming) return;

    // Reset state
    _decoder.reset();
    _charIndex = 0;
    _outputController.value = const Markdown.empty();

    setState(() => _isStreaming = true);

    // Stream characters with varying chunk sizes
    _streamTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_charIndex >= _streamingContent.length) {
        timer.cancel();
        setState(() => _isStreaming = false);
        return;
      }

      // Simulate varying chunk sizes (1-5 characters)
      final chunkSize = (_charIndex % 5) + 1;
      final endIndex =
          (_charIndex + chunkSize).clamp(0, _streamingContent.length);
      final chunk = _streamingContent.substring(_charIndex, endIndex);

      _decoder.append(chunk);
      _outputController.value = _decoder.build();

      _charIndex = endIndex;
    });
  }

  void _stopStreaming() {
    _streamTimer?.cancel();
    setState(() => _isStreaming = false);
  }

  void _resetStreaming() {
    _stopStreaming();
    _decoder.reset();
    _charIndex = 0;
    _outputController.value = const Markdown.empty();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Streaming Demo'),
          actions: <Widget>[
            // Animation toggle button
            IconButton(
              icon: Icon(_animationEnabled
                  ? Icons.animation
                  : Icons.animation_outlined),
              tooltip:
                  _animationEnabled ? 'Disable Animation' : 'Enable Animation',
              onPressed: () {
                setState(() => _animationEnabled = !_animationEnabled);
              },
            ),
            // Play/Pause button
            IconButton(
              icon: Icon(_isStreaming ? Icons.pause : Icons.play_arrow),
              tooltip: _isStreaming ? 'Pause' : 'Start Streaming',
              onPressed: _isStreaming ? _stopStreaming : _startStreaming,
            ),
            // Reset button
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset',
              onPressed: _resetStreaming,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Progress indicator
              ValueListenableBuilder<Markdown>(
                valueListenable: _outputController,
                builder: (context, _, __) {
                  final progress = _streamingContent.isEmpty
                      ? 0.0
                      : _charIndex / _streamingContent.length;
                  return LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade300,
                  );
                },
              ),
              // Stats bar
              ValueListenableBuilder<Markdown>(
                valueListenable: _outputController,
                builder: (context, markdown, _) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatChip(
                        label: 'Chars',
                        value: '$_charIndex/${_streamingContent.length}',
                      ),
                      _StatChip(
                        label: 'Lines',
                        value: '${_decoder.lineCount}',
                      ),
                      _StatChip(
                        label: 'Blocks',
                        value: '${markdown.blocks.length}',
                      ),
                      _StatChip(
                        label: 'Closed',
                        value: '${markdown.closedBlockCount ?? //
                            markdown.blocks.length}',
                      ),
                    ],
                  ),
                ),
              ),
              // Markdown output
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(50),
                    child: ValueListenableBuilder<Markdown>(
                      valueListenable: _outputController,
                      builder: (context, markdown, _) => MarkdownWidget(
                        markdown: markdown,
                        animationConfig: _animationConfig,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// A small chip widget for displaying stats.
class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      );
}
