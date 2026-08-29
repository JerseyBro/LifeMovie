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
    this.duration,
    this.width,
    this.height,
    this.location,
    this.isFavorite = false,
    this.isLivePhoto = false,
    this.localIdentifier,
  });
  final String id;
  final MediaType type;
  final DateTime? creationDate;
  final Duration? duration;
  final int? width;
  final int? height;
  final GeoPoint? location;
  final bool isFavorite;
  final bool isLivePhoto;
  final String? localIdentifier;
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

enum MemoryCandidateType { dateCluster, samePlace, yearRecap }

class MemoryCandidate {
  const MemoryCandidate({
    required this.id,
    required this.type,
    required this.period,
    required this.mediaIds,
    this.personIds = const [],
    this.placeIds = const [],
    this.score = 0,
    this.reasons = const [],
    this.metadata = const {},
  });
  final String id;
  final MemoryCandidateType type;
  final DateTimeRange period;
  final List<String> mediaIds;
  final List<String> personIds;
  final List<String> placeIds;
  final double score;
  final List<String> reasons;
  final Map<String, Object?> metadata;
  MemoryCandidate withScore(double value) => MemoryCandidate(
    id: id,
    type: type,
    period: period,
    mediaIds: mediaIds,
    personIds: personIds,
    placeIds: placeIds,
    score: value,
    reasons: reasons,
    metadata: metadata,
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
