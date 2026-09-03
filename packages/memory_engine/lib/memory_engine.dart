library;

// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:memory_domain/memory_domain.dart';

class MemoryContext {
  MemoryContext({required this.assets})
    : assetsById = {for (final asset in assets) asset.id: asset};

  final List<MediaAsset> assets;
  final Map<String, MediaAsset> assetsById;

  List<MediaAsset> mediaFor(MemoryCandidate candidate) => candidate.mediaIds
      .map((id) => assetsById[id])
      .whereType<MediaAsset>()
      .toList(growable: false);
}

class MemoryFailure implements Exception {
  const MemoryFailure(this.code, this.message, [this.cause]);
  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'MemoryFailure($code): $message';
}

abstract interface class MemoryRule {
  Future<List<MemoryCandidate>> discover(MemoryContext context);
}

// ---------------------------------------------------------------------------
// Year semantics helper — P0-1
// ---------------------------------------------------------------------------

class YearMetrics {
  const YearMetrics({
    required this.distinctYearCount,
    required this.calendarSpanYears,
    required this.longestConsecutiveYearRun,
    required this.firstYear,
    required this.lastYear,
    required this.years,
  });

  final int distinctYearCount;
  final int calendarSpanYears;
  final int longestConsecutiveYearRun;
  final int firstYear;
  final int lastYear;
  final List<int> years;

