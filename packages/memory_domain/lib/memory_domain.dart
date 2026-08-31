library;

enum MediaType { image, video, livePhoto, audio }

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.type,
    this.creationDate,
    this.modificationDate,
    this.duration,
    this.width,
    this.height,
    this.location,
    this.isFavorite = false,
    this.isLivePhoto = false,
    this.localIdentifier,
    this.personIds = const [],
  });
  final String id;
  final MediaType type;
  final DateTime? creationDate;
  final DateTime? modificationDate;
  final Duration? duration;
  final int? width;
  final int? height;
  final GeoPoint? location;
  final bool isFavorite;
  final bool isLivePhoto;
  final String? localIdentifier;
  final List<String> personIds;
}

class Person {
  const Person({
    required this.id,
    this.displayName,
    this.clusterId,
    this.coverAssetId,
  });
  final String id;
  final String? displayName;
  final String? clusterId;
  final String? coverAssetId;
}

class Place {
  const Place({required this.id, this.name, required this.location});
  final String id;
  final String? name;
  final GeoPoint location;
}

class Event {
  const Event({required this.id, required this.mediaIds, required this.period});
  final String id;
  final List<String> mediaIds;
  final DateTimeRange period;
}

class DateTimeRange {
  const DateTimeRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
  Duration get duration => end.difference(start);
}

enum MemoryCandidateType {
  dateCluster,
  samePlace,
  yearRecap,
  personTimeline,
  samePlaceAcrossYears,
  firstMemory,
  travelStory,
  annualTogether,
  longTermEvolution,
}

class MemoryCandidate {
  const MemoryCandidate({
    required this.id,
    required this.type,
    required this.period,
    required this.mediaIds,
    this.personIds = const [],
    this.placeIds = const [],
    this.representativeMediaIds = const [],
    this.score = 0,
    this.reasons = const [],
    this.metadata = const {},
    @Deprecated(
      'Use presentation copy mapper instead. Engine should not own final Chinese copy.',
    )
    this.safeTitleTemplate,
    @Deprecated(
      'Use presentation copy mapper instead. Engine should not own final Chinese copy.',
    )
    this.safeSubtitleTemplate,
  });
  final String id;
  final MemoryCandidateType type;
  final DateTimeRange period;
  final List<String> mediaIds;
  final List<String> personIds;
  final List<String> placeIds;
  final List<String> representativeMediaIds;
  final double score;
  final List<String> reasons;
  final Map<String, Object?> metadata;
  @Deprecated('Use presentation copy mapper instead.')
  final String? safeTitleTemplate;
  @Deprecated('Use presentation copy mapper instead.')
  final String? safeSubtitleTemplate;

  MemoryCandidate withScore(double value) => MemoryCandidate(
    id: id,
    type: type,
    period: period,
    mediaIds: mediaIds,
    personIds: personIds,
    placeIds: placeIds,
    representativeMediaIds: representativeMediaIds,
    score: value,
    reasons: reasons,
    metadata: metadata,
    safeTitleTemplate: safeTitleTemplate,
    safeSubtitleTemplate: safeSubtitleTemplate,
  );
}

class MemoryEvaluation {
  const MemoryEvaluation({
    required this.candidateId,
    required this.ruleType,
    required this.accuracy,
    required this.meaningfulness,
    required this.surprise,
    required this.clarity,
    required this.sensitivity,
    this.labels = const [],
    required this.createdAt,
    this.anonymousCandidateId,
  });

  /// Opaque candidate identifier for persistence. Must not contain raw GPS,
  /// person id, asset id or file path. Use [opaqueCandidateId] to derive.
  final String candidateId;
  final MemoryCandidateType ruleType;
  final int accuracy;
  final int meaningfulness;
  final int surprise;
  final int clarity;
  final int sensitivity;
  final List<String> labels;
  final DateTime createdAt;

  /// Explicit opaque alias. When set, this is persisted instead of exposing raw.
  /// Kept for migration; [candidateId] should already be opaque after 0.8.1.
  final String? anonymousCandidateId;

  /// Stable opaque id for a raw candidate id. Uses FNV-1a 64 with app salt.
  /// Result is 16-char hex, no raw coordinates or ids leak.
  static String opaqueCandidateId(
    String rawCandidateId,
    MemoryCandidateType type,
  ) {
    const salt = 'LifeMovie-eval-v1';
    final input = '${type.name}:$rawCandidateId:$salt';
    var hash = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    for (final code in input.codeUnits) {
      hash ^= code;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
    }
    final hex = hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
    return 'eval-$hex';
  }

  /// Convenience factory that hashes candidate.id automatically.
  factory MemoryEvaluation.forCandidate(
    MemoryCandidate candidate, {
    required int accuracy,
    required int meaningfulness,
    required int surprise,
    required int clarity,
    required int sensitivity,
    List<String> labels = const [],
    required DateTime createdAt,
  }) => MemoryEvaluation(
    candidateId: opaqueCandidateId(candidate.id, candidate.type),
    ruleType: candidate.type,
    accuracy: accuracy,
    meaningfulness: meaningfulness,
    surprise: surprise,
    clarity: clarity,
    sensitivity: sensitivity,
    labels: labels,
    createdAt: createdAt,
    anonymousCandidateId: opaqueCandidateId(candidate.id, candidate.type),
  );

  String get effectiveOpaqueId => anonymousCandidateId ?? candidateId;

  Map<String, Object?> toJson() => {
    'candidateId': effectiveOpaqueId,
    'ruleType': ruleType.name,
    'accuracy': accuracy,
    'meaningfulness': meaningfulness,
    'surprise': surprise,
    'clarity': clarity,
    'sensitivity': sensitivity,
    'labels': labels,
    'createdAt': createdAt.toIso8601String(),
    if (anonymousCandidateId != null)
      'anonymousCandidateId': anonymousCandidateId,
  };

  static MemoryEvaluation fromJson(Map<String, Object?> json) =>
      MemoryEvaluation(
        candidateId:
            (json['anonymousCandidateId'] as String?) ??
            json['candidateId']! as String,
        ruleType: MemoryCandidateType.values.byName(
          json['ruleType']! as String,
        ),
        accuracy: json['accuracy']! as int,
        meaningfulness: json['meaningfulness']! as int,
        surprise: json['surprise']! as int,
        clarity: json['clarity']! as int,
        sensitivity: json['sensitivity']! as int,
        labels: (json['labels'] as List? ?? const []).cast<String>(),
        createdAt: DateTime.parse(json['createdAt']! as String),
        anonymousCandidateId: json['anonymousCandidateId'] as String?,
      );
}

class Memory {
  const Memory({
    required this.id,
    required this.title,
    required this.candidate,
  });
  final String id;
  final String title;
  final MemoryCandidate candidate;
}

class MemoryStory {
  const MemoryStory({
    required this.memoryId,
    required this.title,
    required this.summary,
  });
  final String memoryId;
  final String title;
  final String summary;
}

class MovieProject {
  const MovieProject({required this.id, required this.memoryId});
  final String id;
  final String memoryId;
}
