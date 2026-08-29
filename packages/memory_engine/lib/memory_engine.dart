library;

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

class DateClusterRule implements MemoryRule {
  const DateClusterRule({
    this.maxGap = const Duration(days: 2),
    this.minimumAssets = 3,
  });
  final Duration maxGap;
  final int minimumAssets;
  @override
  Future<List<MemoryCandidate>> discover(MemoryContext context) async {
    final dated = context.assets.where((a) => a.creationDate != null).toList()
      ..sort((a, b) => a.creationDate!.compareTo(b.creationDate!));
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
    period: DateTimeRange(
      assets.first.creationDate!,
      assets.last.creationDate!,
    ),
    mediaIds: assets.map((a) => a.id).toList(),
    reasons: [
      'Dense activity across ${assets.length} media assets',
      'Assets were created within a short time window',
      '${assets.where((a) => a.type == MediaType.video).length} videos in this cluster',
    ],
  );
}

class SamePlaceRule implements MemoryRule {
  const SamePlaceRule({
    this.minimumAssets = 3,
    this.precision = 1,
    this.maxSessionGap = const Duration(days: 14),
  });

  final int minimumAssets;
  final int precision;
  final Duration maxSessionGap;

  @override
  Future<List<MemoryCandidate>> discover(MemoryContext context) async {
    final groups = <String, List<MediaAsset>>{};
    for (final asset in context.assets) {
      final p = asset.location;
      if (p != null) {
        final key =
            '${p.latitude.toStringAsFixed(precision)},${p.longitude.toStringAsFixed(precision)}';
        (groups[key] ??= []).add(asset);
      }
    }
    final candidates = <MemoryCandidate>[];
    for (final entry in groups.entries) {
      final sorted = entry.value
        ..sort(
          (a, b) => (a.creationDate ?? DateTime(1970)).compareTo(
            b.creationDate ?? DateTime(1970),
          ),
        );
      for (final session in _sessions(sorted)) {
        if (session.length < minimumAssets) continue;
        candidates.add(
          MemoryCandidate(
            id: 'place-${entry.key}-${session.first.id}',
            type: MemoryCandidateType.samePlace,
            period: DateTimeRange(
              session.first.creationDate ?? DateTime(1970),
              session.last.creationDate ?? DateTime(1970),
            ),
            mediaIds: session.map((a) => a.id).toList(),
            placeIds: [entry.key],
            reasons: [
              '${session.length} assets in one place session',
              'Nearby media is split by visit gaps to avoid one huge home cluster',
            ],
          ),
        );
      }
    }
    return candidates;
  }

  List<List<MediaAsset>> _sessions(List<MediaAsset> assets) {
    final result = <List<MediaAsset>>[];
    var current = <MediaAsset>[];
    for (final asset in assets) {
      final date = asset.creationDate;
      final previous = current.isEmpty ? null : current.last.creationDate;
      if (date != null &&
          previous != null &&
          date.difference(previous) > maxSessionGap) {
        result.add(current);
        current = [];
      }
      current.add(asset);
    }
    if (current.isNotEmpty) result.add(current);
    return result;
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
        .map(
          (e) => MemoryCandidate(
            id: 'year-${e.key}',
            type: MemoryCandidateType.yearRecap,
            period: DateTimeRange(
              DateTime(e.key),
              DateTime(e.key, 12, 31, 23, 59, 59),
            ),
            mediaIds: e.value.map((a) => a.id).toList(),
            reasons: ['Year recap contains ${e.value.length} media assets'],
          ),
        )
        .toList();
  }
}

class PersonTimelineRule implements MemoryRule {
  const PersonTimelineRule({this.minimumAssets = 3, this.minimumYears = 2});

  final int minimumAssets;
  final int minimumYears;

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
      final assets = entry.value
        ..sort(
          (a, b) => (a.creationDate ?? DateTime(1970)).compareTo(
            b.creationDate ?? DateTime(1970),
          ),
        );
      final years = assets
          .map((asset) => asset.creationDate?.year)
          .whereType<int>()
          .toSet();
      if (assets.length < minimumAssets || years.length < minimumYears) {
        continue;
      }
      candidates.add(
        MemoryCandidate(
          id: 'person-${entry.key}',
          type: MemoryCandidateType.personTimeline,
          period: DateTimeRange(
            assets.first.creationDate ?? DateTime(1970),
            assets.last.creationDate ?? DateTime(1970),
          ),
          mediaIds: assets.map((a) => a.id).toList(),
          personIds: [entry.key],
          reasons: [
            'Synthetic person cluster spans ${years.length} years',
            '${assets.length} assets can support a future person story',
          ],
        ),
      );
    }
    return candidates;
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

class WeightedMemoryRanker implements MemoryRanker {
  const WeightedMemoryRanker({
    this.mediaDensityWeight = 24,
    this.durationWeight = 14,
    this.favoriteWeight = 10,
    this.locationWeight = 14,
    this.videoRatioWeight = 12,
    this.timeSpanWeight = 14,
    this.recurrenceWeight = 12,
  });

  final double mediaDensityWeight;
  final double durationWeight;
  final double favoriteWeight;
  final double locationWeight;
  final double videoRatioWeight;
  final double timeSpanWeight;
  final double recurrenceWeight;

  @override
  MemoryScoreBreakdown explain(MemoryCandidate c, MemoryContext context) {
    final media = context.mediaFor(c);
    final count = media.length;
    final favorites = media.where((a) => a.isFavorite).length;
    final videos = media.where((a) => a.type == MediaType.video).length;
    final located = media.where((a) => a.location != null).length;
    final years = media
        .map((a) => a.creationDate?.year)
        .whereType<int>()
        .toSet()
        .length;
    final factors = {
      'mediaDensity': _factor(count / 40, mediaDensityWeight),
      'duration': _factor(c.period.duration.inDays / 30, durationWeight),
      'favorite': _factor(favorites / count.clamp(1, 10), favoriteWeight),
      'location': _factor(located / count.clamp(1, 20), locationWeight),
      'videoRatio': _factor(videos / count.clamp(1, 20), videoRatioWeight),
      'timeSpan': _factor(c.period.duration.inDays / 14, timeSpanWeight),
      'recurrence': _factor(years / 3, recurrenceWeight),
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
      candidates.map((c) => c.withScore(explain(c, context).score)).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

  static double _factor(num normalized, double weight) =>
      normalized.clamp(0, 1).toDouble() * weight;
}
