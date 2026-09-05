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

    // onTap shares the recognizer with onDoubleTap, so it fires only after
    // the double-tap timeout. pumpAndSettle alone never advances that timer.
    await tester.tap(find.byType(PageView));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(FullscreenPhotoViewerPage), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('viewer downward drag dismisses when not zoomed', (tester) async {
    final repository = _RecordingMediaRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: FullscreenPhotoViewerPage(
          repository: repository,
          assets: _assets(2),
          initialIndex: 0,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FullscreenPhotoViewerPage), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(0, 400), 900);
    await tester.pumpAndSettle();

    expect(find.byType(FullscreenPhotoViewerPage), findsNothing);
  });

  testWidgets('viewer horizontal swipe blocked while zoomed', (tester) async {
    final repository = _RecordingMediaRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: FullscreenPhotoViewerPage(
          repository: repository,
          assets: _assets(2),
          initialIndex: 0,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byType(PageView));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
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

/// Minimal 1x1 transparent PNG so image widgets render real pixels.
final Uint8List _transparentPixel = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x18, 0x05, 0xA3,
  0x60, 0x14, 0x8C, 0x02, 0x00, 0x00, 0x0D, 0x00, 0x01, 0xE2, 0xB8, 0x1E,
  0xE6, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60,
  0x82,
]);

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
    return _transparentPixel;
  }

  @override
  Future<Uint8List?> loadThumbnail(
    String assetId, {
    int size = 320,
    String? requestId,
  }) async {
    thumbnailSizes.add(size);
    return _transparentPixel;
  }

  @override
  Future<MediaPermissionStatus> presentLimitedLibraryPicker() async =>
      MediaPermissionStatus.authorized;

  @override
  Future<MediaPermissionStatus> requestPermission() async =>
      MediaPermissionStatus.authorized;
}
