import 'dart:typed_data';

import 'package:flutter/material.dart' hide DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/screens/photo_viewer_page.dart';
import 'package:memory_app/widgets/media_preview.dart';
import 'package:memory_domain/memory_domain.dart';

void main() {
  testWidgets('viewer opens at requested initial index and swipes pages', (
    tester,
  ) async {
    final repository = _RecordingMediaRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: FullscreenPhotoViewerPage(
          repository: repository,
          assets: _assets(3),
          initialIndex: 1,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2 / 3'), findsOneWidget);
    expect(repository.previewSizes, contains(viewerPreviewSize));

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('3 / 3'), findsOneWidget);
  });

  testWidgets('viewer tap toggles chrome instead of closing immediately', (
    tester,
  ) async {
    final repository = _RecordingMediaRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: FullscreenPhotoViewerPage(
          repository: repository,
          assets: _assets(1),
          initialIndex: 0,
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();

    expect(find.byType(FullscreenPhotoViewerPage), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets(
    'media preview separates feed thumbnail from high quality preview',
    (tester) async {
      final repository = _RecordingMediaRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              SizedBox(
                height: 120,
                child: MediaPreviewTile(
                  repository: repository,
                  assetId: 'a0',
                  size: feedPreviewSize,
                ),
              ),
              SizedBox(
                height: 120,
                child: MediaPreview(
                  repository: repository,
                  assetId: 'a1',
                  size: detailPreviewSize,
                  usePreview: true,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(repository.thumbnailSizes, contains(feedPreviewSize));
      expect(repository.previewSizes, contains(detailPreviewSize));
    },
  );
}

List<MediaAsset> _assets(int count) => List.generate(
  count,
  (i) => MediaAsset(
    id: 'asset-$i',
    localIdentifier: 'asset-$i',
    type: MediaType.image,
    creationDate: DateTime(2026, 8, i + 1),
    width: 1200,
    height: 900,
  ),
);

class _RecordingMediaRepository implements MediaRepository {
  final thumbnailSizes = <int>[];
  final previewSizes = <int>[];

  @override
  Future<void> cancelThumbnailRequest(String requestId) async {}

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
    previewSizes.add(maxPixelSize ?? 0);
    return null;
  }

  @override
  Future<Uint8List?> loadThumbnail(
    String assetId, {
    int size = 320,
    String? requestId,
  }) async {
    thumbnailSizes.add(size);
    return null;
  }

  @override
  Future<MediaPermissionStatus> presentLimitedLibraryPicker() async =>
      MediaPermissionStatus.authorized;

  @override
  Future<MediaPermissionStatus> requestPermission() async =>
      MediaPermissionStatus.authorized;
}
