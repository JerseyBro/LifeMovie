library;

import 'package:media_library/media_library.dart';
import 'package:memory_domain/memory_domain.dart';

class MemoryContext {
  const MemoryContext({required this.assets});
  final List<MediaAsset> assets;
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
    ],
  );
}

class SamePlaceRule implements MemoryRule {
  const SamePlaceRule({this.minimumAssets = 2, this.precision = 1});
  final int minimumAssets;
  final int precision;
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
    return groups.entries.where((e) => e.value.length >= minimumAssets).map((
      e,
    ) {
      final assets = e.value
        ..sort(
          (a, b) => (a.creationDate ?? DateTime(1970)).compareTo(
            b.creationDate ?? DateTime(1970),
          ),
        );
      return MemoryCandidate(
        id: 'place-${e.key}',
        type: MemoryCandidateType.samePlace,
        period: DateTimeRange(
          assets.first.creationDate ?? DateTime(1970),
          assets.last.creationDate ?? DateTime(1970),
        ),
        mediaIds: assets.map((a) => a.id).toList(),
        placeIds: [e.key],
        reasons: ['${assets.length} assets share a coarse location'],
      );
    }).toList();
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
    this.durationWeight = .2,
    this.mediaCountWeight = .4,
    this.favoriteWeight = .2,
    this.locationWeight = .2,
  });
  final double durationWeight;
  final double mediaCountWeight;
  final double favoriteWeight;
  final double locationWeight;
  @override
  MemoryScoreBreakdown explain(MemoryCandidate c, MemoryContext context) {
    final media = context.assets.where((a) => c.mediaIds.contains(a.id));
    final count = media.length;
    final favorites = media.where((a) => a.isFavorite).length;
    final factors = {
      'mediaCount': (count / 20).clamp(0, 1).toDouble() * mediaCountWeight,
      'favoriteCount':
          (favorites / count.clamp(1, 10)).clamp(0, 1).toDouble() *
          favoriteWeight,
      'duration':
          (c.period.duration.inDays / 30).clamp(0, 1).toDouble() *
          durationWeight,
      'locationConsistency': c.placeIds.isNotEmpty ? locationWeight : 0.0,
    };
    return MemoryScoreBreakdown(
      score: factors.values.fold(0.0, (a, b) => a + b),
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
}
