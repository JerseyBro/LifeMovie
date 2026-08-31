@Timeout(Duration(minutes: 5))
// ignore_for_file: avoid_print
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_domain/memory_domain.dart';
import 'package:memory_engine/memory_engine.dart';

void main() {
  test(
    'Sprint 0.8 synthetic performance baseline uses warm-up and median',
    () async {
      final results = <Map<String, Object?>>[];
      for (final size in [1000, 10000, 50000]) {
        await _runOnce(size);
        final runs = <Map<String, Object?>>[];
        for (var i = 0; i < 3; i += 1) {
          runs.add(await _runOnce(size));
        }
        results.add(_medianResult(size, runs));
      }
      for (final result in results) {
        print('PERF_BASELINE_V08 ${jsonEncode(result)}');
      }
    },
  );

  test('Sprint 0.8.1 correctness smoke 60K/75K without silent cap', () async {
    for (final size in [60000, 75000]) {
      final result = await _runOnce(size);
      print('PERF_SMOKE_V081 ${jsonEncode({'dataset_size': size, ...result})}');
      expect(result['candidate_count'] as int, greaterThan(0));
      expect(result['time_to_top_10_ms'] as int, lessThan(2000),
          reason: '60K/75K should not explode with new clustering');
    }
  });
}

Future<Map<String, Object?>> _runOnce(int size) async {
  final assets = _syntheticAssets(size);
  final repository = MockMediaRepository(assets);
  final index = PersistentMediaIndex.fromExecutor(NativeDatabase.memory());
  final rules = const <MemoryRule>[
    DateClusterRule(),
    SamePlaceRule(),
    YearRecapRule(),
    SamePlaceAcrossYearsRule(),
    FirstMemoryRule(),
    TravelStoryRule(),
    PersonTimelineRule(),
    AnnualTogetherRule(),
    LongTermEvolutionRule(),
  ];
  final ranker = const WeightedMemoryRanker();
  final deduplicator = const MemoryCandidateDeduplicator();
  final diversity = const FeedDiversityController();
  final memoryBefore = ProcessInfo.currentRss;

  final reconciliation = await _measure(
    () => index.reconcile(repository, batchSize: 500),
  );
  final dateQuery = await _measure(
    () => index.byDateRange(
      DateTimeRange(DateTime(2026, 8, 1), DateTime(2026, 8, 20)),
      limit: size,
    ),
  );
  final placeQuery = await _measure(
    () => index.byCoarsePlace(const GeoPoint(22.5, 114.0), limit: size),
  );
  final indexedAssets = size > 50000
      ? await index.allAssetsPaged(batchSize: 10000)
      : await index.allAssets(limit: size);
  final context = MemoryContext(assets: indexedAssets);

  final ruleTimes = <String, int>{};
  final candidates = <MemoryCandidate>[];
  for (final rule in rules) {
    final elapsed = await _measure(() async {
      candidates.addAll(await rule.discover(context));
    });
    ruleTimes[rule.runtimeType.toString()] = elapsed.inMilliseconds;
  }
  final ranking = await _measure(() => ranker.rank(candidates, context));
  final ranked = ranker.rank(candidates, context);
  final dedup = await _measure(() => deduplicator.deduplicate(ranked));
  final deduped = deduplicator.deduplicate(ranked);
  final diversify = await _measure(() => diversity.diversify(deduped));
  final firstCandidate = await _measure(() async {
    final firstContext = MemoryContext(
      assets: indexedAssets.take(1000).toList(),
    );
    for (final rule in rules.take(6)) {
      final discovered = await rule.discover(firstContext);
      if (discovered.isNotEmpty) break;
    }
  });
  final top10 = await _measure(() async {
    final discovered = await MemoryEngine(rules: rules).discover(context);
    final ranked = ranker.rank(discovered, context);
    final deduped = deduplicator.deduplicate(ranked);
    diversity.diversify(deduped, limit: 10);
  });
  final memoryAfter = ProcessInfo.currentRss;

  await index.close();
  return {
    'reconciliation_ms': reconciliation.inMilliseconds,
    'date_query_ms': dateQuery.inMilliseconds,
    'place_query_ms': placeQuery.inMilliseconds,
    'rule_runtime_ms': ruleTimes,
    'all_rule_runtime_ms': ruleTimes.values.fold<int>(0, (a, b) => a + b),
    'ranking_ms': ranking.inMilliseconds,
    'dedup_ms': dedup.inMilliseconds,
    'diversity_ms': diversify.inMilliseconds,
    'time_to_first_candidate_ms': firstCandidate.inMilliseconds,
    'time_to_top_10_ms': top10.inMilliseconds,
    'candidate_count': candidates.length,
    'ranked_count': ranked.length,
    'feed_count': diversity.diversify(deduped, limit: 10).length,
    'approx_rss_delta_mb': ((memoryAfter - memoryBefore) / (1024 * 1024))
        .round(),
  };
}

