import 'dart:io';

import 'package:memory_domain/memory_domain.dart';
import 'package:memory_engine/memory_engine.dart';
import 'package:test/test.dart';

void main() {
  test('Sprint 0.8 rules produce explainable product candidates', () async {
    final context = MemoryContext(assets: _intelligenceAssets());
    final candidates = await MemoryEngine(
      rules: const [
        SamePlaceAcrossYearsRule(),
        FirstMemoryRule(),
        TravelStoryRule(),
        PersonTimelineRule(),
        AnnualTogetherRule(),
        LongTermEvolutionRule(),
      ],
    ).discover(context);

    expect(
      candidates.map((c) => c.type),
      containsAll([
        MemoryCandidateType.samePlaceAcrossYears,
        MemoryCandidateType.firstMemory,
        MemoryCandidateType.travelStory,
        MemoryCandidateType.personTimeline,
        MemoryCandidateType.annualTogether,
        MemoryCandidateType.longTermEvolution,
      ]),
    );
    expect(candidates.every((c) => c.reasons.isNotEmpty), isTrue);
    expect(candidates.every((c) => c.safeTitleTemplate != null), isTrue);
    expect(candidates.any((c) => c.representativeMediaIds.isNotEmpty), isTrue);
  });

  test(
    'same place across years has boundary thresholds and routine penalty',
    () async {
      final boundary = [
        for (final year in [2024, 2025, 2026])
          ...List.generate(
            2,
            (i) => _asset(
              'boundary-$year-$i',
              DateTime(year, 7, 1 + i),
              location: const GeoPoint(22.5, 114.0),
            ),
          ),
      ];
      final candidates = await const SamePlaceAcrossYearsRule(
        config: SamePlaceAcrossYearsRuleConfig(
          minimumYearCount: 3,
          minimumVisitCount: 3,
        ),
      ).discover(MemoryContext(assets: boundary));

      expect(candidates, hasLength(1));
      expect(candidates.single.metadata['yearCount'], 3);
      expect(candidates.single.metadata['visitCount'], 3);

      final negative = await const SamePlaceAcrossYearsRule().discover(
        MemoryContext(assets: boundary.take(4).toList()),
      );
      expect(negative, isEmpty);
    },
  );

  test('travel story requires movement, density and duration', () async {
    final positive = await const TravelStoryRule().discover(
      MemoryContext(assets: _travelAssets(18)),
    );
    expect(positive.single.type, MemoryCandidateType.travelStory);
    expect(positive.single.metadata['placeCount'], greaterThanOrEqualTo(3));

    final negative = await const TravelStoryRule().discover(
      MemoryContext(assets: _travelAssets(6)),
    );
    expect(negative, isEmpty);
  });

  test(
    'person rules use injected ids without relationship inference',
    () async {
      final candidates = await MemoryEngine(
        rules: const [
          PersonTimelineRule(),
          AnnualTogetherRule(),
          LongTermEvolutionRule(),
          FirstMemoryRule(),
        ],
      ).discover(MemoryContext(assets: _personAssets()));

      expect(candidates, isNotEmpty);
      expect(candidates.expand((c) => c.personIds).toSet(), contains('p1'));
      expect(
        candidates.map((c) => c.safeTitleTemplate).join(' '),
        isNot(contains('妈妈')),
      );
    },
  );

  test('ranking v0.2 exposes weighted signals and sensitivity penalty', () {
    final assets = _intelligenceAssets();
    final context = MemoryContext(assets: assets);
    final candidate = MemoryCandidate(
      id: 'x',
      type: MemoryCandidateType.travelStory,
      period: DateTimeRange(DateTime(2026, 1, 1), DateTime(2026, 1, 12)),
      mediaIds: assets.take(30).map((a) => a.id).toList(),
      representativeMediaIds: assets.take(6).map((a) => a.id).toList(),
      reasons: const ['synthetic test'],
    );
    final ranker = const WeightedMemoryRanker();
    final breakdown = ranker.explain(candidate, context);
    expect(
      breakdown.factors.keys,
      containsAll([
        'accuracyConfidence',
        'timeSpan',
        'recurrence',
        'mediaDiversity',
        'rarity',
        'visualCoverage',
        'storyPotential',
        'sensitivityPenalty',
      ]),
    );
    expect(breakdown.finalScore, greaterThan(0));
    expect(ranker.rank([candidate], context).single.score, breakdown.score);

    final unsafe = MemoryCandidate(
      id: 'unsafe',
      type: MemoryCandidateType.firstMemory,
      period: DateTimeRange(DateTime(2026), DateTime(2026)),
      mediaIds: const [],
      reasons: const ['death-related label'],
      safeTitleTemplate: 'death memory',
    );
    expect(ranker.rank([unsafe], context), isEmpty);
  });

  test(
    'sensitivity guard blocks unsafe inference and penalizes relationship terms',
    () {
      const guard = MemorySensitivityGuard();
      final relationship = guard.assess(
        MemoryCandidate(
          id: 'r',
          type: MemoryCandidateType.personTimeline,
          period: DateTimeRange(DateTime(2020), DateTime(2026)),
          mediaIds: const [],
          safeTitleTemplate: '你和妈妈这些年的照片',
        ),
      );
      expect(relationship.hidden, isFalse);
      expect(relationship.penalty, greaterThan(0));
      expect(relationship.flags, contains('unverified_relationship'));

      final bodyChange = guard.assess(
        MemoryCandidate(
          id: 'b',
          type: MemoryCandidateType.longTermEvolution,
          period: DateTimeRange(DateTime(2020), DateTime(2026)),
          mediaIds: const [],
          safeTitleTemplate: '你变瘦了',
        ),
      );
      expect(bodyChange.flags, contains('body_change'));
    },
  );

  test(
    'candidate dedup keeps strongest overlap and preserves different stories',
    () {
      final a = _candidate('a', MemoryCandidateType.travelStory, [
        '1',
        '2',
        '3',
        '4',
      ]);
      final b = _candidate('b', MemoryCandidateType.dateCluster, [
        '1',
        '2',
        '3',
        '4',
      ]).withScore(60);
      final c = _candidate('c', MemoryCandidateType.personTimeline, [
        '9',
        '10',
      ]).withScore(55);
      final deduped = const MemoryCandidateDeduplicator().deduplicate([
        a.withScore(80),
        b,
        c,
      ]);
      expect(deduped.map((item) => item.id), ['a', 'c']);
    },
  );

  test('feed diversity avoids more than two consecutive same rule types', () {
    final ranked = [
      for (var i = 0; i < 5; i++)
        _candidate('place-$i', MemoryCandidateType.samePlaceAcrossYears, [
          '$i',
        ]).withScore(100.0 - i),
      _candidate('travel', MemoryCandidateType.travelStory, const [
        't',
      ]).withScore(50),
    ];
    final diversified = const FeedDiversityController().diversify(ranked);
    expect(
      diversified.take(3).map((c) => c.type).toSet().length,
      greaterThan(1),
    );
  });

  test(
    'memory evaluation store saves, loads and updates local anonymous data',
    () async {
      final dir = await Directory.systemTemp.createTemp('lifemovie-eval-test');
      final store = JsonFileMemoryEvaluationStore(
        File('${dir.path}/eval.json'),
      );
      final evaluation = MemoryEvaluation(
        candidateId: 'anonymous-candidate',
        ruleType: MemoryCandidateType.travelStory,
        accuracy: 4,
        meaningfulness: 5,
        surprise: 4,
        clarity: 5,
        sensitivity: 5,
        labels: const ['有意义'],
        createdAt: DateTime(2026, 8, 31),
      );
      await store.save(evaluation);
      expect((await store.loadAll()).single.labels, ['有意义']);
      await store.save(
        MemoryEvaluation(
          candidateId: 'anonymous-candidate',
          ruleType: MemoryCandidateType.travelStory,
          accuracy: 2,
          meaningfulness: 2,
          surprise: 1,
          clarity: 3,
          sensitivity: 4,
          labels: const ['不准确'],
          createdAt: DateTime(2026, 8, 31, 1),
        ),
      );
      expect((await store.load('anonymous-candidate'))!.labels, ['不准确']);
      final fileContent = await File('${dir.path}/eval.json').readAsString();
      expect(fileContent, isNot(contains('/')));
      await dir.delete(recursive: true);
    },
  );

  test(
    'large input path avoids obvious quadratic asset scans in rules',
    () async {
      final assets = List.generate(
        5000,
        (i) => _asset(
          'large-$i',
          DateTime(2020 + (i % 6), 1 + (i % 12), 1 + (i % 24)),
          location: GeoPoint(22.5 + (i % 6) * .04, 114.0 + (i % 6) * .04),
          personIds: i % 17 == 0 ? const ['large-person'] : const [],
        ),
      );
      final watch = Stopwatch()..start();
      final candidates = await MemoryEngine(
        rules: const [
          SamePlaceAcrossYearsRule(),
          TravelStoryRule(),
          PersonTimelineRule(),
          AnnualTogetherRule(),
          LongTermEvolutionRule(),
        ],
      ).discover(MemoryContext(assets: assets));
      watch.stop();
      expect(candidates, isNotEmpty);
      expect(watch.elapsedMilliseconds, lessThan(1200));
    },
  );
}

