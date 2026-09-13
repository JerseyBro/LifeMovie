import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_app/media_editor/edit_recipe_store.dart';
import 'package:memory_app/media_editor/edit_render.dart';
import 'package:memory_app/media_editor/media_editor_page.dart';
import 'package:memory_domain/memory_domain.dart';

void main() {
  group('EditRecipe model', () {
    test('default recipe is identity', () {
      expect(const EditRecipe().isIdentity, isTrue);
      expect(
        const EditRecipe(
          adjustments: EditAdjustments(exposure: 0.5),
        ).isIdentity,
        isFalse,
      );
    });

    test('json round-trip preserves edits', () {
      const recipe = EditRecipe(
        rotationQuarterTurns: 1,
        straightenDegrees: -3.5,
        crop: EditCropRect(left: 0.1, top: 0.2, width: 0.5, height: 0.5),
        adjustments: EditAdjustments(exposure: 0.4, warmth: -0.2),
        filter: EditFilter.mono,
      );
      final decoded = EditRecipe.fromJson(
        recipe.toJson().cast<String, Object?>(),
      );
      expect(decoded.rotationQuarterTurns, recipe.rotationQuarterTurns);
      expect(decoded.straightenDegrees, recipe.straightenDegrees);
      expect(decoded.crop, recipe.crop);
      expect(decoded.adjustments, recipe.adjustments);
      expect(decoded.filter, EditFilter.mono);
    });

    test('rotation wraps modulo 4', () {
      expect(const EditRecipe().rotated(1).rotationQuarterTurns, 1);
      expect(const EditRecipe().rotated(5).rotationQuarterTurns, 1);
      expect(const EditRecipe().rotated(-1).rotationQuarterTurns, 3);
    });

    test('center crop respects aspect', () {
      final square = EditCropRect.centerForAspect(1);
      expect(square.width, 1);
      expect(square.height, 1);
      final wide = EditCropRect.centerForAspect(16 / 9);
      expect(wide.height, closeTo(9 / 16, 1e-9));
      expect(wide.left, 0);
      expect(wide.top, closeTo((1 - 9 / 16) / 2, 1e-9));
    });
  });

  group('color matrix pipeline', () {
    test('identity recipe yields identity matrix', () {
      final matrix = colorMatrixFor(const EditAdjustments(), EditFilter.none);
      expect(matrix, [
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0, //
        0, 0, 1, 0, 0, //
        0, 0, 0, 1, 0,
      ]);
    });

    test('mono filter removes chroma (luma rows)', () {
      final matrix = colorMatrixFor(const EditAdjustments(), EditFilter.mono);
      final r = matrix.sublist(0, 5);
      final g = matrix.sublist(5, 10);
      final b = matrix.sublist(10, 15);
      // Luma weights: each row is the same luma vector.
      expect(r[0], closeTo(0.213, 1e-6));
      expect(r[1], closeTo(0.715, 1e-6));
      expect(r[2], closeTo(0.072, 1e-6));
      expect(g, equals(r));
      expect(b, equals(r));
    });

    test('warmth shifts red up and blue down', () {
      final matrix = colorMatrixFor(
        const EditAdjustments(warmth: 0.5),
        EditFilter.none,
      );
      final rOffset = matrix[4];
      final bOffset = matrix[14];
      expect(rOffset, greaterThan(0));
      expect(bOffset, lessThan(0));
    });

    test('exposure scales rgb gain', () {
      final matrix = colorMatrixFor(
        const EditAdjustments(exposure: 0.5),
        EditFilter.none,
      );
      expect(matrix[0], greaterThan(1));
      expect(matrix[6], greaterThan(1));
    });
  });

  group('EditRecipeStore (non-destructive persistence)', () {
    late Directory tempDir;
    late File file;
    late EditRecipeStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('lifemovie_edit_test');
      file = File('${tempDir.path}/recipes.json');
      store = EditRecipeStore(file);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('save and load round-trip', () async {
      const recipe = EditRecipe(filter: EditFilter.vivid);
      await store.save('asset-1', recipe);
      final fresh = EditRecipeStore(file);
      expect(await fresh.load('asset-1'), isNotNull);
      final loaded = await fresh.load('asset-1');
      expect(loaded!.filter, EditFilter.vivid);
    });

    test('identity recipe is removed instead of stored', () async {
      await store.save('asset-1', const EditRecipe(filter: EditFilter.warm));
      await store.save('asset-1', const EditRecipe());
      final fresh = EditRecipeStore(file);
      expect(await fresh.load('asset-1'), isNull);
    });

    test('remove clears recipe', () async {
      await store.save('asset-1', const EditRecipe(filter: EditFilter.cool));
      await store.remove('asset-1');
      expect(await store.load('asset-1'), isNull);
    });

    test('in-memory store never touches disk', () async {
      final memory = EditRecipeStore.inMemory();
      await memory.save('asset-1', const EditRecipe(filter: EditFilter.mono));
      expect(await memory.load('asset-1'), isNotNull);
    });
  });

  group('editor widget', () {
    testWidgets('done persists the recipe, cancel leaves store untouched', (
      tester,
    ) async {
      final repository = _StubMediaRepository();
      // In-memory store: real file I/O does not complete inside the test
      // fake-async zone; file persistence is covered by the group above.
      final store = EditRecipeStore.inMemory();
      final asset = _asset('edit-1');

      await tester.pumpWidget(
        _wrapWithRoute(
          MediaEditorPage(repository: repository, asset: asset, store: store),
        ),
      );
      await tester.pumpAndSettle();

      // Move exposure slider, then save.
      await tester.drag(find.byType(Slider).first, const Offset(80, 0));
      await tester.pump();
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      final saved = await store.load(asset.id);
      expect(saved, isNotNull);
      expect(saved!.adjustments.exposure, greaterThan(0));

      // Reopen with a clean in-memory view of the same recipe, then cancel:
      // the stored recipe must remain exactly what was saved before.
      await tester.pumpWidget(
        _wrapWithRoute(
          MediaEditorPage(
            repository: repository,
            asset: asset,
            store: store,
            initialRecipe: saved,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      final afterCancel = await store.load(asset.id);
      expect(afterCancel!.adjustments.exposure, saved.adjustments.exposure);
    });

    testWidgets('reset button restores identity adjustments', (tester) async {
      final repository = _StubMediaRepository();
      final store = EditRecipeStore.inMemory();

      await tester.pumpWidget(
        _wrapWithRoute(
          MediaEditorPage(
            repository: repository,
            asset: _asset('edit-2'),
            store: store,
            initialRecipe: const EditRecipe(
              adjustments: EditAdjustments(contrast: 0.5),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Reset row sits below the seven sliders: scroll it into view.
      await tester.scrollUntilVisible(
        find.text('还原'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();
      await tester.tap(find.text('还原'));
      await tester.pump();

      // Reset clears adjustments: the recipe becomes identity, and an
      // identity recipe is intentionally not persisted.
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      final saved = await store.load('edit-2');
      expect(
        saved,
        isNull,
        reason:
            'identity recipe must not be persisted (non-destructive '
            'store contract)',
      );
    });
  });
}

MediaAsset _asset(String id) => MediaAsset(
  id: id,
  localIdentifier: id,
  type: MediaType.image,
  creationDate: DateTime(2026, 8, 1),
  width: 1200,
  height: 900,
);

/// Hosts [page] as a pushed route so pop() returns to a valid home.
Widget _wrapWithRoute(Widget page) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => page));
      });
      return const Scaffold();
    },
  ),
);

class _StubMediaRepository implements MediaRepository {
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
  }) async => Uint8List.fromList(const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x60,
    0x18,
    0x05,
    0xA3,
    0x60,
    0x14,
    0x8C,
    0x02,
    0x00,
    0x00,
    0x0D,
    0x00,
    0x01,
    0xE2,
    0xB8,
    0x1E,
    0xE6,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);

  @override
  Future<Uint8List?> loadThumbnail(
    String assetId, {
    int size = 320,
    String? requestId,
  }) async => Uint8List.fromList(const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x60,
    0x18,
    0x05,
    0xA3,
    0x60,
    0x14,
    0x8C,
    0x02,
    0x00,
    0x00,
    0x0D,
    0x00,
    0x01,
    0xE2,
    0xB8,
    0x1E,
    0xE6,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);

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
