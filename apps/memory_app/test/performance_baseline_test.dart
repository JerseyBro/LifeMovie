@Timeout(Duration(minutes: 3))
// ignore_for_file: avoid_print
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_domain/memory_domain.dart';
import 'package:memory_engine/memory_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('synthetic performance baseline for 1K, 10K and 50K assets', () async {
    final results = <Map<String, Object?>>[];
    for (final size in [1000, 10000, 50000]) {
      results.add(await _runBaseline(size));
    }
    for (final result in results) {
      print('PERF_BASELINE ${jsonEncode(result)}');
    }
  });
}

Future<Map<String, Object?>> _runBaseline(int size) async {
  final assets = _syntheticAssets(size);
  final repository = MockMediaRepository(assets);
  final index = PersistentMediaIndex.fromExecutor(NativeDatabase.memory());
  final engine = MemoryEngine(
    rules: const [DateClusterRule(), SamePlaceRule(), YearRecapRule()],
  );
  final ranker = const WeightedMemoryRanker();
  final memoryBefore = ProcessInfo.currentRss;

  final reconcileTime = await _measure(
    () => index.reconcile(repository, batchSize: 500),
  );
  final dateQueryTime = await _measure(
    () => index.byDateRange(
      DateTimeRange(DateTime(2026, 8, 1), DateTime(2026, 8, 20)),
      limit: size,
    ),
  );
  final placeQueryTime = await _measure(
    () => index.byCoarsePlace(const GeoPoint(22.5, 114.0), limit: size),
  );
  final indexedAssets = await index.allAssets(limit: size);
  final dateRuleTime = await _measure(
    () =>
        const DateClusterRule().discover(MemoryContext(assets: indexedAssets)),
  );
  final samePlaceRuleTime = await _measure(
    () => const SamePlaceRule().discover(MemoryContext(assets: indexedAssets)),
  );
  final context = MemoryContext(assets: indexedAssets);
  final candidates = await engine.discover(context);
  final rankingTime = await _measure(() => ranker.rank(candidates, context));
  final firstUsefulTime = await _measure(() async {
    final firstContext = MemoryContext(
      assets: indexedAssets.take(1000).toList(),
    );
    final firstCandidates = await engine.discover(firstContext);
    ranker.rank(firstCandidates, firstContext);
    return null;
  });
  final memoryAfter = ProcessInfo.currentRss;

  await index.close();
  return {
    'environment': {
      'os': Platform.operatingSystem,
      'dart': Platform.version.split(' ').first,
      'flutter_mode': 'flutter test',
      'database_state': 'in-memory cold',
    },
    'dataset_size': size,
    'reconciliation_ms': reconcileTime.inMilliseconds,
    'date_query_ms': dateQueryTime.inMilliseconds,
    'place_query_ms': placeQueryTime.inMilliseconds,
    'date_cluster_rule_ms': dateRuleTime.inMilliseconds,
    'same_place_rule_ms': samePlaceRuleTime.inMilliseconds,
    'ranking_ms': rankingTime.inMilliseconds,
    'time_to_first_useful_result_ms': firstUsefulTime.inMilliseconds,
    'candidate_count': candidates.length,
    'approx_rss_delta_mb': ((memoryAfter - memoryBefore) / (1024 * 1024))
        .round(),
  };
}

Future<Duration> _measure(FutureOr<Object?> Function() run) async {
  final watch = Stopwatch()..start();
  await run();
  watch.stop();
  return watch.elapsed;
}

List<MediaAsset> _syntheticAssets(int count) => List.generate(count, (i) {
  final year = 2023 + (i % 4);
  final month = 1 + (i % 12);
  final day = 1 + (i % 26);
  final isVideo = i % 9 == 0;
  final place = i % 4;
  return MediaAsset(
    id: 'perf-$i',
    localIdentifier: 'perf-$i',
    type: isVideo ? MediaType.video : MediaType.image,
    creationDate: DateTime(year, month, day),
    modificationDate: DateTime(year, month, day, 12),
    duration: isVideo ? const Duration(seconds: 24) : null,
    width: 1600,
    height: 1200,
    location: GeoPoint(22.5 + place * .04, 114.0 + place * .04),
    isFavorite: i % 37 == 0,
  );
});
