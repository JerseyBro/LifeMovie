import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/media_viewer/viewer_media_loader.dart';
import 'package:memory_app/widgets/media_preview.dart';
import 'package:memory_domain/memory_domain.dart';

void main() {
  test('loader prefetches preview window N-1/N/N+1 only', () async {
    final repository = _RecordingMediaRepository();
    final loader = _loader(repository, 6);

    loader.focus(2);
    await _drain();

    expect(
      repository.previewedAssets,
      {'asset-1', 'asset-2', 'asset-3'},
      reason: 'window N-1/N/N+1 gets previews, N+2 must not',
    );
    expect(repository.thumbAssets.length, 3);
  });

  test(
    'loader cancels in-flight preview requests outside the focus window',
    () async {
      final repository = _InFlightPreviewRepository();
      final loader = _loader(repository, 6);

      loader.focus(0);
      await _drain();
      expect(repository.previewedAssets, {'asset-0', 'asset-1'});

      loader.focus(3);
      await _drain();

      expect(
        repository.cancelledRequestIds,
        containsAll(<String>[
          'viewer-preview-asset-0-0',
          'viewer-preview-asset-1-1',
        ]),
        reason: 'requests outside the new window must be cancelled',
      );
    },
  );

  test('preview byte cache evicts entries outside the focus window', () async {
    final repository = _RecordingMediaRepository();
    final loader = _loader(repository, 6);

    loader.focus(0);
    await _drain();
    expect(loader.previewFor(0), isNotNull);

    loader.focus(2);
    await _drain();

    expect(
      loader.previewFor(0),
      isNull,
      reason: 'preview window must stay within memory budget',
    );
    expect(loader.previewFor(1), isNotNull);
    expect(loader.previewFor(2), isNotNull);
    expect(loader.previewFor(3), isNotNull);
  });

  test('failed preview marks failure and retry reloads', () async {
    final repository = _FailingPreviewRepository();
    final loader = _loader(repository, 2);

    loader.focus(0);
    await _drain();

    expect(loader.isPreviewFailed(0), isTrue);
    expect(loader.previewFor(0), isNull);

    repository.fail = false;
    await loader.retryPreview(0);
    await _drain();

    expect(loader.isPreviewFailed(0), isFalse);
    expect(loader.previewFor(0), isNotNull);
  });

  test('dispose cancels in-flight requests', () async {
    final repository = _InFlightPreviewRepository();
    final loader = _loader(repository, 6);

    loader.focus(1);
    await _drain();
    loader.dispose();

    expect(repository.cancelledRequestIds.length, greaterThanOrEqualTo(3));
  });
}

ViewerMediaLoader _loader(_RecordingMediaRepository repository, int count) =>
    ViewerMediaLoader(
      repository: repository,
      assets: List.generate(
        count,
        (i) => MediaAsset(
          id: 'asset-$i',
          localIdentifier: 'asset-$i',
          type: MediaType.image,
          creationDate: DateTime(2026, 8, i + 1),
        ),
      ),
      previewPixelSize: viewerPreviewSize,
      thumbPixelSize: gridPreviewSize,
    );

Future<void> _drain() => Future<void>.delayed(Duration.zero);

class _RecordingMediaRepository implements MediaRepository {
  final previewedAssets = <String>{};
  final thumbAssets = <String>{};
  final cancelledRequestIds = <String>{};

  @override
  Future<void> cancelThumbnailRequest(String requestId) async {
    cancelledRequestIds.add(requestId);
  }

  @override
  Future<List<MediaAsset>> fetchAssets({
    int offset = 0,
    int limit = 200,
    MediaTypeFilter filter = MediaTypeFilter.all,
  }) async => const [];

  @override
  Future<List<MediaAsset>> fetchAssetsByDateRange(
    DateTimeRange range, {
    MediaTypeFilter filter = MediaTypeFilter.all,
    int offset = 0,
    int limit = 500,
  }) async => const [];

  @override
  Future<MediaPermissionStatus> getPermissionStatus() async =>
      MediaPermissionStatus.authorized;

  @override
  Future<Uint8List?> loadPreview(
    String assetId, {
    int? maxPixelSize,
    String? requestId,
  }) async {
    previewedAssets.add(assetId);
    return Uint8List.fromList(const [1, 2, 3]);
  }

  @override
  Future<Uint8List?> loadThumbnail(
    String assetId, {
    int size = 320,
    String? requestId,
  }) async {
    thumbAssets.add(assetId);
    return Uint8List.fromList(const [1, 2, 3]);
  }

  @override
  Future<MediaPermissionStatus> presentLimitedLibraryPicker() async =>
      MediaPermissionStatus.authorized;

  @override
  Future<MediaPermissionStatus> requestPermission() async =>
      MediaPermissionStatus.authorized;

  @override
  Future<bool> setFavorite(String assetId, {required bool favorite}) async =>
      true;

  @override
  Future<bool> presentShareSheet(String assetId) async => false;

  @override
  Future<String?> loadVideoPlaybackUrl(String assetId) async => null;

  @override
  Future<String?> loadPlaceLabel(GeoPoint location) async => null;
}

/// Previews never complete: models in-flight high-quality requests so
/// cancellation paths can be exercised.
class _InFlightPreviewRepository extends _RecordingMediaRepository {
  @override
  Future<Uint8List?> loadPreview(
    String assetId, {
    int? maxPixelSize,
    String? requestId,
  }) {
    previewedAssets.add(assetId);
    return Completer<Uint8List?>().future;
  }
}

class _FailingPreviewRepository extends _RecordingMediaRepository {
  bool fail = true;

  @override
  Future<Uint8List?> loadPreview(
    String assetId, {
    int? maxPixelSize,
    String? requestId,
  }) async {
    previewedAssets.add(assetId);
    if (fail) throw const MediaFailure('boom', 'preview failed');
    return Uint8List.fromList(const [1, 2, 3]);
  }
}
