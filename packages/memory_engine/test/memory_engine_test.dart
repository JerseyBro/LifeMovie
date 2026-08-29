import 'package:media_library/media_library.dart';
import 'package:memory_domain/memory_domain.dart';
import 'package:memory_engine/memory_engine.dart';
import 'package:test/test.dart';

void main() {
  final assets = List.generate(
    6,
    (i) => MediaAsset(
      id: '$i',
      type: MediaType.image,
      creationDate: DateTime(2025, 7, 10 + i ~/ 3),
      location: const GeoPoint(31.23, 121.47),
      isFavorite: i == 0,
    ),
  );
  final context = MemoryContext(assets: assets);
  test('rules produce explainable candidates', () async {
    final candidates = await MemoryEngine(
      rules: const [DateClusterRule(), SamePlaceRule(), YearRecapRule()],
    ).discover(context);
    expect(
      candidates.map((c) => c.type),
      containsAll([
        MemoryCandidateType.dateCluster,
        MemoryCandidateType.samePlace,
        MemoryCandidateType.yearRecap,
      ]),
    );
    expect(candidates.every((c) => c.reasons.isNotEmpty), isTrue);
  });
  test('ranking returns descending scores with breakdown factors', () {
    final candidate = MemoryCandidate(
      id: 'x',
      type: MemoryCandidateType.yearRecap,
      period: DateTimeRange(DateTime(2025), DateTime(2025, 12, 31)),
      mediaIds: assets.map((a) => a.id).toList(),
    );
    final ranker = const WeightedMemoryRanker();
    final breakdown = ranker.explain(candidate, context);
    expect(
      breakdown.factors.keys,
      containsAll([
        'mediaCount',
        'favoriteCount',
        'duration',
        'locationConsistency',
      ]),
    );
    expect(ranker.rank([candidate], context).single.score, breakdown.score);
  });
}
