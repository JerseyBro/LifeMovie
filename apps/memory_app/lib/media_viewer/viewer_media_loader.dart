import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/widgets/media_preview.dart';
import 'package:memory_domain/memory_domain.dart';

/// Progressive media pipeline for the fullscreen viewer (ADR media loading
/// contract):
///
///   thumb(360) immediately -> preview(2200) replaces seamlessly
///   prefetch window: N-1 / N / N+1 previews, no N+2
///   byte budget: preview LRU <= [previewMaxEntries], thumb LRU <= [thumbMaxEntries]
///   requests outside the window are cancelled through the repository.
class ViewerMediaLoader extends ChangeNotifier {
  ViewerMediaLoader({
    required this.repository,
    required this.assets,
    this.previewMaxEntries = 3,
    this.thumbMaxEntries = 30,
    this.previewPixelSize = viewerPreviewSize,
    this.thumbPixelSize = gridPreviewSize,
  });

  final MediaRepository repository;
  final List<MediaAsset> assets;
  final int previewMaxEntries;
  final int thumbMaxEntries;
  final int previewPixelSize;
  final int thumbPixelSize;

  final LinkedHashMap<int, Uint8List> _thumbs = LinkedHashMap();
  final LinkedHashMap<int, Uint8List> _previews = LinkedHashMap();
  final Map<int, String> _previewRequests = {};
  final Map<int, String> _thumbRequests = {};
  final Set<int> _previewFailed = {};

  Uint8List? thumbFor(int index) => _thumbs[index];
  Uint8List? previewFor(int index) => _previews[index];
  bool get hasAssets => assets.isNotEmpty;
  bool isPreviewFailed(int index) => _previewFailed.contains(index);
  bool get isPreviewInFlight => _previewRequests.isNotEmpty;

  /// Makes [index] the focus: guarantees thumb + preview for the window and
  /// cancels/evicts everything outside it. Called on open and page change.
  void focus(int index) {
    final window = {
      for (var i = index - 1; i <= index + 1; i++)
        if (i >= 0 && i < assets.length) i,
    };
    for (final i in window) {
      _ensureThumb(i);
      _ensurePreview(i);
    }
    for (final i in {..._previewRequests.keys}) {
      if (!window.contains(i)) _cancelPreview(i);
    }
    for (final i in {..._thumbRequests.keys}) {
      if (!window.contains(i)) _cancelThumb(i);
    }
    _evictTo(_previews, previewMaxEntries, window);
    _evictTo(_thumbs, thumbMaxEntries, window);
  }

  Future<Uint8List?> retryPreview(int index) {
    _previewFailed.remove(index);
    _previews.remove(index);
    return _ensurePreview(index);
  }

  Future<Uint8List?> _ensurePreview(int index) {
    if (_previews.containsKey(index) || _previewRequests.containsKey(index)) {
      return Future.value(_previews[index]);
    }
    final asset = assets[index];
    final requestId = 'viewer-preview-${asset.id}-$index';
    _previewRequests[index] = requestId;
    return repository
        .loadPreview(
          asset.id,
          maxPixelSize: previewPixelSize,
          requestId: requestId,
        )
        .then((bytes) {
          _previewRequests.remove(index);
          if (bytes == null || bytes.isEmpty) {
            _previewFailed.add(index);
            notifyListeners();
            return null;
          }
          _previews[index] = bytes;
          _evictTo(_previews, previewMaxEntries, null);
          notifyListeners();
          return bytes;
        })
        .catchError((Object error) {
          _previewRequests.remove(index);
          _previewFailed.add(index);
          notifyListeners();
          return null;
        });
  }

  Future<Uint8List?> _ensureThumb(int index) {
    if (_thumbs.containsKey(index) || _thumbRequests.containsKey(index)) {
      return Future.value(_thumbs[index]);
    }
    final asset = assets[index];
    final requestId = 'viewer-thumb-${asset.id}-$index';
    _thumbRequests[index] = requestId;
    return repository
        .loadThumbnail(asset.id, size: thumbPixelSize, requestId: requestId)
        .then((bytes) {
          _thumbRequests.remove(index);
          if (bytes == null || bytes.isEmpty) {
            notifyListeners();
            return null;
          }
          _thumbs[index] = bytes;
          _evictTo(_thumbs, thumbMaxEntries, null);
          notifyListeners();
          return bytes;
        })
        .catchError((Object error) {
          _thumbRequests.remove(index);
          notifyListeners();
          return null;
        });
  }

  void _cancelPreview(int index) {
    final requestId = _previewRequests.remove(index);
    if (requestId != null) {
      repository.cancelThumbnailRequest(requestId);
    }
    _previewFailed.remove(index);
  }

  void _cancelThumb(int index) {
    final requestId = _thumbRequests.remove(index);
    if (requestId != null) {
      repository.cancelThumbnailRequest(requestId);
    }
  }

  void _evictTo(LinkedHashMap<int, Uint8List> cache, int max, Set<int>? keep) {
    final keys = cache.keys.toList(growable: false);
    for (final key in keys) {
      if (cache.length <= max) break;
      if (keep?.contains(key) ?? false) continue;
      cache.remove(key);
    }
  }

  @override
  void dispose() {
    for (final requestId in _previewRequests.values) {
      repository.cancelThumbnailRequest(requestId);
    }
    for (final requestId in _thumbRequests.values) {
      repository.cancelThumbnailRequest(requestId);
    }
    _previewRequests.clear();
    _thumbRequests.clear();
    super.dispose();
  }
}
