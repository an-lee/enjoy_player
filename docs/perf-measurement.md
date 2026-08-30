# Performance measurement guide

How this project proves performance-sensitive behavior in CI. The companion
[testing.md](testing.md) covers commands, layout, and the coverage gate; this
guide is about **what to measure and how** when a change touches a user-visible
hot path (playback, startup, scrolling, transcript rendering, sync, media
import — see [architecture.md § Main-isolate performance](architecture.md#main-isolate-performance-windows)).

## Philosophy: structural tests over wall-clock benchmarks

Wall-clock timings in CI are noisy: shared runners, cold caches, and OS
schedulers turn micro-regressions into coin flips. This repo therefore prefers
**structural, deterministic assertions** that proxy for performance:

- Count **stream emissions** instead of timing rebuilds.
- Count **method entries** with a barrier-controlled double instead of racing
  concurrent calls.
- Scroll a **10k-item list** and assert zero exceptions instead of measuring
  frame times.
- Pin **`==` / `hashCode`** so `.distinct()` chains keep deduping.

Reserve wall-clock measurement for local investigation (DevTools CPU profiler
on the UI thread — see the architecture doc) and for the occasional
microbenchmark that cannot be expressed structurally (template below).

## Pattern 1: Value equality regression

Every `.distinct()` / dedupe chain is only as good as the domain type's
`==` / `hashCode`. Pin them field-by-field so a new field can't silently break
deduplication.

Real example — [`test/features/discover/discover_dedupe_test.dart`](../test/features/discover/discover_dedupe_test.dart)
(`Discover domain value equality` group):

```dart
final a = FeedEntry(videoId: 'v1', channelId: 'c1', title: 'Title', /* … */);
final b = FeedEntry(videoId: 'v1', channelId: 'c1', title: 'Title', /* … */);
final renamed = /* same but title differs */;

expect(a, equals(b));
expect(a.hashCode, equals(b.hashCode));
expect(a, isNot(equals(renamed)));
```

Apply to: any domain model flowing through a `.distinct()` stream or a
set/map keyed dedupe (Freezed generates these; the test guards the contract).

## Pattern 2: Stream emission counting

Drift watch streams re-emit on **any** write to the table. The repository
layer dedupes semantically-identical lists; prove it by counting emissions,
not by timing UI updates.

Real example — same file, `DiscoverRepository watch dedupe` group:

```dart
final emissions = <List<DiscoverChannel>>[];
final sub = repo.watchSubscriptions().listen(emissions.add);

await Future<void>.delayed(const Duration(milliseconds: 50));
final baseline = emissions.length;

await db.youtubeChannelSubscriptionDao.touchLastFetched(channelId, /* … */);
await Future<void>.delayed(const Duration(milliseconds: 50));
expect(emissions.length, lessThanOrEqualTo(baseline + 2)); // no unbounded growth

// …and the companion test: a REAL field change must still re-emit
await db.youtubeChannelSubscriptionDao.updateDisplayName(channelId, 'TED Talks');
expect(emissions.length, greaterThan(baseline));
```

Rules of thumb:

- Collect into a list with `listen(emissions.add)`; assert on `length` and on
  the **last** emission's contents.
- Always pair "dedupes when nothing changed" with "still emits when something
  changed" — a dedupe that never emits is a bug, not a win.
- Use `NativeDatabase.memory()` for isolation and speed.

## Pattern 3: Completer-barrier test double (single-flight)

To prove concurrent callers share one in-flight operation, stall the
operation with a `Completer` and count entries/completions.

Real example — [`test/features/discover/discover_refresh_single_flight_test.dart`](../test/features/discover/discover_refresh_single_flight_test.dart):

```dart
class _TestDiscoverRepository extends DiscoverRepository {
  _TestDiscoverRepository(super.db);
  Completer<void> barrier = Completer<void>();
  int refreshCallCount = 0;
  int refreshCompleteCount = 0;

  @override
  Future<DiscoverRefreshResult> refreshFeeds({bool force = false}) async {
    refreshCallCount++;
    await barrier.future;          // stall until the test releases us
    refreshCompleteCount++;
    return const DiscoverRefreshResult(/* … */);
  }
}

final first = notifier.refresh();
await Future<void>.delayed(Duration.zero);   // let the first call enter
final second = notifier.refresh();           // while first is in-flight

expect(repo.refreshCallCount, 1);            // deduped to one entry
repo.barrier.complete();
expect(await first, same(await second));     // identical result object
expect(repo.refreshCompleteCount, 1);
```

Also assert the **next** call after completion starts normally (the guard must
reset) — see the second test in that file.

## Pattern 4: Large-list widget stress

For scroll performance, build the worst realistic list, fling it, and assert
the tree survives with the expected per-tile behavior.

Real example — [`test/features/transcript/transcript_blur_long_list_perf_test.dart`](../test/features/transcript/transcript_blur_long_list_perf_test.dart):

```dart
const lineCount = 10000;
final lines = List.generate(lineCount, (i) => TranscriptLine(/* … */));

await tester.pumpWidget(/* MaterialApp + ListView.builder of TranscriptLineTile */);
await tester.pumpAndSettle();

expect(firstVisibleBlurWidget.revealed, isFalse);          // structural check
await tester.fling(find.byType(ListView), const Offset(0, -4000), 8000);
await tester.pumpAndSettle();
expect(tester.takeException(), isNull);                    // no overflow/dispose
```

`tester.takeException()` is the load-bearing assertion: layout overflows,
disposed-listener errors, and unbounded-constraint crashes all surface here
deterministically.

## Per-layer guidance

| Layer | What to assert | Reference |
|-------|----------------|-----------|
| Drift DAO streams | emission counts after no-op vs real writes | Pattern 2 |
| Domain models | `==` / `hashCode` field coverage | Pattern 1 |
| Riverpod notifiers | single-flight entry/completion counts, guard reset | Pattern 3 |
| Widget lists | 10k-item build + fling + `takeException()` | Pattern 4 |
| Main isolate | keep heavy work off the UI thread; profile locally with DevTools | [architecture.md](architecture.md#main-isolate-performance-windows) |

## Microbenchmark template (local only)

When a structural proxy is impossible (e.g. parse throughput), use this
zero-dependency harness locally. Do **not** gate CI on its wall-clock numbers.

```dart
test('parse 5k-line SRT (informational)', () {
  final parser = SrtParser(); // lib/data/subtitle/subtitle_parser.dart
  final input = /* build worst-case input */;

  // Warmup (JIT / caches).
  parser.parse(input);

  final sw = Stopwatch()..start();
  const runs = 20;
  for (var i = 0; i < runs; i++) {
    parser.parse(input);
  }
  sw.stop();

  // Assert a loose ceiling only (e.g. 10x the observed median) so the test
  // fails on order-of-magnitude regressions, not runner noise.
  final medianMs = sw.elapsedMilliseconds / runs;
  // ignore: avoid_print
  print('median: ${medianMs.toStringAsFixed(2)} ms/run');
  expect(medianMs, lessThan(500));
});
```

Keep the assertion **loose** (order-of-magnitude) and the input
**deterministic** (generated, not fixture-clock dependent).

## CI recommendations

- Structural tests (Patterns 1-4) run in the normal `flutter test` suite and
  count toward the coverage gate — see [testing.md](testing.md).
- A dedicated `test/perf/` directory and a benchmark smoke job are deferred
  future work; until then, keep perf tests in their feature's test folder next
  to the behavior tests.
- PRs touching a hot path must name the structural test (or manual DevTools
  evidence) that covers it — this is a constitution gate, not a convention.

## References

- [`test/features/discover/discover_dedupe_test.dart`](../test/features/discover/discover_dedupe_test.dart) — value equality + stream dedupe
- [`test/features/discover/discover_refresh_single_flight_test.dart`](../test/features/discover/discover_refresh_single_flight_test.dart) — single-flight barrier double
- [`test/features/transcript/transcript_blur_long_list_perf_test.dart`](../test/features/transcript/transcript_blur_long_list_perf_test.dart) — 10k-line scroll stress
- [`test/features/transcript/transcript_lines_provider_dedupe_test.dart`](../test/features/transcript/transcript_lines_provider_dedupe_test.dart), [`test/features/transcript/transcript_tracks_dedupe_test.dart`](../test/features/transcript/transcript_tracks_dedupe_test.dart), [`test/data/db/recording_dao_dedupe_test.dart`](../test/data/db/recording_dao_dedupe_test.dart) — more emission-counting coverage
- [`test/features/player/presentation/root_shell_overlay_scope_test.dart`](../test/features/player/presentation/root_shell_overlay_scope_test.dart), [`test/features/player/presentation/widgets/player_surface_overlay_churn_test.dart`](../test/features/player/presentation/widgets/player_surface_overlay_churn_test.dart), [`test/features/player/presentation/widgets/youtube_video_stage_scope_test.dart`](../test/features/player/presentation/widgets/youtube_video_stage_scope_test.dart) — widget-instance identity as a rebuild counter (overlay open/close, registry churn, buffering flips)
- [`test/features/player/presentation/widgets/transport/transport_progress_strip_perf_test.dart`](../test/features/player/presentation/widgets/transport/transport_progress_strip_perf_test.dart) — rebuilds-per-bucket cadence + paint-object allocation counter
- [testing.md](testing.md) — commands, layout, coverage gate
- [architecture.md § Main-isolate performance](architecture.md#main-isolate-performance-windows) — profiling guidance
