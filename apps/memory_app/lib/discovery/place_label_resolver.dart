import 'package:media_library/media_library.dart';
import 'package:memory_engine/memory_engine.dart';

/// Resolves city-level place labels for discovery place cards. Labels come
/// from the platform geocoder and are cached in memory; failures fall back
/// to a count-based neutral label so no section ever fakes data.
class PlaceLabelResolver {
  PlaceLabelResolver(this._repository);

  final MediaRepository _repository;
  final Map<String, String> _cache = {};

  Future<String> labelFor(DiscoveryPlaceSummary place) async {
    final cached = _cache[place.placeId];
    if (cached != null) return cached;
    final label = await _repository.loadPlaceLabel(place.center);
    final resolved = label ?? '地点 ${place.placeId}';
    _cache[place.placeId] = resolved;
    return resolved;
  }
}
