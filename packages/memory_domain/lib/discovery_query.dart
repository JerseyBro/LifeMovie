/// Discovery query model (Sprint 1.0).
///
/// The UI never assembles filter logic by hand: it mutates this immutable
/// query and the engine applies it. Semantics are explicit:
///   - AND across dimensions (year AND place AND type ...)
///   - OR within one dimension (place = A OR place = B)
library;

import 'memory_domain.dart';

enum DiscoverySortMode { recommended, newest, oldest, mostPhotos }

/// Filter keys, used by active-filter chips to remove one selection.
enum DiscoveryFilterKey {
  years,
  places,
  people,
  memoryTypes,
  mediaTypes,
  favorites,
}

class MemoryDiscoveryQuery {
  const MemoryDiscoveryQuery({
    this.years = const [],
    this.placeIds = const [],
    this.personIds = const [],
    this.memoryTypes = const [],
    this.mediaTypes = const [],
    this.favoritesOnly = false,
    this.sort = DiscoverySortMode.recommended,
  });

  final List<int> years;
  final List<String> placeIds;
  final List<String> personIds;
  final List<MemoryCandidateType> memoryTypes;
  final List<MediaType> mediaTypes;
  final bool favoritesOnly;
  final DiscoverySortMode sort;

  bool get isDefault =>
      years.isEmpty &&
      placeIds.isEmpty &&
      personIds.isEmpty &&
      memoryTypes.isEmpty &&
      mediaTypes.isEmpty &&
      !favoritesOnly &&
      sort == DiscoverySortMode.recommended;

  int get activeFilterCount =>
      years.length +
      placeIds.length +
      personIds.length +
      memoryTypes.length +
      mediaTypes.length +
      (favoritesOnly ? 1 : 0);

  MemoryDiscoveryQuery copyWith({
    List<int>? years,
    List<String>? placeIds,
    List<String>? personIds,
    List<MemoryCandidateType>? memoryTypes,
    List<MediaType>? mediaTypes,
    bool? favoritesOnly,
    DiscoverySortMode? sort,
  }) => MemoryDiscoveryQuery(
    years: years ?? this.years,
    placeIds: placeIds ?? this.placeIds,
    personIds: personIds ?? this.personIds,
    memoryTypes: memoryTypes ?? this.memoryTypes,
    mediaTypes: mediaTypes ?? this.mediaTypes,
    favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    sort: sort ?? this.sort,
  );

  /// Returns a copy with [value] removed from the given dimension.
  MemoryDiscoveryQuery without(DiscoveryFilterKey key, Object? value) {
    switch (key) {
      case DiscoveryFilterKey.years:
        return copyWith(years: years.where((y) => y != value).toList());
      case DiscoveryFilterKey.places:
        return copyWith(placeIds: placeIds.where((p) => p != value).toList());
      case DiscoveryFilterKey.people:
        return copyWith(personIds: personIds.where((p) => p != value).toList());
      case DiscoveryFilterKey.memoryTypes:
        return copyWith(
          memoryTypes: memoryTypes
              .where((t) => t != value)
              .toList(growable: false),
        );
      case DiscoveryFilterKey.mediaTypes:
        return copyWith(
          mediaTypes: mediaTypes
              .where((t) => t != value)
              .toList(growable: false),
        );
      case DiscoveryFilterKey.favorites:
        return copyWith(favoritesOnly: false);
    }
  }

  /// Clears every dimension but keeps the sort mode.
  MemoryDiscoveryQuery clearFilters() => MemoryDiscoveryQuery(sort: sort);

  /// Pure matching logic.
  ///
  /// [assetsById] resolves a candidate's media so media-level dimensions
  /// (media type, favorites) can participate. A candidate matches when every
  /// dimension either is empty or has at least one hit inside the candidate.
  bool matchesCandidate(
    MemoryCandidate candidate,
    Map<String, MediaAsset> assetsById,
  ) {
    if (years.isNotEmpty) {
      final candidateYears = _candidateYears(candidate, assetsById);
      if (!years.any(candidateYears.contains)) return false;
    }
    if (placeIds.isNotEmpty && !placeIds.any(candidate.placeIds.contains)) {
      return false;
    }
    if (personIds.isNotEmpty && !personIds.any(candidate.personIds.contains)) {
      return false;
    }
    if (memoryTypes.isNotEmpty && !memoryTypes.contains(candidate.type)) {
      return false;
    }
    if (mediaTypes.isNotEmpty || favoritesOnly) {
      final media = _candidateMedia(candidate, assetsById);
      if (mediaTypes.isNotEmpty &&
          !media.any((asset) => mediaTypes.contains(asset.type))) {
        return false;
      }
      if (favoritesOnly && !media.any((asset) => asset.isFavorite)) {
        return false;
      }
    }
    return true;
  }

  Set<int> _candidateYears(
    MemoryCandidate candidate,
    Map<String, MediaAsset> assetsById,
  ) {
    final years = <int>{};
    for (final id in candidate.mediaIds) {
      final year = assetsById[id]?.creationDate?.year;
      if (year != null) years.add(year);
    }
    return years;
  }

  List<MediaAsset> _candidateMedia(
    MemoryCandidate candidate,
    Map<String, MediaAsset> assetsById,
  ) => candidate.mediaIds
      .map((id) => assetsById[id])
      .whereType<MediaAsset>()
      .toList(growable: false);
}