MemoryCandidate _candidate(
  String id,
  MemoryCandidateType type,
  List<String> mediaIds,
) => MemoryCandidate(
  id: id,
  type: type,
  period: DateTimeRange(DateTime(2026, 1, 1), DateTime(2026, 1, 5)),
  mediaIds: mediaIds,
  reasons: const ['test'],
);

List<MediaAsset> _intelligenceAssets() => [
  ..._personAssets(),
  ..._travelAssets(24),
  for (final year in [2021, 2022, 2023, 2024, 2025, 2026])
    ...List.generate(
      3,
      (i) => _asset(
        'return-$year-$i',
        DateTime(year, 8, 10 + i),
        location: const GeoPoint(31.23, 121.47),
        favorite: i == 0,
      ),
    ),
];

List<MediaAsset> _personAssets() => [
  for (final year in [2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026])
    ...List.generate(
      3,
      (i) => _asset(
        'person-$year-$i',
        DateTime(year, 1, 10 + i),
        location: const GeoPoint(22.54, 114.06),
        personIds: const ['p1'],
      ),
    ),
];

List<MediaAsset> _travelAssets(int count) => List.generate(count, (i) {
  final day = 1 + (i ~/ 3);
  final place = i % 5;
  return _asset(
    'travel-$i',
    DateTime(2026, 5, day),
    location: GeoPoint(35.0 + place * .35, 139.0 + place * .28),
    video: i % 6 == 0,
    favorite: i % 9 == 0,
  );
});

MediaAsset _asset(
  String id,
  DateTime date, {
  GeoPoint? location,
  bool favorite = false,
  bool video = false,
  List<String> personIds = const [],
}) => MediaAsset(
  id: id,
  type: video ? MediaType.video : MediaType.image,
  creationDate: date,
  location: location,
  isFavorite: favorite,
  personIds: personIds,
);