  static YearMetrics? fromAssets(Iterable<MediaAsset> assets) {
    final years = _yearSet(assets);
    if (years.isEmpty) return null;
    final distinct = years.length;
    final first = years.first;
    final last = years.last;
    final span = last - first + 1;
    var longest = 1;
    var current = 1;
    for (var i = 1; i < years.length; i++) {
      if (years[i] == years[i - 1] + 1) {
        current += 1;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return YearMetrics(
      distinctYearCount: distinct,
      calendarSpanYears: span,
      longestConsecutiveYearRun: longest,
      firstYear: first,
      lastYear: last,
      years: years,
    );
  }

  static YearMetrics? fromYears(List<int> years) {
    if (years.isEmpty) return null;
    final sorted = [...years]..sort();
    final distinct = sorted.toSet().toList()..sort();
    final first = distinct.first;
    final last = distinct.last;
    final span = last - first + 1;
    var longest = 1;
    var current = 1;
    for (var i = 1; i < distinct.length; i++) {
      if (distinct[i] == distinct[i - 1] + 1) {
        current += 1;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return YearMetrics(
      distinctYearCount: distinct.length,
      calendarSpanYears: span,
      longestConsecutiveYearRun: longest,
      firstYear: first,
      lastYear: last,
      years: distinct,
    );
  }
}

// ---------------------------------------------------------------------------
// Location clustering — P0-2
// ---------------------------------------------------------------------------

class LocationClusterConfig {
  const LocationClusterConfig({
    this.radiusMeters = 500,
    this.minimumAssets = 3,
  });

  final double radiusMeters;
  final int minimumAssets;
}

class _LocationCluster {
  _LocationCluster({
    required this.id,
    required this.center,
    required this.radiusMeters,
  }) : assets = [];
  final String id;
  final GeoPoint center;
  final double radiusMeters;
  final List<MediaAsset> assets;
}

String _cellKey(GeoPoint p, double cellSizeDeg) {
  final latCell = (p.latitude / cellSizeDeg).floor();
  final lonCell = (p.longitude / cellSizeDeg).floor();
  return '$latCell,$lonCell';
}

Map<String, List<MediaAsset>> _groupByPlaceCluster(
  Iterable<MediaAsset> assets,
  LocationClusterConfig config,
) {
  final clusters = _buildLocationClusters(assets, config);
  final result = <String, List<MediaAsset>>{};
  for (final c in clusters) {
    result[c.id] = c.assets;
  }
  return result;
}

List<_LocationCluster> _buildLocationClusters(
  Iterable<MediaAsset> assets,
  LocationClusterConfig config,
) {
  final dated = _dated(assets.where((a) => a.location != null).toList());
  if (dated.isEmpty) return const [];
  final radiusKm = config.radiusMeters / 1000.0;
  // cell size approx = radius in degrees, lat ~111km per degree
  final cellSizeDeg = config.radiusMeters / 111000.0;
  final effectiveCellSize = cellSizeDeg <= 0 ? 0.0045 : cellSizeDeg;
  final clusters = <_LocationCluster>[];
  final bucketMap = <String, List<int>>{}; // bucketKey -> cluster indices

  for (final asset in dated) {
    final point = asset.location!;
    final bucketLat = (point.latitude / effectiveCellSize).floor();
    final bucketLon = (point.longitude / effectiveCellSize).floor();
    _LocationCluster? best;
    var bestDist = double.infinity;
    // Latitude-aware neighbor search: lon degrees shrink with cos(lat)
    final latRad = _radians(point.latitude);
    final cosLat = math.cos(latRad).abs().clamp(0.01, 1.0);
    final lonDeltaDeg = config.radiusMeters / (111000 * cosLat);
    final latDeltaDeg = config.radiusMeters / 111000;
    final latCells = (latDeltaDeg / effectiveCellSize).ceil().clamp(1, 2);
    final lonCells = (lonDeltaDeg / effectiveCellSize).ceil().clamp(1, 10);
    for (var dLat = -latCells; dLat <= latCells; dLat++) {
      for (var dLon = -lonCells; dLon <= lonCells; dLon++) {
        final key = '${bucketLat + dLat},${bucketLon + dLon}';
        final indices = bucketMap[key];
        if (indices == null) continue;
        for (final idx in indices) {
          final cluster = clusters[idx];
          final dist = _distanceKm(cluster.center, point);
          if (dist <= radiusKm && dist < bestDist) {
            best = cluster;
            bestDist = dist;
          }
        }
      }
    }
    if (best != null) {
      best.assets.add(asset);
    } else {
      final id = 'cluster-${clusters.length}';
      final cluster = _LocationCluster(
        id: id,
        center: point,
        radiusMeters: config.radiusMeters,
      );
      cluster.assets.add(asset);
      final idx = clusters.length;
      clusters.add(cluster);
      final key = _cellKey(point, effectiveCellSize);
      (bucketMap[key] ??= []).add(idx);
    }
  }
  return clusters;
}

// ---------------------------------------------------------------------------
// Configs
// ---------------------------------------------------------------------------

class MemoryIntelligenceConfig {
  const MemoryIntelligenceConfig({
    this.samePlaceAcrossYears = const SamePlaceAcrossYearsRuleConfig(),
    this.firstMemory = const FirstMemoryRuleConfig(),
    this.travelStory = const TravelStoryRuleConfig(),
    this.personTimeline = const PersonTimelineRuleConfig(),
    this.annualTogether = const AnnualTogetherRuleConfig(),
    this.longTermEvolution = const LongTermEvolutionRuleConfig(),
    this.rankingWeights = const MemoryRankingWeights(),
    this.locationCluster = const LocationClusterConfig(),
  });

  final SamePlaceAcrossYearsRuleConfig samePlaceAcrossYears;
  final FirstMemoryRuleConfig firstMemory;
  final TravelStoryRuleConfig travelStory;
  final PersonTimelineRuleConfig personTimeline;
  final AnnualTogetherRuleConfig annualTogether;
  final LongTermEvolutionRuleConfig longTermEvolution;
  final MemoryRankingWeights rankingWeights;
  final LocationClusterConfig locationCluster;
}

class DateClusterRule implements MemoryRule {
  const DateClusterRule({
    this.maxGap = const Duration(days: 2),
    this.minimumAssets = 3,
  });
  final Duration maxGap;
  final int minimumAssets;

  @override
  Future<List<MemoryCandidate>> discover(MemoryContext context) async {
    final dated = _dated(context.assets);
    final result = <MemoryCandidate>[];
    var cluster = <MediaAsset>[];
    for (final asset in dated) {
      if (cluster.isNotEmpty &&
          asset.creationDate!.difference(cluster.last.creationDate!) > maxGap) {
        if (cluster.length >= minimumAssets) result.add(_candidate(cluster));
        cluster = [];
      }
      cluster.add(asset);
    }
    if (cluster.length >= minimumAssets) result.add(_candidate(cluster));
    return result;
  }

  MemoryCandidate _candidate(List<MediaAsset> assets) => MemoryCandidate(
    id: 'date-${assets.first.id}',
    type: MemoryCandidateType.dateCluster,
    period: _periodFor(assets),
    mediaIds: assets.map((a) => a.id).toList(growable: false),
    representativeMediaIds: RepresentativeMediaSelector.selectIds(assets),
    reasons: [
      'dense_activity:${assets.length}',
      'short_time_window:${assets.first.creationDate!.toIso8601String()}',
      'video_count:${_videoCount(assets)}',
    ],
    safeTitleTemplate: '这几天留下了很多照片。',
    safeSubtitleTemplate: '${assets.length} 个媒体项目',
  );
}

class SamePlaceRule implements MemoryRule {
  const SamePlaceRule({
    this.minimumAssets = 3,
    this.clusterConfig = const LocationClusterConfig(),
    @Deprecated('Use clusterConfig') this.precision = 1,
    this.maxSessionGap = const Duration(days: 14),
  });

  final int minimumAssets;
  final LocationClusterConfig clusterConfig;
  @Deprecated('Use clusterConfig.radiusMeters')
  final int precision;
  final Duration maxSessionGap;

  @override
  Future<List<MemoryCandidate>> discover(MemoryContext context) async {
    final candidates = <MemoryCandidate>[];
    for (final entry in _groupByPlaceCluster(
      context.assets,
      clusterConfig,
    ).entries) {
      for (final session in _sessions(entry.value, maxSessionGap)) {
        if (session.length < minimumAssets) continue;
        candidates.add(
          MemoryCandidate(
            id: 'place-${entry.key}-${session.first.id}',
            type: MemoryCandidateType.samePlace,
            period: _periodFor(session),
            mediaIds: session.map((a) => a.id).toList(growable: false),
            placeIds: [entry.key],
            representativeMediaIds: RepresentativeMediaSelector.selectIds(
              session,
            ),
            reasons: [
              'place_session_assets:${session.length}',
              'session_gap_days:${maxSessionGap.inDays}',
            ],
            safeTitleTemplate: '这里有一段值得回看的记忆。',
            safeSubtitleTemplate: '${session.length} 张照片和视频',
          ),
        );
      }
    }
    return candidates;
  }
}

class YearRecapRule implements MemoryRule {
  const YearRecapRule({this.minimumAssets = 1});
  final int minimumAssets;

  @override
  Future<List<MemoryCandidate>> discover(MemoryContext context) async {
    final groups = <int, List<MediaAsset>>{};
    for (final asset in context.assets) {
      final date = asset.creationDate;
      if (date != null) (groups[date.year] ??= []).add(asset);
    }
    return groups.entries
        .where((e) => e.value.length >= minimumAssets)
        .map((e) {
          final assets = _dated(e.value);
          return MemoryCandidate(
            id: 'year-${e.key}',
            type: MemoryCandidateType.yearRecap,
            period: DateTimeRange(
              DateTime(e.key),
              DateTime(e.key, 12, 31, 23, 59, 59),
            ),
            mediaIds: assets.map((a) => a.id).toList(growable: false),
            representativeMediaIds: RepresentativeMediaSelector.selectIds(
              assets,
            ),
            metadata: {'year': e.key, 'mediaCount': assets.length},
            reasons: ['year_recap_assets:${assets.length}'],
            safeTitleTemplate: '${e.key} 年，有很多值得回看的片段。',
            safeSubtitleTemplate: '${assets.length} 张照片和视频',
          );
        })
        .toList(growable: false);
  }
}

class PersonTimelineRuleConfig {
  const PersonTimelineRuleConfig({
    this.minimumAssets = 3,
    this.minimumYears = 2,
  });

  final int minimumAssets;
  final int minimumYears;
}

class PersonTimelineRule implements MemoryRule {
  const PersonTimelineRule({PersonTimelineRuleConfig? config})
    : config = config ?? const PersonTimelineRuleConfig();

  final PersonTimelineRuleConfig config;

  @override
  Future<List<MemoryCandidate>> discover(MemoryContext context) async {
    final groups = <String, List<MediaAsset>>{};
    for (final asset in context.assets) {
      for (final personId in asset.personIds) {
        (groups[personId] ??= []).add(asset);
      }
    }

    final candidates = <MemoryCandidate>[];
    for (final entry in groups.entries) {
      final assets = _dated(entry.value);
      final metrics = YearMetrics.fromAssets(assets);
      if (metrics == null) continue;
      if (assets.length < config.minimumAssets ||
          metrics.distinctYearCount < config.minimumYears) {
        continue;
      }
      final distribution = _yearDistribution(assets);
      // Accurate copy: use firstYear and calendarSpan
      final title = '这个人从 ${metrics.firstYear} 年开始出现在你的镜头里。';
      final subtitle =
          '${metrics.firstYear} — ${metrics.lastYear} · 跨越 ${metrics.calendarSpanYears} 年 · ${assets.length} 张照片和视频';
      candidates.add(
        MemoryCandidate(
          id: 'person-${entry.key}',
          type: MemoryCandidateType.personTimeline,
          period: _periodFor(assets),
          mediaIds: assets.map((a) => a.id).toList(growable: false),
          personIds: [entry.key],
          representativeMediaIds: RepresentativeMediaSelector.selectIds(assets),
          metadata: {
            'personId': entry.key,
            'firstSeen': assets.first.creationDate!.toIso8601String(),
            'lastSeen': assets.last.creationDate!.toIso8601String(),
            'distinctYearCount': metrics.distinctYearCount,
            'calendarSpanYears': metrics.calendarSpanYears,
            'longestConsecutiveYearRun': metrics.longestConsecutiveYearRun,
            'firstYear': metrics.firstYear,
            'lastYear': metrics.lastYear,
            'mediaCount': assets.length,
            'yearDistribution': distribution,
            // legacy keys for compat
            'yearSpan': metrics.distinctYearCount,
          },
          reasons: [
            'person_distinct_years:${metrics.distinctYearCount}',
            'person_calendar_span:${metrics.calendarSpanYears}',
            'person_media_count:${assets.length}',
          ],
          safeTitleTemplate: title,
          safeSubtitleTemplate: subtitle,
        ),
      );
    }
    return candidates;
  }
}

class SamePlaceAcrossYearsRuleConfig {
  const SamePlaceAcrossYearsRuleConfig({
    this.minimumYearCount = 3,
    this.minimumVisitCount = 3,
    this.clusterConfig = const LocationClusterConfig(radiusMeters: 500),
    @Deprecated('Use clusterConfig') this.locationPrecision = 1,
    this.sessionGap = const Duration(days: 21),
    this.routineVisitThreshold = 16,
    this.routineMonthThreshold = 9,
  });

  final int minimumYearCount;
  final int minimumVisitCount;
  final LocationClusterConfig clusterConfig;
  @Deprecated('Use clusterConfig')
  final int locationPrecision;
  final Duration sessionGap;
  final int routineVisitThreshold;
  final int routineMonthThreshold;
}

class SamePlaceAcrossYearsRule implements MemoryRule {
  const SamePlaceAcrossYearsRule({SamePlaceAcrossYearsRuleConfig? config})
    : config = config ?? const SamePlaceAcrossYearsRuleConfig();

  final SamePlaceAcrossYearsRuleConfig config;

  @override
  Future<List<MemoryCandidate>> discover(MemoryContext context) async {
    final candidates = <MemoryCandidate>[];
    for (final entry in _groupByPlaceCluster(
      context.assets,
      config.clusterConfig,
    ).entries) {
      final assets = _dated(entry.value);
      if (assets.isEmpty) continue;
      final visits = _sessions(
        assets,
        config.sessionGap,
      ).where((session) => session.length >= 2).toList(growable: false);
      final metrics = YearMetrics.fromAssets(assets);
      if (metrics == null) continue;
      if (metrics.distinctYearCount < config.minimumYearCount ||
          visits.length < config.minimumVisitCount) {
        continue;
      }

      final months = assets
          .map((asset) => asset.creationDate)
          .whereType<DateTime>()
          .map((date) => '${date.year}-${date.month}')
          .toSet()
          .length;
      final routinePenalty =
          visits.length >= config.routineVisitThreshold ||
          months >= config.routineMonthThreshold;
      final selected = RepresentativeMediaSelector.selectIds(
        assets,
        maxCount: 8,
      );
      final canSayConsecutive = metrics.longestConsecutiveYearRun >= 3;
      final title = canSayConsecutive
          ? '你已经连续 ${metrics.longestConsecutiveYearRun} 年来到这里。'
          : metrics.distinctYearCount >= 3
          ? '这个地方在 ${metrics.distinctYearCount} 个不同年份出现在你的相册里。'
          : '这些年，你已经多次回到这里。';
      final subtitle = canSayConsecutive
          ? '${metrics.firstYear} — ${metrics.lastYear} · ${visits.length} 次到访 · 连续 ${metrics.longestConsecutiveYearRun} 年'
          : '${metrics.firstYear} — ${metrics.lastYear} · ${visits.length} 次到访 · ${metrics.distinctYearCount} 个年份';
      candidates.add(
        MemoryCandidate(
          id: 'place-years-${entry.key}',
          type: MemoryCandidateType.samePlaceAcrossYears,
          period: _periodFor(assets),
          mediaIds: assets.map((a) => a.id).toList(growable: false),
          placeIds: [entry.key],
          representativeMediaIds: selected,
          metadata: {
            'placeClusterId': entry.key,
            'distinctYearCount': metrics.distinctYearCount,
            'calendarSpanYears': metrics.calendarSpanYears,
            'longestConsecutiveYearRun': metrics.longestConsecutiveYearRun,
            'firstYear': metrics.firstYear,
            'lastYear': metrics.lastYear,
            'yearCount': metrics.distinctYearCount,
            'visitCount': visits.length,
            'routinePlacePenalty': routinePenalty,
            'monthCoverage': months,
          },
          reasons: [
            'appears_across_years:${metrics.distinctYearCount}',
            'calendar_span:${metrics.calendarSpanYears}',
            'longest_consecutive:${metrics.longestConsecutiveYearRun}',
            'independent_visits:${visits.length}',
            if (routinePenalty) 'routine_place_penalty:true',
            if (!routinePenalty) 'routine_place_penalty:false',
          ],
          safeTitleTemplate: title,
          safeSubtitleTemplate: subtitle,
        ),
      );
    }
    return candidates;
  }
}

class FirstMemoryRuleConfig {
  const FirstMemoryRuleConfig({
    this.minimumAssets = 2,
    this.clusterConfig = const LocationClusterConfig(radiusMeters: 500),
    @Deprecated('Use clusterConfig') this.locationPrecision = 1,
    this.firstWindow = const Duration(days: 2),
  });

  final int minimumAssets;
  final LocationClusterConfig clusterConfig;
  @Deprecated('Use clusterConfig')
  final int locationPrecision;
  final Duration firstWindow;
}

class FirstMemoryRule implements MemoryRule {
  const FirstMemoryRule({FirstMemoryRuleConfig? config})
    : config = config ?? const FirstMemoryRuleConfig();

  final FirstMemoryRuleConfig config;

  @override
  Future<List<MemoryCandidate>> discover(MemoryContext context) async {
    final candidates = <MemoryCandidate>[];
    final personGroups = <String, List<MediaAsset>>{};
    for (final asset in context.assets) {
      for (final personId in asset.personIds) {
        (personGroups[personId] ??= []).add(asset);
      }
    }
    for (final entry in personGroups.entries) {
      final first = _firstWindow(_dated(entry.value), config.firstWindow);
      if (first.length < config.minimumAssets) continue;
      candidates.add(
        MemoryCandidate(
          id: 'first-person-${entry.key}-${first.first.id}',
          type: MemoryCandidateType.firstMemory,
          period: _periodFor(first),
          mediaIds: first.map((a) => a.id).toList(growable: false),
          personIds: [entry.key],
          representativeMediaIds: RepresentativeMediaSelector.selectIds(first),
          metadata: {'firstMemoryKind': 'person', 'personId': entry.key},
          reasons: ['earliest_person_media_in_library:${first.length}'],
          safeTitleTemplate: '这是相册里最早的一组你们合照。',
          safeSubtitleTemplate: '${first.first.creationDate!.year} · 相册记录',
        ),
      );
    }

    for (final entry in _groupByPlaceCluster(
      context.assets,
      config.clusterConfig,
    ).entries) {
      final first = _firstWindow(_dated(entry.value), config.firstWindow);
      if (first.length < config.minimumAssets) continue;
      candidates.add(
        MemoryCandidate(
          id: 'first-place-${entry.key}-${first.first.id}',
          type: MemoryCandidateType.firstMemory,
          period: _periodFor(first),
          mediaIds: first.map((a) => a.id).toList(growable: false),
          placeIds: [entry.key],
          representativeMediaIds: RepresentativeMediaSelector.selectIds(first),
          metadata: {'firstMemoryKind': 'place', 'placeClusterId': entry.key},
          reasons: ['earliest_place_media_in_library:${first.length}'],
          safeTitleTemplate: '这是相册里最早记录这个地方的一组照片。',
          safeSubtitleTemplate: '${first.first.creationDate!.year} · 相册记录',
        ),
      );
    }
    return candidates;
  }
}

class TravelStoryRuleConfig {
  const TravelStoryRuleConfig({
    this.minimumAssets = 12,
    this.minimumDays = 3,
    this.minimumPlaceCount = 3,
    this.maxGap = const Duration(days: 2),
    this.clusterConfig = const LocationClusterConfig(radiusMeters: 500),
    @Deprecated('Use clusterConfig') this.locationPrecision = 1,
  });

  final int minimumAssets;
  final int minimumDays;
  final int minimumPlaceCount;
  final Duration maxGap;
  final LocationClusterConfig clusterConfig;
  @Deprecated('Use clusterConfig')
  final int locationPrecision;
}

class TravelStoryRule implements MemoryRule {
  const TravelStoryRule({TravelStoryRuleConfig? config})
    : config = config ?? const TravelStoryRuleConfig();

  final TravelStoryRuleConfig config;

  @override
  Future<List<MemoryCandidate>> discover(MemoryContext context) async {
    final located = _dated(
      context.assets.where((asset) => asset.location != null).toList(),
    );
    final segments = <List<MediaAsset>>[];
    var current = <MediaAsset>[];
    for (final asset in located) {
      final previous = current.isEmpty ? null : current.last.creationDate;
      if (previous != null &&
          asset.creationDate!.difference(previous) > config.maxGap) {
        segments.add(current);
        current = [];
      }
      current.add(asset);
    }
    if (current.isNotEmpty) segments.add(current);

    final candidates = <MemoryCandidate>[];
    for (final segment in segments) {
      final places = _groupByPlaceCluster(segment, config.clusterConfig).keys;
      // detection phase uses located segment only for days/place count
      final detectionDays = math.max(
        1,
        _periodFor(segment).duration.inDays + 1,
      );
      final distanceKm = _routeDistanceKm(segment);
      // need at least movement: we keep existing thresholds but based on located segment
      if (segment.length < 3) continue; // need some located to define window
      if (detectionDays < config.minimumDays ||
          places.length < config.minimumPlaceCount) {
        continue;
      }
      // Phase B: enrich with ALL assets in date window
      final window = _periodFor(segment);
      final enriched = context.assets
          .where((a) {
            final d = a.creationDate;
            if (d == null) return false;
            return !d.isBefore(window.start) && !d.isAfter(window.end);
          })
          .toList(growable: false);
      final enrichedDated = _dated(enriched);
      if (enrichedDated.isEmpty) continue;
      final totalDays = math.max(
        1,
        _periodFor(enrichedDated).duration.inDays + 1,
      );
      if (enrichedDated.length < config.minimumAssets ||
          totalDays < config.minimumDays) {
        continue;
      }
      final locatedCount = segment.length;
      final totalCount = enrichedDated.length;
      final locationCoverage = totalCount == 0
          ? 0.0
          : locatedCount / totalCount;
      final videoCount = _videoCount(enrichedDated);
      candidates.add(
        MemoryCandidate(
          id: 'travel-${segment.first.id}-${segment.last.id}',
          type: MemoryCandidateType.travelStory,
          period: _periodFor(enrichedDated),
          mediaIds: enrichedDated.map((a) => a.id).toList(growable: false),
          placeIds: places.toList(growable: false),
          representativeMediaIds: RepresentativeMediaSelector.selectIds(
            enrichedDated,
            maxCount: 10,
          ),
          metadata: {
            'durationDays': totalDays,
            'placeCount': places.length,
            'mediaCount': totalCount,
            'locatedMediaCount': locatedCount,
            'totalMediaCount': totalCount,
            'locationCoverage': locationCoverage,
            'videoCount': videoCount,
            'routeDistanceKm': distanceKm.round(),
          },
          reasons: [
            'travel_duration_days:$totalDays',
            'travel_place_count:${places.length}',
            'travel_distance_km:${distanceKm.round()}',
            'travel_video_count:$videoCount',
            'travel_located:$locatedCount',
            'travel_coverage:${locationCoverage.toStringAsFixed(2)}',
          ],
          safeTitleTemplate: '这 $totalDays 天，看起来像一段完整的旅程。',
          safeSubtitleTemplate: '${places.length} 个地点 · $totalCount 张照片和视频',
        ),
      );
    }
    return candidates;
  }
}

class AnnualTogetherRuleConfig {
  const AnnualTogetherRuleConfig({
    this.minimumAssets = 2,
    this.minimumYearCount = 3,
    this.windowDays = 24,
  });

  final int minimumAssets;
  final int minimumYearCount;
  final int windowDays;
}

class AnnualTogetherRule implements MemoryRule {
  const AnnualTogetherRule({AnnualTogetherRuleConfig? config})
    : config = config ?? const AnnualTogetherRuleConfig();

  final AnnualTogetherRuleConfig config;

  @override
  Future<List<MemoryCandidate>> discover(MemoryContext context) async {
    // Group by person, then cluster by circular day-of-year distance
    final byPerson = <String, List<MediaAsset>>{};
    for (final asset in context.assets) {
      final date = asset.creationDate;
      if (date == null || asset.personIds.isEmpty) continue;
      for (final personId in asset.personIds) {
        (byPerson[personId] ??= []).add(asset);
      }
    }

    final candidates = <MemoryCandidate>[];
    for (final entry in byPerson.entries) {
      final personId = entry.key;
      final assets = _dated(entry.value);
      if (assets.length < config.minimumAssets) continue;
      final clusters = _clusterByAnnualWindow(assets, config.windowDays);
      for (final cluster in clusters) {
        final clusterAssets = _dated(cluster);
        final metrics = YearMetrics.fromAssets(clusterAssets);
        if (metrics == null) continue;
        if (clusterAssets.length < config.minimumAssets ||
            metrics.distinctYearCount < config.minimumYearCount) {
          continue;
        }
        final centerDoy = _dayOfYear(clusterAssets.first.creationDate!);
        final windowLabel = 'doy-$centerDoy';
        final isConsecutive = metrics.longestConsecutiveYearRun >= 3;
        final title = isConsecutive
            ? '每年差不多这个时候，这个人都会出现在你的照片里。'
            : '这些年，差不多这个时候，这个人多次出现在你的照片里。';
        final subtitle = isConsecutive
            ? '${metrics.firstYear} — ${metrics.lastYear} · 连续 ${metrics.longestConsecutiveYearRun} 年'
            : '${metrics.firstYear} — ${metrics.lastYear} · ${metrics.distinctYearCount} 年';
        candidates.add(
          MemoryCandidate(
            id: 'annual-$personId@$windowLabel-${metrics.firstYear}',
            type: MemoryCandidateType.annualTogether,
            period: _periodFor(clusterAssets),
            mediaIds: clusterAssets.map((a) => a.id).toList(growable: false),
            personIds: [personId],
            representativeMediaIds: RepresentativeMediaSelector.selectIds(
              clusterAssets,
            ),
            metadata: {
              'personId': personId,
              'distinctYearCount': metrics.distinctYearCount,
              'calendarSpanYears': metrics.calendarSpanYears,
              'longestConsecutiveYearRun': metrics.longestConsecutiveYearRun,
              'firstYear': metrics.firstYear,
              'lastYear': metrics.lastYear,
              'yearCount': metrics.distinctYearCount,
              'yearDistribution': _yearDistribution(clusterAssets),
              'annualWindow': windowLabel,
              'windowDays': config.windowDays,
            },
            reasons: [
              'annual_person_recurrence:${metrics.distinctYearCount}',
              'annual_longest_consecutive:${metrics.longestConsecutiveYearRun}',
              'annual_window:$windowLabel',
            ],
            safeTitleTemplate: title,
            safeSubtitleTemplate: subtitle,
          ),
        );
      }
    }
    return candidates;
  }
}

List<List<MediaAsset>> _clusterByAnnualWindow(
  List<MediaAsset> sortedAssets,
  int windowDays,
) {
  if (sortedAssets.isEmpty) return const [];
  // Build clusters by circular day-of-year distance <= windowDays (single-link)
  // Approach: sort by dayOfYear, then greedy
  final withDoy = sortedAssets
      .map((a) => (asset: a, doy: _dayOfYear(a.creationDate!)))
      .toList();
  withDoy.sort((a, b) => a.doy.compareTo(b.doy));

  final clusters = <List<MediaAsset>>[];
  List<MediaAsset> current = [];
  var currentBaseDoy = withDoy.first.doy;

  for (final item in withDoy) {
    if (current.isEmpty) {
      current = [item.asset];
      currentBaseDoy = item.doy;
      continue;
    }
    final dist = _circularDayDistance(item.doy, currentBaseDoy);
    // Also check distance to last item in current for chain effect
    final lastDoy = _dayOfYear(current.last.creationDate!);
    final distToLast = _circularDayDistance(item.doy, lastDoy);
    // If close to base or close to last, same cluster
    if (dist <= windowDays || distToLast <= windowDays) {
      current.add(item.asset);
      // keep base as first; optionally update but keep stable
    } else {
      clusters.add(current);
      current = [item.asset];
      currentBaseDoy = item.doy;
    }
  }
  if (current.isNotEmpty) clusters.add(current);

  // Handle wrap-around: first and last clusters may be circularly close
  if (clusters.length >= 2) {
    final firstDoy = _dayOfYear(clusters.first.first.creationDate!);
    final lastDoy = _dayOfYear(clusters.last.last.creationDate!);
    if (_circularDayDistance(firstDoy, lastDoy) <= windowDays) {
      // merge last into first
      final merged = [...clusters.first, ...clusters.last];
      // sort merged by date for consistency
      merged.sort((a, b) => a.creationDate!.compareTo(b.creationDate!));
      final newClusters = <List<MediaAsset>>[merged];
      newClusters.addAll(clusters.sublist(1, clusters.length - 1));
      return newClusters;
    }
  }
  return clusters;
}

int _dayOfYear(DateTime date) {
  final start = DateTime(date.year, 1, 1);
  return date.difference(start).inDays + 1;
}

int _circularDayDistance(int a, int b) {
  final diff = (a - b).abs();
  return math.min(diff, 366 - diff);
}

class LongTermEvolutionRuleConfig {
  const LongTermEvolutionRuleConfig({
    this.minimumAssets = 6,
    this.minimumYears = 4,
    this.clusterConfig = const LocationClusterConfig(radiusMeters: 500),
    @Deprecated('Use clusterConfig') this.locationPrecision = 1,
  });

  final int minimumAssets;
  final int minimumYears;
  final LocationClusterConfig clusterConfig;
  @Deprecated('Use clusterConfig')
  final int locationPrecision;
}

class LongTermEvolutionRule implements MemoryRule {
  const LongTermEvolutionRule({LongTermEvolutionRuleConfig? config})
    : config = config ?? const LongTermEvolutionRuleConfig();

  final LongTermEvolutionRuleConfig config;

  @override
  Future<List<MemoryCandidate>> discover(MemoryContext context) async {
    final candidates = <MemoryCandidate>[];
    final personGroups = <String, List<MediaAsset>>{};
    for (final asset in context.assets) {
      for (final personId in asset.personIds) {
        (personGroups[personId] ??= []).add(asset);
      }
    }
    for (final entry in personGroups.entries) {
      final candidate = _candidate(
        id: 'evolution-person-${entry.key}',
        assets: entry.value,
        personIds: [entry.key],
        placeIds: const [],
        subtype: 'personEvolution',
        titleForMetrics: (m) => m.calendarSpanYears >= 4
            ? '这些照片跨越了 ${m.calendarSpanYears} 年。'
            : '这些照片记录了一段时间的变化。',
      );
      if (candidate != null) candidates.add(candidate);
    }

    for (final entry in _groupByPlaceCluster(
      context.assets,
      config.clusterConfig,
    ).entries) {
      final candidate = _candidate(
        id: 'evolution-place-${entry.key}',
        assets: entry.value,
        personIds: const [],
        placeIds: [entry.key],
        subtype: 'placeEvolution',
        titleForMetrics: (m) => m.calendarSpanYears >= 4
            ? '这个地方在你的相册里跨越了 ${m.calendarSpanYears} 年。'
            : '这个地方在你的相册里出现了 ${m.distinctYearCount} 个年份。',
      );
      if (candidate != null) candidates.add(candidate);
    }
    return candidates;
  }

  MemoryCandidate? _candidate({
    required String id,
    required List<MediaAsset> assets,
    required List<String> personIds,
    required List<String> placeIds,
    required String subtype,
    required String Function(YearMetrics) titleForMetrics,
  }) {
    final sorted = _dated(assets);
    final metrics = YearMetrics.fromAssets(sorted);
    if (metrics == null) return null;
    if (sorted.length < config.minimumAssets ||
        metrics.distinctYearCount < config.minimumYears) {
      return null;
    }
    final title = titleForMetrics(metrics);
    return MemoryCandidate(
      id: id,
      type: MemoryCandidateType.longTermEvolution,
      period: _periodFor(sorted),
      mediaIds: sorted.map((a) => a.id).toList(growable: false),
      personIds: personIds,
      placeIds: placeIds,
      representativeMediaIds: RepresentativeMediaSelector.selectIds(
        sorted,
        maxCount: math.min(10, metrics.distinctYearCount),
      ),
      metadata: {
        'evolutionType': subtype,
        'distinctYearCount': metrics.distinctYearCount,
        'calendarSpanYears': metrics.calendarSpanYears,
        'longestConsecutiveYearRun': metrics.longestConsecutiveYearRun,
        'firstYear': metrics.firstYear,
        'lastYear': metrics.lastYear,
        'yearCount': metrics.distinctYearCount,
        'yearDistribution': _yearDistribution(sorted),
      },
      reasons: [
        'long_term_distinct_years:${metrics.distinctYearCount}',
        'long_term_span:${metrics.calendarSpanYears}',
        'long_term_media_count:${sorted.length}',
      ],
      safeTitleTemplate: title,
      safeSubtitleTemplate: '${metrics.firstYear} — ${metrics.lastYear}',
    );
  }
}

class MemoryEngine {
  MemoryEngine({Iterable<MemoryRule> rules = const []})
    : rules = List.unmodifiable(rules);
  final List<MemoryRule> rules;

  Future<List<MemoryCandidate>> discover(MemoryContext context) async {
    final all = <MemoryCandidate>[];
    for (final rule in rules) {
      all.addAll(await rule.discover(context));
    }
    return all;
  }
}

class MemoryScoreBreakdown {
  const MemoryScoreBreakdown({required this.score, required this.factors});
  final double score;
  final Map<String, double> factors;
  double get finalScore => score;
}

abstract interface class MemoryRanker {
  MemoryScoreBreakdown explain(
    MemoryCandidate candidate,
    MemoryContext context,
  );
  List<MemoryCandidate> rank(
    List<MemoryCandidate> candidates,
    MemoryContext context,
  );
}

class MemoryRankingWeights {
  const MemoryRankingWeights({
    this.accuracyConfidence = 18,
    this.timeSpan = 14,
    this.recurrence = 18,
    this.mediaDiversity = 12,
    this.rarity = 12,
    this.visualCoverage = 12,
    this.storyPotential = 14,
    this.sensitivityPenalty = 22,
  });

  final double accuracyConfidence;
  final double timeSpan;
  final double recurrence;
  final double mediaDiversity;
  final double rarity;
  final double visualCoverage;
  final double storyPotential;
  final double sensitivityPenalty;
}

class WeightedMemoryRanker implements MemoryRanker {
  const WeightedMemoryRanker({
    this.weights = const MemoryRankingWeights(),
    this.sensitivityGuard = const MemorySensitivityGuard(),
  });

  final MemoryRankingWeights weights;
  final MemorySensitivityGuard sensitivityGuard;

  @override
  MemoryScoreBreakdown explain(MemoryCandidate c, MemoryContext context) {
    final media = context.mediaFor(c);
    final count = media.length;
    final metrics = YearMetrics.fromAssets(media);
    final years = metrics?.distinctYearCount ?? _yearSet(media).length;
    final videos = _videoCount(media);
    final favorites = media.where((a) => a.isFavorite).length;
    final located = media.where((a) => a.location != null).length;
    final representativeCount = c.representativeMediaIds.isEmpty
        ? math.min(count, 6)
        : c.representativeMediaIds.length;
    final sensitivity = sensitivityGuard.assess(c);
    final routinePenalty = c.metadata['routinePlacePenalty'] == true ? .35 : 0;
    // locationCoverage confidence from metadata if present
    final coverageRaw = c.metadata['locationCoverage'];
    final locationCoverage = coverageRaw is double
        ? coverageRaw
        : count == 0
        ? 0.0
        : located / count;

    final factors = <String, double>{
      'accuracyConfidence': _factor(
        _accuracySignal(c, media, locationCoverage),
        weights.accuracyConfidence,
      ),
      'timeSpan': _factor(c.period.duration.inDays / 365, weights.timeSpan),
      'recurrence': _factor(_recurrenceSignal(c, years), weights.recurrence),
      'mediaDiversity': _factor(
        ((videos > 0 ? .5 : 0) +
            (favorites > 0 ? .25 : 0) +
            (located > 0 ? .25 : 0)),
        weights.mediaDiversity,
      ),
      'rarity': _factor(1 - routinePenalty, weights.rarity),
      'visualCoverage': _factor(
        representativeCount / 8,
        weights.visualCoverage,
      ),
      'storyPotential': _factor(
        _storyPotential(c, count),
        weights.storyPotential,
      ),
      'sensitivityPenalty': -_factor(
        sensitivity.penalty / weights.sensitivityPenalty,
        weights.sensitivityPenalty,
      ),
    };
    return MemoryScoreBreakdown(
      score: factors.values.fold(0.0, (a, b) => a + b).clamp(0, 100),
      factors: factors,
    );
  }

  @override
  List<MemoryCandidate> rank(
    List<MemoryCandidate> candidates,
    MemoryContext context,
  ) =>
      candidates
          .where((c) => !sensitivityGuard.assess(c).hidden)
          .map((c) => c.withScore(explain(c, context).score))
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));

  double _accuracySignal(
    MemoryCandidate c,
    List<MediaAsset> media,
    double locationCoverage,
  ) => switch (c.type) {
    MemoryCandidateType.samePlaceAcrossYears =>
      media.any((a) => a.location != null) ? .9 : .45,
    MemoryCandidateType.travelStory => locationCoverage,
    MemoryCandidateType.personTimeline ||
    MemoryCandidateType.annualTogether ||
    MemoryCandidateType.longTermEvolution => c.personIds.isNotEmpty ? .72 : .62,
    MemoryCandidateType.firstMemory => .68,
    MemoryCandidateType.samePlace => .76,
    MemoryCandidateType.dateCluster => .58,
    MemoryCandidateType.yearRecap => .5,
  };

  double _recurrenceSignal(MemoryCandidate c, int years) {
    final metadataYears = c.metadata['distinctYearCount'];
    if (metadataYears is int) return metadataYears / 6;
    final legacyYears = c.metadata['yearCount'];
    if (legacyYears is int) return legacyYears / 6;
    final visits = c.metadata['visitCount'];
    if (visits is int) return visits / 8;
    return years / 5;
  }

  double _storyPotential(MemoryCandidate c, int count) {
    final base = switch (c.type) {
      MemoryCandidateType.samePlaceAcrossYears => .9,
      MemoryCandidateType.travelStory => .86,
      MemoryCandidateType.personTimeline => .78,
      MemoryCandidateType.firstMemory => .72,
      MemoryCandidateType.annualTogether => .74,
      MemoryCandidateType.longTermEvolution => .76,
      MemoryCandidateType.samePlace => .58,
      MemoryCandidateType.dateCluster => .52,
      MemoryCandidateType.yearRecap => .46,
    };
    return math.min(1, base + count / 160);
  }

  static double _factor(num normalized, double weight) =>
      normalized.clamp(0, 1).toDouble() * weight;
}

class MemorySensitivityResult {
  const MemorySensitivityResult({
    this.flags = const [],
    this.penalty = 0,
    this.hidden = false,
  });

  final List<String> flags;
  final double penalty;
  final bool hidden;
}

/// V0.1: structured candidate flags + copy keyword guard + ranking penalty/hide.
/// This is not a semantic inference engine; it is keyword + structural scan.
class MemorySensitivityGuard {
  const MemorySensitivityGuard();

  static const _sensitiveTerms = {
    'death': 'death',
    'dead': 'death',
    'funeral': 'death',
    'illness': 'health',
    'disease': 'health',
    'pregnant': 'pregnancy',
    'pregnancy': 'pregnancy',
    'marriage': 'relationship',
    'divorce': 'relationship',
    'breakup': 'relationship',
    'religion': 'religion',
    'sexual': 'sexual_orientation',
    'body change': 'body_change',
    '死亡': 'death',
    '葬礼': 'death',
    '疾病': 'health',
    '生病': 'health',
    '怀孕': 'pregnancy',
    '结婚': 'relationship',
    '离婚': 'relationship',
    '分手': 'relationship',
    '宗教': 'religion',
    '性取向': 'sexual_orientation',
    '变胖': 'body_change',
    '变瘦': 'body_change',
    '老了': 'body_change',
    '妈妈': 'unverified_relationship',
    '爸爸': 'unverified_relationship',
    '丈夫': 'unverified_relationship',
    '妻子': 'unverified_relationship',
    '男朋友': 'unverified_relationship',
    '女朋友': 'unverified_relationship',
    '伴侣': 'unverified_relationship',
  };

  MemorySensitivityResult assess(MemoryCandidate candidate) {
    final text = [
      candidate.safeTitleTemplate,
      candidate.safeSubtitleTemplate,
      ...candidate.reasons,
      ...candidate.metadata.values.map((value) => '$value'),
    ].whereType<String>().join(' ').toLowerCase();
    final flags = <String>{};
    for (final entry in _sensitiveTerms.entries) {
      if (text.contains(entry.key.toLowerCase())) flags.add(entry.value);
    }
    if (flags.isEmpty) return const MemorySensitivityResult();
    final highRisk = flags.any(
      (flag) =>
          flag == 'death' || flag == 'health' || flag == 'sexual_orientation',
    );
    return MemorySensitivityResult(
      flags: flags.toList(growable: false)..sort(),
      penalty: highRisk ? 22 : 12,
      hidden: highRisk,
    );
  }
}

class MemoryCandidateDeduplicator {
  const MemoryCandidateDeduplicator({
    this.mediaOverlapThreshold = .72,
    this.timeOverlapThreshold = .75,
    this.subjectOverlapThreshold = .8,
  });

  final double mediaOverlapThreshold;
  final double timeOverlapThreshold;
  final double subjectOverlapThreshold;

  List<MemoryCandidate> deduplicate(List<MemoryCandidate> candidates) {
    final sorted = [...candidates]..sort((a, b) => b.score.compareTo(a.score));
    final infos = sorted.map(_CandidateDedupInfo.new).toList(growable: false);
    final kept = <_CandidateDedupInfo>[];
    for (final info in infos) {
      final duplicate = kept.any((existing) => _sameStory(existing, info));
      if (!duplicate) kept.add(info);
    }
    return kept.map((info) => info.candidate).toList(growable: false);
  }

  bool _sameStory(_CandidateDedupInfo a, _CandidateDedupInfo b) {
    final timeOverlap = _timeOverlap(a.candidate.period, b.candidate.period);
    if (timeOverlap == 0) return false;
    final mediaOverlap = _jaccardSets(a.mediaIds, b.mediaIds);
    if (mediaOverlap >= mediaOverlapThreshold) return true;
    final subjectOverlap = math.max(
      _jaccardSets(a.personIds, b.personIds),
      _jaccardSets(a.placeIds, b.placeIds),
    );
    return timeOverlap >= timeOverlapThreshold &&
        subjectOverlap >= subjectOverlapThreshold;
  }
}

class _CandidateDedupInfo {
  _CandidateDedupInfo(this.candidate)
    : mediaIds = candidate.mediaIds.toSet(),
      personIds = candidate.personIds.toSet(),
      placeIds = candidate.placeIds.toSet();

  final MemoryCandidate candidate;
  final Set<String> mediaIds;
  final Set<String> personIds;
  final Set<String> placeIds;
}

class FeedDiversityController {
  const FeedDiversityController({this.maxConsecutivePerType = 2});

  final int maxConsecutivePerType;

  List<MemoryCandidate> diversify(
    List<MemoryCandidate> ranked, {
    int limit = 10,
  }) {
    final remaining = [...ranked];
    final output = <MemoryCandidate>[];
    while (remaining.isNotEmpty && output.length < limit) {
      final blockedType = _blockedType(output);
      var index = 0;
      if (blockedType != null) {
        final alternative = remaining.indexWhere((c) => c.type != blockedType);
        if (alternative != -1) index = alternative;
      }
      output.add(remaining.removeAt(index));
    }
    return output;
  }

  MemoryCandidateType? _blockedType(List<MemoryCandidate> output) {
    if (output.length < maxConsecutivePerType) return null;
    final tail = output
        .skip(output.length - maxConsecutivePerType)
        .map((c) => c.type)
        .toSet();
    return tail.length == 1 ? tail.single : null;
  }
}

class RepresentativeMediaSelector {
  const RepresentativeMediaSelector();

  static List<String> selectIds(List<MediaAsset> assets, {int maxCount = 6}) {
    final sorted = _dated(assets);
    if (sorted.isEmpty) return const [];
    final selected = <MediaAsset>[];
    void addIfUseful(MediaAsset asset) {
      if (selected.any((item) => item.id == asset.id)) return;
      if (selected.any((item) => _nearDuplicate(item, asset))) return;
      selected.add(asset);
    }

    for (final asset in sorted.where((asset) => asset.isFavorite)) {
      addIfUseful(asset);
      if (selected.length >= maxCount) break;
    }
    for (final asset in sorted.where(
      (asset) => asset.type == MediaType.video,
    )) {
      addIfUseful(asset);
      if (selected.length >= maxCount) break;
    }
    for (final year in _yearSet(sorted)) {
      final yearAssets = sorted.where(
        (asset) => asset.creationDate?.year == year,
      );
      if (yearAssets.isNotEmpty) addIfUseful(yearAssets.first);
      if (selected.length >= maxCount) break;
    }
    final stride = math.max(1, sorted.length ~/ maxCount);
    for (var index = 0; index < sorted.length; index += stride) {
      addIfUseful(sorted[index]);
      if (selected.length >= maxCount) break;
    }
    return selected.map((asset) => asset.id).toList(growable: false);
  }

  static bool _nearDuplicate(MediaAsset a, MediaAsset b) {
    final ad = a.creationDate;
    final bd = b.creationDate;
    if (ad == null || bd == null) return false;
    final closeTime = ad.difference(bd).abs() <= const Duration(seconds: 8);
    final al = a.location;
    final bl = b.location;
    final closeLocation = al != null && bl != null && _distanceKm(al, bl) < .03;
    return closeTime && (closeLocation || al == null || bl == null);
  }
}

abstract interface class MemoryEvaluationStore {
  Future<void> save(MemoryEvaluation evaluation);
  Future<List<MemoryEvaluation>> loadAll();
  Future<MemoryEvaluation?> load(String candidateId);
}

class InMemoryMemoryEvaluationStore implements MemoryEvaluationStore {
  final Map<String, MemoryEvaluation> _items = {};

  @override
  Future<List<MemoryEvaluation>> loadAll() async =>
      _items.values.toList(growable: false);

  @override
  Future<MemoryEvaluation?> load(String candidateId) async =>
      _items[candidateId];

  @override
  Future<void> save(MemoryEvaluation evaluation) async {
    final key = evaluation.effectiveOpaqueId;
    _items[key] = evaluation;
  }
}

class JsonFileMemoryEvaluationStore implements MemoryEvaluationStore {
  JsonFileMemoryEvaluationStore(this.file);

  final File file;

  @override
  Future<List<MemoryEvaluation>> loadAll() async {
    if (!await file.exists()) return const [];
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => MemoryEvaluation.fromJson(item.cast<String, Object?>()))
        .toList(growable: false);
  }

  @override
  Future<MemoryEvaluation?> load(String candidateId) async {
    final opaque = candidateId.startsWith('eval-') ? candidateId : null;
    for (final evaluation in await loadAll()) {
      if (evaluation.candidateId == candidateId ||
          evaluation.candidateId == opaque ||
          evaluation.effectiveOpaqueId == candidateId) {
        return evaluation;
      }
    }
    return null;
  }

  @override
  Future<void> save(MemoryEvaluation evaluation) async {
    final parent = file.parent;
    if (!await parent.exists()) await parent.create(recursive: true);
    final items = {
      for (final item in await loadAll()) item.effectiveOpaqueId: item,
    };
    items[evaluation.effectiveOpaqueId] = evaluation;
    await file.writeAsString(
      jsonEncode(items.values.map((item) => item.toJson()).toList()),
    );
  }
}

List<MediaAsset> _dated(List<MediaAsset> assets) =>
    assets.where((a) => a.creationDate != null).toList()
      ..sort((a, b) => a.creationDate!.compareTo(b.creationDate!));

DateTimeRange _periodFor(List<MediaAsset> assets) {
  final dated = _dated(assets);
  if (dated.isEmpty) return DateTimeRange(DateTime(1970), DateTime(1970));
  return DateTimeRange(dated.first.creationDate!, dated.last.creationDate!);
}

List<List<MediaAsset>> _sessions(List<MediaAsset> assets, Duration maxGap) {
  final sorted = _dated(assets);
  final result = <List<MediaAsset>>[];
  var current = <MediaAsset>[];
  for (final asset in sorted) {
    final previous = current.isEmpty ? null : current.last.creationDate;
    if (previous != null && asset.creationDate!.difference(previous) > maxGap) {
      result.add(current);
      current = [];
    }
    current.add(asset);
  }
  if (current.isNotEmpty) result.add(current);
  return result;
}

List<MediaAsset> _firstWindow(List<MediaAsset> assets, Duration window) {
  final sorted = _dated(assets);
  if (sorted.isEmpty) return const [];
  final start = sorted.first.creationDate!;
  return sorted
      .where((asset) => asset.creationDate!.difference(start) <= window)
      .toList(growable: false);
}

List<int> _yearSet(Iterable<MediaAsset> assets) {
  final years = assets
      .map((asset) => asset.creationDate?.year)
      .whereType<int>()
      .toSet()
      .toList();
  years.sort();
  return years;
}

Map<String, int> _yearDistribution(Iterable<MediaAsset> assets) {
  final result = <String, int>{};
  for (final asset in assets) {
    final year = asset.creationDate?.year;
    if (year == null) continue;
    result['$year'] = (result['$year'] ?? 0) + 1;
  }
  return result;
}

int _videoCount(Iterable<MediaAsset> assets) =>
    assets.where((asset) => asset.type == MediaType.video).length;

double _routeDistanceKm(List<MediaAsset> assets) {
  var distance = 0.0;
  GeoPoint? previous;
  for (final asset in assets) {
    final point = asset.location;
    if (point == null) continue;
    if (previous != null) distance += _distanceKm(previous, point);
    previous = point;
  }
  return distance;
}

double _distanceKm(GeoPoint a, GeoPoint b) {
  const earthKm = 6371.0;
  final dLat = _radians(b.latitude - a.latitude);
  final dLon = _radians(b.longitude - a.longitude);
  final lat1 = _radians(a.latitude);
  final lat2 = _radians(b.latitude);
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(lat1) * math.cos(lat2);
  return earthKm * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

double _radians(double degrees) => degrees * math.pi / 180;

double _jaccardSets(Set<String> left, Set<String> right) {
  if (left.isEmpty || right.isEmpty) return 0;
  final smaller = left.length < right.length ? left : right;
  final larger = identical(smaller, left) ? right : left;
  var intersection = 0;
  for (final item in smaller) {
    if (larger.contains(item)) intersection += 1;
  }
  final union = left.length + right.length - intersection;
  return union == 0 ? 0 : intersection / union;
}

double _timeOverlap(DateTimeRange a, DateTimeRange b) {
  final start = a.start.isAfter(b.start) ? a.start : b.start;
  final end = a.end.isBefore(b.end) ? a.end : b.end;
  if (end.isBefore(start)) return 0;
  final overlap = end.difference(start).inMilliseconds;
  final shortest = math.min(
    math.max(1, a.duration.inMilliseconds),
    math.max(1, b.duration.inMilliseconds),
  );
  return overlap / shortest;
}
