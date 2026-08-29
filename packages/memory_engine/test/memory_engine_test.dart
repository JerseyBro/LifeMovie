import 'package:memory_domain/memory_domain.dart';
import 'package:memory_engine/memory_engine.dart';
import 'package:test/test.dart';

void main() {
  test('rules produce explainable candidates', () async {
    final context = MemoryContext(assets: _assets());
    final candidates = await MemoryEngine(
      rules: const [
        DateClusterRule(),
        SamePlaceRule(),
        YearRecapRule(),
        PersonTimelineRule(),
      ],
    ).discover(context);
    expect(
      candidates.map((c) => c.type),
      containsAll([
        MemoryCandidateType.dateCluster,
        MemoryCandidateType.samePlace,
        MemoryCandidateType.yearRecap,
        MemoryCandidateType.personTimeline,
      ]),
    );
    expect(candidates.every((c) => c.reasons.isNotEmpty), isTrue);
  });

  test(
    'same place rule splits long-term home location into visit sessions',
    () async {
      final assets = [
        ...List.generate(
          4,
          (i) => _asset('near-$i', DateTime(2026, 1, 1 + i), location: true),
        ),
        ...List.generate(
          4,
          (i) => _asset('later-$i', DateTime(2026, 3, 1 + i), location: true),
        ),
      ];
      final candidates = await const SamePlaceRule(
        maxSessionGap: Duration(days: 7),
      ).discover(MemoryContext(assets: assets));
      expect(candidates, hasLength(2));
      expect(candidates.every((c) => c.mediaIds.length == 4), isTrue);
    },
  );

  test(
    'person timeline rule uses injected person ids without face recognition',
    () async {
      final candidates = await const PersonTimelineRule().discover(
        MemoryContext(
          assets: [
            _asset('a', DateTime(2024, 1, 1), personIds: const ['person-a']),
            _asset('b', DateTime(2025, 1, 1), personIds: const ['person-a']),
            _asset('c', DateTime(2026, 1, 1), personIds: const ['person-a']),
          ],
        ),
      );
      expect(candidates.single.type, MemoryCandidateType.personTimeline);
      expect(candidates.single.personIds, ['person-a']);
    },
  );

  test('ranking returns descending scores with breakdown factors', () {
    final assets = _assets();
    final context = MemoryContext(assets: assets);
    final candidate = MemoryCandidate(
      id: 'x',
      type: MemoryCandidateType.yearRecap,
      period: DateTimeRange(DateTime(2025), DateTime(2025, 12, 31)),
      mediaIds: assets.map((a) => a.id).toList(),
      reasons: const ['synthetic test'],
    );
    final ranker = const WeightedMemoryRanker();
    final breakdown = ranker.explain(candidate, context);
    expect(
      breakdown.factors.keys,
      containsAll([
        'mediaDensity',
        'duration',
        'favorite',
        'location',
        'videoRatio',
        'timeSpan',
        'recurrence',
      ]),
    );
    expect(breakdown.finalScore, greaterThan(0));
    expect(ranker.rank([candidate], context).single.score, breakdown.score);
  });
}

List<MediaAsset> _assets() => [
  ...List.generate(
    6,
    (i) => _asset(
      '$i',
      DateTime(2025, 7, 10 + i ~/ 3),
      location: true,
      favorite: i == 0,
      video: i == 2,
      personIds: i.isEven ? const ['person-a'] : const [],
    ),
  ),
  _asset('old', DateTime(2023, 7, 1), personIds: const ['person-a']),
];

MediaAsset _asset(
  String id,
  DateTime date, {
  bool location = false,
  bool favorite = false,
  bool video = false,
  List<String> personIds = const [],
}) => MediaAsset(
  id: id,
  type: video ? MediaType.video : MediaType.image,
  creationDate: date,
  location: location ? const GeoPoint(31.23, 121.47) : null,
  isFavorite: favorite,
  personIds: personIds,
);
