import 'package:flutter/foundation.dart';
import 'package:memory_domain/memory_domain.dart';
import 'package:memory_engine/memory_engine.dart';

/// Application-layer state for Discovery Home / Search / Timeline.
///
/// UI mutates the [query]; all filtering/sorting goes through the engine.
/// No ranking happens here (BOUNDARIES: Ranking stays in memory_engine).
class DiscoveryController extends ChangeNotifier {
  DiscoveryController({
    this.queryEngine = const DiscoveryQueryEngine(),
    this.dimensionIndex = const DiscoveryDimensionIndex(),
  });

  final DiscoveryQueryEngine queryEngine;
  final DiscoveryDimensionIndex dimensionIndex;

  MemoryDiscoveryQuery query = const MemoryDiscoveryQuery();

  /// Full ranked set (ranker -> sensitivity -> dedup). Never re-ranked here.
  List<MemoryCandidate> rankedCandidates = const [];

  /// Diversity-ordered "For You" feed (top of the ranked set).
  List<MemoryCandidate> feedCandidates = const [];

  List<MediaAsset> assets = const [];

  /// Set by the root shell: opens a candidate's detail page from any tab.
  void Function(MemoryCandidate candidate)? onOpenCandidate;

  DiscoveryDimensionSummary? _dimensions;

  void update({
    required List<MemoryCandidate> rankedCandidates,
    required List<MemoryCandidate> feedCandidates,
    required List<MediaAsset> assets,
  }) {
    this.rankedCandidates = rankedCandidates;
    this.feedCandidates = feedCandidates;
    this.assets = assets;
    _dimensions = null;
    notifyListeners();
  }

  DiscoveryDimensionSummary? dimensions({bool force = false}) {
    if (_dimensions == null || force) {
      if (rankedCandidates.isEmpty && assets.isEmpty) return null;
      _dimensions = dimensionIndex.summarize(
        candidates: rankedCandidates,
        assets: assets,
      );
    }
    return _dimensions;
  }

  bool get hasActiveFilters => !query.isDefault;

  /// The visible "For You" list: diversity feed when no filter is active,
  /// engine-filtered ranked set otherwise.
  List<MemoryCandidate> visibleCandidates() {
    if (!hasActiveFilters) return feedCandidates;
    return queryEngine.apply(
      query,
      rankedCandidates,
      MemoryContext(assets: assets),
    );
  }

  List<MemoryCandidate> searchResults(String text) {
    final base = hasActiveFilters
        ? queryEngine.apply(
            query,
            rankedCandidates,
            MemoryContext(assets: assets),
          )
        : rankedCandidates;
    if (text.trim().isEmpty) return base;
    return const DiscoverySearchService().search(
      query: text,
      candidates: base,
      context: MemoryContext(assets: assets),
      textOf: null,
    );
  }

  void openCandidate(MemoryCandidate candidate) =>
      onOpenCandidate?.call(candidate);

  // --- Query mutations -------------------------------------------------------

  void _mutate(MemoryDiscoveryQuery next) {
    query = next;
    notifyListeners();
  }

  void toggleYear(int year) => _mutate(
    query.years.contains(year)
        ? query.without(DiscoveryFilterKey.years, year)
        : query.copyWith(years: [...query.years, year]),
  );

  void togglePlace(String placeId) => _mutate(
    query.placeIds.contains(placeId)
        ? query.without(DiscoveryFilterKey.places, placeId)
        : query.copyWith(placeIds: [...query.placeIds, placeId]),
  );

  void togglePerson(String personId) => _mutate(
    query.personIds.contains(personId)
        ? query.without(DiscoveryFilterKey.people, personId)
        : query.copyWith(personIds: [...query.personIds, personId]),
  );

  void toggleMemoryType(MemoryCandidateType type) => _mutate(
    query.memoryTypes.contains(type)
        ? query.without(DiscoveryFilterKey.memoryTypes, type)
        : query.copyWith(memoryTypes: [...query.memoryTypes, type]),
  );

  void toggleMediaType(MediaType type) => _mutate(
    query.mediaTypes.contains(type)
        ? query.without(DiscoveryFilterKey.mediaTypes, type)
        : query.copyWith(mediaTypes: [...query.mediaTypes, type]),
  );

  void toggleFavorites() =>
      _mutate(query.copyWith(favoritesOnly: !query.favoritesOnly));

  void setSort(DiscoverySortMode sort) => _mutate(query.copyWith(sort: sort));

  void clearFilters() => _mutate(query.clearFilters());
}
