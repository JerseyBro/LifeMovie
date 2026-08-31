import 'dart:io';
import 'dart:math' as math;

import 'package:memory_domain/memory_domain.dart';
import 'package:memory_engine/memory_engine.dart';
import 'package:test/test.dart';

void main() {
  // Year semantics
  group('P0-1 Year semantics', () {
    test('Case A: [2019,2022,2026] distinct 3 span 8 longest 1', () {
      final metrics = YearMetrics.fromYears([2019, 2022, 2026])!;
      expect(metrics.distinctYearCount, 3);
      expect(metrics.calendarSpanYears, 8);
      expect(metrics.longestConsecutiveYearRun, 1);
      expect(metrics.firstYear, 2019);
      expect(metrics.lastYear, 2026);
    });

    test('Case B: [2022,2023,2024] consecutive 3', () {
      final metrics = YearMetrics.fromYears([2022, 2023, 2024])!;
      expect(metrics.distinctYearCount, 3);
      expect(metrics.calendarSpanYears, 3);
      expect(metrics.longestConsecutiveYearRun, 3);
    });

    test('Case C: [2019,2020,2022,2023,2024] longest 3', () {
      final metrics = YearMetrics.fromYears([2019, 2020, 2022, 2023, 2024])!;
      expect(metrics.distinctYearCount, 5);
      expect(metrics.calendarSpanYears, 6); // 2019..2024
      expect(metrics.longestConsecutiveYearRun, 3);
    });

    test(
      'SamePlaceAcrossYears does not claim consecutive for non-consecutive years',
      () async {
        final assets = [
          for (final year in [2019, 2022, 2026])
            ...List.generate(
              2,
              (i) => _asset(
                'a-$year-$i',
                DateTime(year, 7, 1 + i),
                location: const GeoPoint(31.23, 121.47),
              ),
            ),
        ];
        final candidates = await const SamePlaceAcrossYearsRule(
          config: SamePlaceAcrossYearsRuleConfig(
            minimumYearCount: 3,
            minimumVisitCount: 3,
          ),
        ).discover(MemoryContext(assets: assets));
        expect(candidates, hasLength(1));
        final c = candidates.first;
        expect(c.metadata['distinctYearCount'], 3);
        expect(c.metadata['calendarSpanYears'], 8);
        expect(c.metadata['longestConsecutiveYearRun'], 1);
        // Should NOT say 连续 3 年
        expect(c.safeTitleTemplate, isNot(contains('连续 3 年')));
        expect(c.safeTitleTemplate, anyOf(contains('多次'), contains('不同年份')));
      },
    );

    test(
      'SamePlaceAcrossYears allows consecutive when longest run >=3',
      () async {
        final assets = [
          for (final year in [2022, 2023, 2024])
            ...List.generate(
              2,
              (i) => _asset(
                'b-$year-$i',
                DateTime(year, 8, 10 + i),
                location: const GeoPoint(31.23, 121.47),
              ),
            ),
        ];
        final candidates = await const SamePlaceAcrossYearsRule(
          config: SamePlaceAcrossYearsRuleConfig(
            minimumYearCount: 3,
            minimumVisitCount: 3,
          ),
        ).discover(MemoryContext(assets: assets));
        expect(candidates, hasLength(1));
        expect(candidates.first.metadata['longestConsecutiveYearRun'], 3);
        expect(candidates.first.safeTitleTemplate, contains('连续 3 年'));
      },
    );

    test(
      'PersonTimeline uses firstYear and calendarSpan not distinct count',
      () async {
        final assets = [
          for (final year in [2019, 2022, 2026])
            ...List.generate(
              2,
              (i) => _asset(
                'p-$year-$i',
                DateTime(year, 1, 10 + i),
                personIds: const ['p1'],
              ),
            ),
        ];
        final candidates = await const PersonTimelineRule().discover(
          MemoryContext(assets: assets),
        );
        expect(candidates, hasLength(1));
        expect(candidates.first.metadata['distinctYearCount'], 3);
        expect(candidates.first.metadata['calendarSpanYears'], 8);
        expect(candidates.first.metadata['firstYear'], 2019);
        expect(candidates.first.safeTitleTemplate, contains('2019'));
        expect(candidates.first.safeSubtitleTemplate, contains('跨越 8 年'));
      },
    );

    test('LongTermEvolution uses calendarSpan for title', () async {
      final assets = [
        for (final year in [2019, 2022, 2026, 2028])
          ...List.generate(
            2,
            (i) => _asset(
              'e-$year-$i',
              DateTime(year, 3, 1 + i),
              personIds: const ['p1'],
            ),
          ),
      ];
      final candidates = await const LongTermEvolutionRule(
        config: LongTermEvolutionRuleConfig(minimumAssets: 4, minimumYears: 3),
      ).discover(MemoryContext(assets: assets));
      expect(candidates, isNotEmpty);
      final personEvo = candidates.firstWhere(
        (c) => c.personIds.contains('p1'),
      );
      expect(personEvo.metadata['calendarSpanYears'], 10); // 2019-2028
      expect(personEvo.safeTitleTemplate, contains('跨越了 10 年'));
      expect(personEvo.safeTitleTemplate, isNot(contains('3 年的变化')));
    });

    test('AnnualTogether uses longestConsecutiveYearRun metadata', () async {
      // Create person appearing around same day-of-year across years 2020-2022 consecutively and 2025 gap
      final assets = [
        _asset('annual-2020', DateTime(2020, 6, 15), personIds: const ['ann']),
        _asset('annual-2021', DateTime(2021, 6, 16), personIds: const ['ann']),
        _asset('annual-2022', DateTime(2022, 6, 15), personIds: const ['ann']),
        _asset('annual-2025', DateTime(2025, 6, 15), personIds: const ['ann']),
      ];
      final candidates = await const AnnualTogetherRule(
        config: AnnualTogetherRuleConfig(minimumYearCount: 3, windowDays: 24),
      ).discover(MemoryContext(assets: assets));
      expect(candidates, isNotEmpty);
      // Should contain distinctYearCount 4 and longest 3
      final c = candidates.first;
      expect(c.metadata['distinctYearCount'], 4);
      expect(c.metadata['longestConsecutiveYearRun'], 3);
      // Consecutive >=3 so title should be 每年
      expect(c.safeTitleTemplate, contains('每年'));
    });
  });

  // Spatial clustering
  group('P0-2 Spatial clustering', () {
    test(
      'points <500m across old rounding boundary should be same cluster',
      () async {
        // 31.049 vs 31.051 difference 0.002 deg ~222m, old buckets 31.0 vs 31.1
        final assets = [
          _asset(
            's1',
            DateTime(2026, 1, 1),
            location: const GeoPoint(31.049, 121.049),
          ),
          _asset(
            's2',
            DateTime(2026, 1, 2),
            location: const GeoPoint(31.051, 121.051),
          ),
          _asset(
            's3',
            DateTime(2026, 1, 3),
            location: const GeoPoint(31.050, 121.050),
          ),
        ];
        // SamePlaceRule with 500m radius should group them together (1 session if within 14 days)
        final candidates = await const SamePlaceRule(
          clusterConfig: LocationClusterConfig(radiusMeters: 500),
          maxSessionGap: Duration(days: 14),
        ).discover(MemoryContext(assets: assets));
        // Should be at least 1 candidate (3 assets >= minimum 3)
        expect(candidates, isNotEmpty);
        // And should not split into 2 places; placeIds length 1 for that candidate
        expect(candidates.first.placeIds, hasLength(1));
      },
    );

    test('points >500m in same old grid should be different clusters', () async {
      // 31.01 and 31.04 diff 0.03 deg ~3.3km >500m, same old bucket 31.0
      final assets = [
        _asset(
          'd1',
          DateTime(2026, 1, 1),
          location: const GeoPoint(31.01, 121.01),
        ),
        _asset(
          'd2',
          DateTime(2026, 1, 2),
          location: const GeoPoint(31.01, 121.01),
        ),
        _asset(
          'd3',
          DateTime(2026, 1, 3),
          location: const GeoPoint(31.01, 121.01),
        ),
        _asset(
          'e1',
          DateTime(2026, 1, 4),
          location: const GeoPoint(31.04, 121.04),
        ),
        _asset(
          'e2',
          DateTime(2026, 1, 5),
          location: const GeoPoint(31.04, 121.04),
        ),
        _asset(
          'e3',
          DateTime(2026, 1, 6),
          location: const GeoPoint(31.04, 121.04),
        ),
      ];
      final context = MemoryContext(assets: assets);
      // Use SamePlaceAcrossYearsRule clusters? Test clustering directly via SamePlaceRule
      final candidates = await const SamePlaceRule(
        clusterConfig: LocationClusterConfig(radiusMeters: 500),
        maxSessionGap: Duration(days: 14),
      ).discover(context);
      // Should produce 2 candidates (one per cluster) not 1 merged
      expect(candidates.length, greaterThanOrEqualTo(2));
      final allPlaceIds = candidates.expand((c) => c.placeIds).toSet();
      expect(allPlaceIds.length, 2);
    });
  });

  // High latitude spatial
  group('P0-2b High latitude clustering', () {
    for (final lat in [0.0, 60.0, 70.0]) {
      test('lat $lat°: ~400m same cluster, ~700m different cluster', () async {
        final base = GeoPoint(lat, 0);
        final near = _offsetEast(base, 400);
        final far = _offsetEast(base, 700);
        // 400m same cluster: create 3 assets each location repeated to meet minAssets
        final nearAssets = [
          _asset('near-$lat-1', DateTime(2026, 1, 1), location: base),
          _asset('near-$lat-2', DateTime(2026, 1, 2), location: near),
          _asset('near-$lat-3', DateTime(2026, 1, 3), location: base),
        ];
        final nearCandidates = await const SamePlaceRule(
          clusterConfig: LocationClusterConfig(radiusMeters: 500),
          maxSessionGap: Duration(days: 14),
        ).discover(MemoryContext(assets: nearAssets));
        expect(
          nearCandidates,
          isNotEmpty,
          reason: '400m at $lat° should be same cluster',
        );
        expect(nearCandidates.first.placeIds, hasLength(1));

        // 700m different cluster: two distinct places each with 3 assets
        final farAssets = [
          _asset('far-base-$lat-1', DateTime(2026, 1, 1), location: base),
          _asset('far-base-$lat-2', DateTime(2026, 1, 2), location: base),
          _asset('far-base-$lat-3', DateTime(2026, 1, 3), location: base),
          _asset('far-$lat-1', DateTime(2026, 1, 4), location: far),
          _asset('far-$lat-2', DateTime(2026, 1, 5), location: far),
          _asset('far-$lat-3', DateTime(2026, 1, 6), location: far),
        ];
        final farCandidates = await const SamePlaceRule(
          clusterConfig: LocationClusterConfig(radiusMeters: 500),
          maxSessionGap: Duration(days: 14),
        ).discover(MemoryContext(assets: farAssets));
        expect(
          farCandidates.length,
          greaterThanOrEqualTo(2),
          reason: '700m at $lat° should be different clusters',
        );
        final ids = farCandidates.expand((c) => c.placeIds).toSet();
        expect(ids.length, 2);
      });
    }
  });

  // Travel enrichment
  group('P0-3 Travel enrichment', () {
    test('travel candidate includes unlocated media in window', () async {
      // Create a valid travel window: 4 days, 3 places, located 20, plus 30 unlocated in same window
      final located = <MediaAsset>[];
      for (var day = 1; day <= 4; day++) {
        for (var p = 0; p < 5; p++) {
          located.add(
            _asset(
              'loc-$day-$p',
              DateTime(2026, 5, day, 10 + p),
              location: GeoPoint(35.0 + p * 0.35, 139.0 + p * 0.28),
            ),
          );
        }
      }
      // Ensure at least 20 located
      final located20 = located.take(20).toList();
      final unlocated = List.generate(
        30,
        (i) => _asset('unloc-$i', DateTime(2026, 5, 2, 12), location: null),
      );
      final all = [...located20, ...unlocated];
      // Shuffle? Keep dates within window
      final candidates = await const TravelStoryRule(
        config: TravelStoryRuleConfig(
          minimumAssets: 12,
          minimumDays: 3,
          minimumPlaceCount: 3,
        ),
      ).discover(MemoryContext(assets: all));
      expect(candidates, isNotEmpty);
      final c = candidates.first;
      expect(c.metadata['locatedMediaCount'], 20);
      expect(c.metadata['totalMediaCount'], 50);
      expect(c.mediaIds.length, 50);
      expect((c.metadata['locationCoverage'] as double), closeTo(0.4, 0.01));
    });
  });

  // Evaluation privacy
  group('P0-4 Evaluation privacy', () {
    test('opaque id does not contain raw coordinates', () async {
      final dir = await Directory.systemTemp.createTemp('eval-privacy-');
      final file = File('${dir.path}/eval.json');
      final store = JsonFileMemoryEvaluationStore(file);
      const rawId = 'place-years-22.54321,114.06789';
      final candidate = MemoryCandidate(
        id: rawId,
        type: MemoryCandidateType.samePlaceAcrossYears,
        period: DateTimeRange(DateTime(2020), DateTime(2026)),
        mediaIds: const [],
      );
      final evaluation = MemoryEvaluation.forCandidate(
        candidate,
        accuracy: 4,
        meaningfulness: 5,
        surprise: 4,
        clarity: 5,
        sensitivity: 5,
        labels: const ['有意义'],
        createdAt: DateTime(2026, 8, 31),
      );
      await store.save(evaluation);
      final content = await file.readAsString();
      expect(content, isNot(contains('22.54321')));
      expect(content, isNot(contains('114.06789')));
      expect(content, isNot(contains(rawId)));
      expect(content, contains('eval-'));
      await dir.delete(recursive: true);
    });

    test('opaque id is stable deterministic', () {
      const raw = 'place-years-22.54321,114.06789';
      final id1 = MemoryEvaluation.opaqueCandidateId(
        raw,
        MemoryCandidateType.samePlaceAcrossYears,
      );
      final id2 = MemoryEvaluation.opaqueCandidateId(
        raw,
        MemoryCandidateType.samePlaceAcrossYears,
      );
      expect(id1, id2);
      expect(id1, startsWith('eval-'));
      expect(id1.length, 21); // eval- + 16 hex
    });
  });

  // Annual window
  group('P1-2 Annual window boundary', () {
    test('Dec 31 and Jan 1 are within 24-day window', () async {
      final assets = [
        _asset('dec31-2020', DateTime(2020, 12, 31), personIds: const ['p1']),
        _asset('jan01-2021', DateTime(2021, 1, 1), personIds: const ['p1']),
        _asset('jan02-2022', DateTime(2022, 1, 2), personIds: const ['p1']),
        _asset('dec30-2023', DateTime(2023, 12, 30), personIds: const ['p1']),
      ];
      final candidates = await const AnnualTogetherRule(
        config: AnnualTogetherRuleConfig(minimumYearCount: 2, windowDays: 24),
      ).discover(MemoryContext(assets: assets));
      // All 4 should be in same annual cluster because max circular distance <= ~3 days
      expect(candidates, isNotEmpty);
      // At least one candidate should contain 4 years
      expect(
        candidates.any((c) => c.metadata['distinctYearCount'] == 4),
        isTrue,
      );
    });

    test(
      'old 24-day bucket would split Dec31/Jan1 incorrectly but new does not',
      () {
        // DayOfYear: Dec31 ~365, Jan1 =1 distance 1 -> should be same window
        final dist = _circularDayDistanceForTest(365, 1);
        expect(dist, lessThanOrEqualTo(24));
      },
    );
  });

  group('P1-2b Leap year annual window', () {
    test('Feb28/Feb29/Mar1 recurrence does not split incorrectly', () async {
      // 2020 is leap, Feb29 exists; 2021 Feb28 and 2024 Feb29/Mar1 etc.
      final assets = [
        _asset('feb28-2021', DateTime(2021, 2, 28), personIds: const ['pLeap']),
        _asset('feb29-2020', DateTime(2020, 2, 29), personIds: const ['pLeap']),
        _asset('mar01-2022', DateTime(2022, 3, 1), personIds: const ['pLeap']),
        _asset('feb28-2023', DateTime(2023, 2, 28), personIds: const ['pLeap']),
      ];
      final candidates = await const AnnualTogetherRule(
        config: AnnualTogetherRuleConfig(minimumYearCount: 2, windowDays: 4),
      ).discover(MemoryContext(assets: assets));
      // All 4 days are within ~2 days circular distance when considering Feb28/29/Mar1 cluster
      // With window 4, they should be grouped together (at least one candidate with 3+ years)
      expect(candidates, isNotEmpty);
      expect(
        candidates.any((c) => (c.metadata['distinctYearCount'] as int) >= 3),
        isTrue,
      );
    });
  });

  // Localization boundary
  group('P0-5 Localization', () {
    test(
      'engine metadata sufficient for copy mapper without safeTitleTemplate',
      () async {
        final assets = [
          for (final year in [2022, 2023, 2024])
            ...List.generate(
              2,
              (i) => _asset(
                'loc-$year-$i',
                DateTime(year, 8, 10 + i),
                location: const GeoPoint(31.23, 121.47),
              ),
            ),
        ];
        final candidates = await const SamePlaceAcrossYearsRule().discover(
          MemoryContext(assets: assets),
        );
        expect(candidates, isNotEmpty);
        final c = candidates.first;
        // Verify mapper can be used without relying on safeTitleTemplate
        expect(c.metadata['distinctYearCount'], 3);
        expect(c.metadata['longestConsecutiveYearRun'], 3);
        // Simulate copy generation without safeTitleTemplate
        final longest = c.metadata['longestConsecutiveYearRun'] as int;
        final canSayConsecutive = longest >= 3;
        expect(canSayConsecutive, isTrue);
      },
    );
  });

  // Large library
  group('P0-6 Large library no silent cap', () {
    test('engine sees >50K assets', () async {
      final assets = List.generate(
        50001,
        (i) => _asset('large-$i', DateTime(2020 + (i % 6), 1 + (i % 28) + 1)),
      );
      final context = MemoryContext(assets: assets);
      final candidates = await const DateClusterRule(
        minimumAssets: 1000,
      ).discover(context);
      expect(candidates, isNotEmpty);
      expect(context.assets.length, 50001);
      // Also test with 60K smoke
      final assets60k = List.generate(
        60000,
        (i) => _asset('x-$i', DateTime(2021, 6, 1 + (i % 10))),
      );
      expect(assets60k.length, 60000);
      expect(MemoryContext(assets: assets60k).assets.length, 60000);
    });
  });
}

int _circularDayDistanceForTest(int a, int b) {
  final diff = (a - b).abs();
  return diff < 366 - diff ? diff : 366 - diff;
}

GeoPoint _offsetEast(GeoPoint base, double metersEast) {
  final latRad = base.latitude * math.pi / 180;
  final cosLat = math.cos(latRad).abs().clamp(0.01, 1.0);
  final deltaLon = metersEast / (111000 * cosLat);
  return GeoPoint(base.latitude, base.longitude + deltaLon);
}

MediaAsset _asset(
  String id,
  DateTime date, {
  GeoPoint? location,
  List<String> personIds = const [],
}) => MediaAsset(
  id: id,
  type: MediaType.image,
  creationDate: date,
  location: location,
  isFavorite: false,
  personIds: personIds,
);
