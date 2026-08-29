import 'package:memory_domain/memory_domain.dart';
import '../media_library.dart';

class MediaIndex {
  final List<MediaAsset> _assets = [];
  List<MediaAsset> get assets => List.unmodifiable(_assets);
  Future<void> rebuild(MediaRepository repository) async {
    _assets.clear();
    var offset = 0;
    const pageSize = 100;
    while (true) {
      final page = await repository.fetchAssets(
        offset: offset,
        limit: pageSize,
      );
      _assets.addAll(page);
      if (page.length < pageSize) break;
      offset += page.length;
    }
  }

  List<MediaAsset> byDateRange(DateTimeRange range) => _assets
      .where(
        (a) =>
            a.creationDate != null &&
            !a.creationDate!.isBefore(range.start) &&
            !a.creationDate!.isAfter(range.end),
      )
      .toList();
  List<MediaAsset> byType(MediaType type) =>
      _assets.where((a) => a.type == type).toList();
  List<MediaAsset> favorites() => _assets.where((a) => a.isFavorite).toList();
}
