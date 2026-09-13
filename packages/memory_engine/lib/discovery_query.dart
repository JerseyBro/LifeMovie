import 'package:memory_domain/memory_domain.dart';

import 'memory_engine.dart';

/// Applies [MemoryDiscoveryQuery] to ranked candidates. Pure and offline:
/// filtering runs over candidate metadata plus the already-indexed assets,
/// never over the raw photo library (Discovery benchmark contract).
class DiscoveryQueryEngine {
  const DiscoveryQueryEngine();

  List<MemoryCandidate> filter(
    MemoryDiscoveryQuery query,
    List<MemoryCandidate> candidates,
    MemoryContext context,
  ) {
    if (query.isDefault && query.sort == DiscoverySortMode.recommended) {
      return candidates;
    }
    return candidates
        .where(
          (candidate) => query.matchesCandidate(candidate, context.assetsById),
        )
        .toList(growable: false);
  }

  List<MemoryCandidate> sort(
    MemoryDiscoveryQuery query,
    List<MemoryCandidate> candidates,
    MemoryContext context,
  ) {
    final sorted = [...candidates];
    switch (query.sort) {
      case DiscoverySortMode.recommended:
        // Input order is already the ranking order; never re-rank here.
        break;
      case DiscoverySortMode.newest:
        sorted.sort((a, b) => b.period.start.compareTo(a.period.start));
      case DiscoverySortMode.oldest:
        sorted.sort((a, b) => a.period.start.compareTo(b.period.start));
      case DiscoverySortMode.mostPhotos:
        sorted.sort((a, b) => b.mediaIds.length.compareTo(a.mediaIds.length));
    }
    return sorted;
  }

  List<MemoryCandidate> apply(
    MemoryDiscoveryQuery query,
    List<MemoryCandidate> candidates,
    MemoryContext context,
  ) {
    final filtered = filter(query, candidates, context);
    if (query.sort == DiscoverySortMode.recommended) return filtered;
    return sort(query, filtered, context);
  }
}

/// Explore dimensions for the Discovery Home. Every section reports whether
/// it has real data; empty sections must not be rendered by the UI.
class DiscoveryDimensionIndex {
  const DiscoveryDimensionIndex({this.minimumPlaceAssets = 3});

  final int minimumPlaceAssets;

  DiscoveryDimensionSummary summarize({
    required List<MemoryCandidate> candidates,
    required List<MediaAsset> assets,
  }) {
    final years = <int, int>{};
    for (final asset in assets) {
      final year = asset.creationDate?.year;
      if (year != null) years[year] = (years[year] ?? 0) + 1;
    }

    final places = <DiscoveryPlaceSummary>[];
    for (final entry in groupAssetsByPlaceCluster(assets).entries) {
      final clusterAssets = entry.value;
      if (clusterAssets.length < minimumPlaceAssets) continue;
      final center = _centerOf(clusterAssets);
      if (center == null) continue;
      final locatedYears =
          clusterAssets
              .map((a) => a.creationDate?.year)
              .whereType<int>()
              .toSet()
              .toList()
            ..sort();
      places.add(
        DiscoveryPlaceSummary(
          placeId: entry.key,
          center: center,
          assetCount: clusterAssets.length,
          coverAssetId: _coverAsset(clusterAssets)?.id,
          firstYear: locatedYears.isEmpty ? null : locatedYears.first,
          lastYear: locatedYears.isEmpty ? null : locatedYears.last,
        ),
      );
    }
    places.sort((a, b) => b.assetCount.compareTo(a.assetCount));

    final people = <DiscoveryPersonSummary>[];
    final byPerson = <String, List<MediaAsset>>{};
    for (final asset in assets) {
      for (final personId in asset.personIds) {
        (byPerson[personId] ??= []).add(asset);
      }
    }
    for (final entry in byPerson.entries) {
      final personAssets = entry.value..sort(_byCreationDate);
      if (personAssets.length < 3) continue;
      people.add(
        DiscoveryPersonSummary(
          personId: entry.key,
          assetCount: personAssets.length,
          coverAssetId: personAssets.first.id,
        ),
      );
    }
    people.sort((a, b) => b.assetCount.compareTo(a.assetCount));

    final recent = [...candidates]
      ..sort((a, b) => b.period.end.compareTo(a.period.end));

    return DiscoveryDimensionSummary(
      years: Map.fromEntries(
        years.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
      ),
      places: places,
      people: people,
      trips: candidates
          .where((c) => c.type == MemoryCandidateType.travelStory)
          .toList(growable: false),
      firstMemories: candidates
          .where((c) => c.type == MemoryCandidateType.firstMemory)
          .toList(growable: false),
      annualTogether: candidates
          .where((c) => c.type == MemoryCandidateType.annualTogether)
          .toList(growable: false),
      evolutions: candidates
          .where((c) => c.type == MemoryCandidateType.longTermEvolution)
          .toList(growable: false),
      recentDiscoveries: recent.take(5).toList(growable: false),
      hasPersonData: byPerson.isNotEmpty,
    );
  }

