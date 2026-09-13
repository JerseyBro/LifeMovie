import 'package:test/test.dart';
import 'package:memory_domain/memory_domain.dart';
import 'package:memory_engine/memory_engine.dart';

MediaAsset _asset(
  String id, {
  int year = 2024,
  GeoPoint? location,
  List<String> personIds = const [],
  bool favorite = false,
  MediaType type = MediaType.image,
}) => MediaAsset(
  id: id,
  localIdentifier: id,
  type: type,
  creationDate: DateTime(year, 6, 15),
  location: location,
  personIds: personIds,
  isFavorite: favorite,
);

MemoryCandidate _candidate(
  String id,
  MemoryCandidateType type, {
  List<String> mediaIds = const [],
  List<String> placeIds = const [],
  List<String> personIds = const [],
  DateTime? start,
  DateTime? end,
}) => MemoryCandidate(
  id: id,
  type: type,
  period: DateTimeRange(
    start ?? DateTime(2024, 1, 1),
    end ?? DateTime(2024, 12, 31),
  ),
  mediaIds: mediaIds,
  placeIds: placeIds,
  personIds: personIds,
);

void main() {
  final assets = [
    _asset(
      'a1',
      year: 2024,
      location: const GeoPoint(30.0, 120.0),
      favorite: true,
    ),
    _asset('a2', year: 2024, location: const GeoPoint(30.0, 120.0)),
    _asset('a3', year: 2023, location: const GeoPoint(30.001, 120.0)),
    _asset('a4', year: 2022, personIds: const ['person-a']),
    _asset('a5', year: 2021, type: MediaType.video),
    _asset('a6', year: 2023, personIds: const ['person-a']),
    _asset('a7', year: 2024, personIds: const ['person-a'], favorite: true),
  ];
  final context = MemoryContext(assets: assets);

  final candidates = [
    _candidate(
      'c1',
      MemoryCandidateType.samePlace,
      mediaIds: ['a1', 'a2'],
      placeIds: ['cluster-0'],
      start: DateTime(2024, 1, 1),
      end: DateTime(2024, 12, 31),
    ),
    _candidate(
      'c2',
      MemoryCandidateType.travelStory,
      mediaIds: ['a3'],
      start: DateTime(2023, 6, 1),
      end: DateTime(2023, 6, 30),
    ),
    _candidate(
      'c3',
      MemoryCandidateType.personTimeline,
      mediaIds: ['a4'],
      personIds: ['person-a'],
      start: DateTime(2022, 5, 1),
      end: DateTime(2022, 5, 2),
    ),
    _candidate(
      'c4',
      MemoryCandidateType.yearRecap,
      mediaIds: ['a5'],
      start: DateTime(2021, 3, 1),
      end: DateTime(2021, 3, 2),
    ),
  ];

  group('DiscoveryQueryEngine filter', () {
    const engine = DiscoveryQueryEngine();

    test('default query returns everything', () {
      expect(
        engine.filter(const MemoryDiscoveryQuery(), candidates, context).length,
        4,
      );
    });

    test('single dimension: year 2024 keeps only matching candidates', () {
      final result = engine.filter(
        const MemoryDiscoveryQuery(years: [2024]),
        candidates,
        context,
      );
      expect(result.map((c) => c.id), ['c1']);
    });

    test('AND across dimensions: year AND type', () {
      final result = engine.filter(
        const MemoryDiscoveryQuery(
          years: [2023],
          memoryTypes: [MemoryCandidateType.travelStory],
        ),
        candidates,
        context,
      );
      expect(result.map((c) => c.id), ['c2']);
    });

    test('OR within dimension: either place matches', () {
      final result = engine.filter(
        const MemoryDiscoveryQuery(placeIds: ['cluster-0', 'cluster-9']),
        candidates,
        context,
      );
      expect(result.map((c) => c.id), ['c1']);
    });

    test('media type OR + favorites dimension', () {
      final video = engine.filter(
        const MemoryDiscoveryQuery(mediaTypes: [MediaType.video]),
        candidates,
        context,
      );
      expect(video.map((c) => c.id), ['c4']);

      final favorite = engine.filter(
        const MemoryDiscoveryQuery(favoritesOnly: true),
        candidates,
        context,
      );
      expect(favorite.map((c) => c.id), ['c1']);
    });

    test('empty result is allowed', () {
      final result = engine.filter(
        const MemoryDiscoveryQuery(years: [1999]),
        candidates,
        context,
      );
      expect(result, isEmpty);
    });

    test('without() removes a single selection', () {
      const query = MemoryDiscoveryQuery(
        years: [2023, 2024],
        favoritesOnly: true,
      );
      final updated = query.without(DiscoveryFilterKey.years, 2023);
      expect(updated.years, [2024]);
      expect(updated.activeFilterCount, 2);
      final cleared = updated.clearFilters();
      expect(cleared.isDefault, isTrue);
    });
  });

  group('DiscoveryQueryEngine sort', () {
    const engine = DiscoveryQueryEngine();

    test('recommended preserves ranking order', () {
      final result = engine.sort(
        const MemoryDiscoveryQuery(),
        candidates,
        context,
      );
      expect(result.map((c) => c.id), ['c1', 'c2', 'c3', 'c4']);
    });

    test('newest/oldest/mostPhotos reorder without re-scoring', () {
      final newest = engine.sort(
        const MemoryDiscoveryQuery(sort: DiscoverySortMode.newest),
        candidates,
        context,
      );
      expect(newest.first.id, 'c1');

      final oldest = engine.sort(
        const MemoryDiscoveryQuery(sort: DiscoverySortMode.oldest),
        candidates,
        context,
      );
      expect(oldest.first.id, 'c4');

      final mostPhotos = engine.sort(
        const MemoryDiscoveryQuery(sort: DiscoverySortMode.mostPhotos),
        candidates,
        context,
      );
      expect(mostPhotos.first.id, 'c1');
    });
  });

  group('DiscoveryDimensionIndex', () {
    test('places appear only with real GPS clusters', () {
      const index = DiscoveryDimensionIndex();
      final summary = index.summarize(candidates: candidates, assets: assets);
      expect(summary.places, isNotEmpty);
      expect(summary.places.first.assetCount, greaterThanOrEqualTo(3));
      expect(summary.years.keys.first, 2024, reason: 'newest year first');
    });

    test('people hidden without person data, visible with it', () {
      const index = DiscoveryDimensionIndex();
      final withoutPeople = index.summarize(
        candidates: candidates,
        assets: assets.where((a) => a.personIds.isEmpty).toList(),
      );
      expect(withoutPeople.people, isEmpty);
      expect(withoutPeople.hasPersonData, isFalse);

      final withPeople = index.summarize(
        candidates: candidates,
        assets: assets,
      );
      expect(withPeople.people, isNotEmpty);
      expect(withPeople.people.first.personId, 'person-a');
    });

    test('type sections map from real candidates', () {
      const index = DiscoveryDimensionIndex();
      final summary = index.summarize(candidates: candidates, assets: assets);
      expect(summary.trips.map((c) => c.id), ['c2']);
      expect(summary.recentDiscoveries.first.id, 'c1');
    });
  });

  group('DiscoverySearchService', () {
    const engine = DiscoveryQueryEngine();
    const search = DiscoverySearchService();

    test('year token filters by candidate period or assets', () {
      final result = search.search(
        query: '2023',
        candidates: candidates,
        context: context,
      );
      expect(result.map((c) => c.id), ['c2']);
    });

    test('type keyword maps deterministically', () {
      final result = search.search(
        query: '旅行',
        candidates: candidates,
        context: context,
      );
      expect(result.map((c) => c.id), ['c2']);
    });

    test('multiple tokens AND together', () {
      final result = search.search(
        query: '2023 旅行',
        candidates: candidates,
        context: context,
      );
      expect(result.map((c) => c.id), ['c2']);

      final none = search.search(
        query: '2024 旅行',
        candidates: candidates,
        context: context,
      );
      expect(none, isEmpty);
    });

    test('free text matches via injected text provider', () {
      final result = search.search(
        query: '西湖',
        candidates: candidates,
        context: context,
        textOf: (candidate) => candidate.id == 'c1' ? '西湖边的一天' : '其他故事',
      );
      expect(result.map((c) => c.id), ['c1']);
    });

    test('composes with query engine filter', () {
      final searched = search.search(
        query: '2024',
        candidates: candidates,
        context: context,
      );
      final filtered = engine.filter(
        const MemoryDiscoveryQuery(
          memoryTypes: [MemoryCandidateType.samePlace],
        ),
        searched,
        context,
      );
      expect(filtered.map((c) => c.id), ['c1']);
    });
  });
}
