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
