# Benchmarks

This directory contains performance benchmarks for `flutter_md`.

## Streaming Performance Benchmark

Compares `MarkdownDecoder` vs `StreamingMarkdownDecoder` for LLM streaming scenarios.

### Running the Benchmark

```bash
dart benchmark/streaming_performance_benchmark.dart
```

### What It Tests

The benchmark simulates LLM streaming output by:
1. Splitting markdown content into small chunks (5-15 characters)
2. Feeding chunks incrementally to both decoders
3. Measuring total time, average time per parse, and lines parsed

### Expected Results

`StreamingMarkdownDecoder` should show:
- **2-4x speedup** compared to `MarkdownDecoder`
- **Significantly fewer lines parsed** per update (2-6 vs. full document)
- **Greater performance gains** as content size increases

### Sample Output

```
Small Content (50 lines) (chunk size: 5 chars)
--------------------------------------------------------------------------------
Total chunks: 166

Results:
  MarkdownDecoder:
    Total time:        32ms
    Parse count:       166
    Avg per parse:     193µs
    Final blocks:      15

  StreamingMarkdownDecoder:
    Total time:        11ms
    Parse count:       166
    Avg per parse:     68µs
    Final blocks:      17
    Lines parsed:      938
    Avg lines/parse:   5.7

  Performance Gain:
    Speedup:           2.84x faster
    Time saved:        20ms
```

### Key Metrics

- **Total time**: Total time spent parsing all chunks
- **Parse count**: Number of times content was parsed
- **Avg per parse**: Average time per parse operation
- **Lines parsed**: Total lines processed (streaming decoder only)
- **Avg lines/parse**: Average lines parsed per operation (shows optimization effectiveness)

The `Avg lines/parse` metric demonstrates the core optimization: `StreamingMarkdownDecoder` only re-parses open lines instead of the entire document.

## Render Selection Benchmark

Measures 200 streaming updates over a 500-line document, both outside and
inside a `SelectionArea`:

```bash
flutter test benchmark/render_selection_benchmark_test.dart --reporter expanded
```

The no-selection result protects the renderer's zero-fragment fast path. The
selection-enabled result includes creation and registration of native
selectable fragments. Use these acceptance limits when changing selection:

- no-selection median must not regress by more than 5% from its baseline;
- selection-enabled overhead must not exceed 20% relative to the same run's
  no-selection median.

One paired Flutter 3.41.9 debug test run on July 25, 2026 produced:

```text
HEAD no-selection baseline: 2367.3 ms
Current no-selection median: 2444.4 ms
No-selection regression: 3.3%
Selection enabled median: 2680.2 ms
Selection overhead: 9.6%
```

Absolute timings vary by machine and build mode, so use the relative overhead
and a freshly measured local baseline for comparisons.
