import 'package:drift/native.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_domain/memory_domain.dart';
import 'package:memory_engine/memory_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'synthetic PhotoKit-like data reaches ranked memory candidates',
    () async {
      final index = PersistentMediaIndex.fromExecutor(NativeDatabase.memory());
      final repository = MockMediaRepository(_syntheticAssets(120));

      final reconciliation = await index.reconcile(repository, batchSize: 25);
      final assets = await index.allAssets(limit: 200);
      final context = MemoryContext(assets: assets);
      final candidates = await MemoryEngine(
        rules: const [
          DateClusterRule(),
          SamePlaceRule(),
          YearRecapRule(),
          SamePlaceAcrossYearsRule(),
          FirstMemoryRule(),
          TravelStoryRule(),
          PersonTimelineRule(),
          AnnualTogetherRule(),
          LongTermEvolutionRule(),
        ],
      ).discover(context);
      final ranked = const WeightedMemoryRanker().rank(candidates, context);
      final deduped = const MemoryCandidateDeduplicator().deduplicate(ranked);
      final feed = const FeedDiversityController().diversify(deduped);

      expect(reconciliation.inserted, 120);
      expect(await index.count(), 120);
      expect(feed, isNotEmpty);
      expect(feed.first.score, greaterThan(0));
      expect(feed.first.reasons, isNotEmpty);
      expect(feed.first.safeTitleTemplate, isNotNull);
      await index.close();
    },
  );
}

List<MediaAsset> _syntheticAssets(int count) => List.generate(count, (i) {
  final day = 1 + (i % 24);
  final year = 2021 + (i % 6);
  final isVideo = i % 8 == 0;
  return MediaAsset(
    id: 'synthetic-$i',
    localIdentifier: 'synthetic-$i',
    type: isVideo ? MediaType.video : MediaType.image,
    creationDate: DateTime(year, 8, day),
    modificationDate: DateTime(year, 8, day, 12),
    duration: isVideo ? const Duration(seconds: 18) : null,
    width: 1200,
    height: 900,
    location: GeoPoint(22.5 + (i % 3) * .03, 114.0 + (i % 3) * .03),
    isFavorite: i % 19 == 0,
    personIds: i % 7 == 0 ? const ['synthetic-person'] : const [],
  );
});