  static MediaAsset? _coverAsset(List<MediaAsset> assets) {
    final favorite = assets.where((a) => a.isFavorite).toList();
    final pool = favorite.isNotEmpty ? favorite : assets;
    return pool.isEmpty ? null : pool.first;
  }

  static GeoPoint? _centerOf(List<MediaAsset> assets) {
    for (final asset in assets) {
      final location = asset.location;
      if (location != null) return location;
    }
    return null;
  }

  static int _byCreationDate(MediaAsset a, MediaAsset b) {
    final ad = a.creationDate;
    final bd = b.creationDate;
    if (ad == null || bd == null) return 0;
    return ad.compareTo(bd);
  }
}

class DiscoveryPlaceSummary {
  const DiscoveryPlaceSummary({
    required this.placeId,
    required this.center,
    required this.assetCount,
    this.coverAssetId,
    this.firstYear,
    this.lastYear,
  });

  final String placeId;
  final GeoPoint center;
  final int assetCount;
  final String? coverAssetId;
  final int? firstYear;
  final int? lastYear;
}

class DiscoveryPersonSummary {
  const DiscoveryPersonSummary({
    required this.personId,
    required this.assetCount,
    this.coverAssetId,
  });

  final String personId;
  final int assetCount;
  final String? coverAssetId;
}

class DiscoveryDimensionSummary {
  const DiscoveryDimensionSummary({
    required this.years,
    required this.places,
    required this.people,
    required this.trips,
    required this.firstMemories,
    required this.annualTogether,
    required this.evolutions,
    required this.recentDiscoveries,
    required this.hasPersonData,
  });

  /// year -> asset count, newest first.
  final Map<int, int> years;
  final List<DiscoveryPlaceSummary> places;
  final List<DiscoveryPersonSummary> people;
  final List<MemoryCandidate> trips;
  final List<MemoryCandidate> firstMemories;
  final List<MemoryCandidate> annualTogether;
  final List<MemoryCandidate> evolutions;
  final List<MemoryCandidate> recentDiscoveries;

  /// People sections render only when reliable person grouping exists.
  final bool hasPersonData;
}

/// Local metadata search over memories (Discovery benchmark: deterministic
/// V1, future-proof interface for semantic search).
///
/// Token semantics:
///   - "2024"          -> year dimension
///   - "旅行"/"trip"... -> memory type
///   - any other text  -> contains-match on [textOf] (title/summary)
/// Multiple tokens AND together.
class DiscoverySearchService {
  const DiscoverySearchService();

  static const _typeKeywords = <String, MemoryCandidateType>{
    '旅行': MemoryCandidateType.travelStory,
    '旅途': MemoryCandidateType.travelStory,
    'trip': MemoryCandidateType.travelStory,
    'travel': MemoryCandidateType.travelStory,
    '年度': MemoryCandidateType.yearRecap,
    '年回顾': MemoryCandidateType.yearRecap,
    'year': MemoryCandidateType.yearRecap,
    '人物': MemoryCandidateType.personTimeline,
    'person': MemoryCandidateType.personTimeline,
    '初见': MemoryCandidateType.firstMemory,
    '第一次': MemoryCandidateType.firstMemory,
    'first': MemoryCandidateType.firstMemory,
    '每年': MemoryCandidateType.annualTogether,
    '相聚': MemoryCandidateType.annualTogether,
    '变化': MemoryCandidateType.longTermEvolution,
    '成长': MemoryCandidateType.longTermEvolution,
    '聚会': MemoryCandidateType.dateCluster,
    '地点': MemoryCandidateType.samePlace,
    '故地': MemoryCandidateType.samePlaceAcrossYears,
    '重游': MemoryCandidateType.samePlaceAcrossYears,
  };

  List<MemoryCandidate> search({
    required String query,
    required List<MemoryCandidate> candidates,
    required MemoryContext context,
    String Function(MemoryCandidate candidate)? textOf,
  }) {
    final tokens = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) return candidates;

    return candidates
        .where((candidate) {
          for (final token in tokens) {
            final year = int.tryParse(token);
            if (year != null && token.length == 4) {
              if (!_matchesYear(candidate, context, year)) return false;
              continue;
            }
            final type = _typeKeywords[token];
            if (type != null) {
              if (candidate.type != type) return false;
              continue;
            }
            final text = textOf?.call(candidate).toLowerCase() ?? '';
            if (!_matchesPlainText(candidate, context, text, token)) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);
  }

  bool _matchesYear(
    MemoryCandidate candidate,
    MemoryContext context,
    int year,
  ) {
    final start = candidate.period.start.year;
    final end = candidate.period.end.year;
    if (year >= start && year <= end) return true;
    for (final id in candidate.mediaIds) {
      final assetYear = context.assetsById[id]?.creationDate?.year;
      if (assetYear == year) return true;
    }
    return false;
  }

  bool _matchesPlainText(
    MemoryCandidate candidate,
    MemoryContext context,
    String text,
    String token,
  ) {
    if (text.isNotEmpty && text.contains(token)) return true;
    // Place id tokens (e.g. cluster ids) rarely typed; keep text-only.
    return false;
  }
}