Map<String, Object?> _medianResult(int size, List<Map<String, Object?>> runs) {
  int medianInt(String key) {
    final values = runs.map((run) => run[key]! as int).toList()..sort();
    return values[values.length ~/ 2];
  }

  Map<String, int> medianMap(String key) {
    final keys = <String>{};
    for (final run in runs) {
      keys.addAll((run[key]! as Map<String, int>).keys);
    }
    return {
      for (final item in keys)
        item:
            ((runs
                .map((run) => (run[key]! as Map<String, int>)[item] ?? 0)
                .toList()
              ..sort())[runs.length ~/ 2]),
    };
  }

  return {
    'environment': {
      'machine': Platform.localHostname,
      'os': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'dart': Platform.version.split(' ').first,
      'flutter_mode': 'flutter test',
      'dataset': 'synthetic metadata only',
      'database_state':
          'in-memory SQLite, warm-up discarded, 3 measured runs, median reported',
    },
    'dataset_size': size,
    'reconciliation_ms': medianInt('reconciliation_ms'),
    'date_query_ms': medianInt('date_query_ms'),
    'place_query_ms': medianInt('place_query_ms'),
    'rule_runtime_ms': medianMap('rule_runtime_ms'),
    'all_rule_runtime_ms': medianInt('all_rule_runtime_ms'),
    'ranking_ms': medianInt('ranking_ms'),
    'dedup_ms': medianInt('dedup_ms'),
    'diversity_ms': medianInt('diversity_ms'),
    'time_to_first_candidate_ms': medianInt('time_to_first_candidate_ms'),
    'time_to_top_10_ms': medianInt('time_to_top_10_ms'),
    'candidate_count': medianInt('candidate_count'),
    'ranked_count': medianInt('ranked_count'),
    'feed_count': medianInt('feed_count'),
    'approx_rss_delta_mb': medianInt('approx_rss_delta_mb'),
  };
}

Future<Duration> _measure(FutureOr<void> Function() run) async {
  final watch = Stopwatch()..start();
  await run();
  watch.stop();
  return watch.elapsed;
}

List<MediaAsset> _syntheticAssets(int count) => List.generate(count, (i) {
  final year = 2019 + (i % 8);
  final month = 1 + (i % 12);
  final day = 1 + (i % 24);
  final isVideo = i % 9 == 0;
  final place = i % 8;
  final travelPlace = i % 60 < 30 ? i % 5 : place;
  return MediaAsset(
    id: 'perf-$i',
    localIdentifier: 'perf-$i',
    type: isVideo ? MediaType.video : MediaType.image,
    creationDate: DateTime(year, month, day),
    modificationDate: DateTime(year, month, day, 12),
    duration: isVideo ? const Duration(seconds: 24) : null,
    width: 1600,
    height: 1200,
    location: GeoPoint(22.5 + travelPlace * .04, 114.0 + travelPlace * .04),
    isFavorite: i % 37 == 0,
    personIds: i % 13 == 0 ? const ['perf-person'] : const [],
  );
});
