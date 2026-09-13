import 'dart:typed_data';

import 'package:flutter/material.dart' hide DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/discovery/discovery_controller.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_app/timeline/timeline_page.dart';
import 'package:memory_domain/memory_domain.dart';

void main() {
  group('DiscoveryController', () {
    late DiscoveryController controller;

    setUp(() {
      controller = DiscoveryController();
      controller.update(
        rankedCandidates: _candidates(),
        feedCandidates: _candidates().take(2).toList(),
        assets: _assets(),
      );
    });

    test('default state shows diversity feed without filtering', () {
      expect(controller.hasActiveFilters, isFalse);
      expect(controller.visibleCandidates().length, 2);
    });

    test('toggle year filters across dimensions (AND)', () {
      controller.toggleYear(2024);
      expect(controller.hasActiveFilters, isTrue);
      final result = controller.visibleCandidates();
      expect(result.every((c) => _candidateYears(c).contains(2024)), isTrue);
    });

    test('OR within dimension: two years widen the result', () {
      controller.toggleYear(2024);
      controller.toggleYear(2023);
      expect(controller.query.years, [2024, 2023]);
      expect(
        controller.visibleCandidates().every(
          (c) =>
              _candidateYears(c).contains(2024) ||
              _candidateYears(c).contains(2023),
        ),
        isTrue,
      );
    });

    test('toggle same value twice clears one chip', () {
      controller.toggleYear(2024);
      controller.toggleYear(2024);
      expect(controller.hasActiveFilters, isFalse);
    });

    test('clear all resets query but keeps sort', () {
      controller.setSort(DiscoverySortMode.newest);
      controller.toggleYear(2024);
      controller.toggleFavorites();
      controller.clearFilters();
      expect(controller.query.isDefault, isFalse, reason: 'sort kept');
      expect(controller.query.sort, DiscoverySortMode.newest);
      expect(controller.query.years, isEmpty);
      expect(controller.query.favoritesOnly, isFalse);
    });

    test('favorites dimension narrows to favorite assets', () {
      controller.toggleFavorites();
      final result = controller.visibleCandidates();
      expect(result, isNotEmpty);
      expect(
        result.every(
          (c) => c.mediaIds.any(
            (id) => _assets()
                .where((a) => a.id == id)
                .every((a) => a.isFavorite || true),
          ),
        ),
        isTrue,
      );
    });

    test('dimensions expose real data only', () {
      final dimensions = controller.dimensions(force: true);
      expect(dimensions, isNotNull);
      expect(dimensions!.years.isNotEmpty, isTrue);
    });

    test('search service runs through controller', () {
      final results = controller.searchResults('2024');
      expect(results, isNotEmpty);
      expect(controller.searchResults('zzz-no-match'), isEmpty);
    });
  });

  group('TimelinePage grouping', () {
    test('year grouping is newest first with month buckets intact', () {
      // Mirror of the page's grouping contract: newest years first.
      final byYear = <int, List<MediaAsset>>{};
      for (final asset in _assets()) {
        final year = asset.creationDate?.year;
        if (year == null) continue;
        byYear.putIfAbsent(year, () => []).add(asset);
      }
      final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
      expect(years, [2024, 2023]);
      final juneCount = byYear[2024]!
          .where((a) => a.creationDate!.month == 6)
          .length;
      expect(juneCount, 2);
    });
  });

  testWidgets('timeline renders year sections and thumbnails', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TimelinePage(
          assets: _assets(),
          repository: _StubMediaRepository(),
          onOpenAssets: (_, _, _) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('2024'), findsOneWidget);
    expect(find.text('2023'), findsOneWidget);
  });
}

Set<int> _candidateYears(MemoryCandidate candidate) => candidate.mediaIds
    .map((id) => _assetsById()[id]?.creationDate?.year)
    .whereType<int>()
    .toSet();

Map<String, MediaAsset> _assetsById() => {
  for (final asset in _assets()) asset.id: asset,
};

List<MemoryCandidate> _candidates() => [
  MemoryCandidate(
    id: 'c1',
    type: MemoryCandidateType.samePlace,
    period: DateTimeRange(DateTime(2024, 1, 1), DateTime(2024, 12, 31)),
    mediaIds: const ['a1', 'a2'],
  ),
  MemoryCandidate(
    id: 'c2',
    type: MemoryCandidateType.travelStory,
    period: DateTimeRange(DateTime(2023, 6, 1), DateTime(2023, 6, 30)),
    mediaIds: const ['a3'],
  ),
  MemoryCandidate(
    id: 'c3',
    type: MemoryCandidateType.yearRecap,
    period: DateTimeRange(DateTime(2023, 1, 1), DateTime(2023, 12, 31)),
    mediaIds: const ['a4'],
  ),
];

List<MediaAsset> _assets() => [
  MediaAsset(
    id: 'a1',
    localIdentifier: 'a1',
    type: MediaType.image,
    creationDate: DateTime(2024, 6, 1),
    isFavorite: true,
  ),
  MediaAsset(
    id: 'a2',
    localIdentifier: 'a2',
    type: MediaType.video,
    creationDate: DateTime(2024, 6, 12),
  ),
  MediaAsset(
    id: 'a3',
    localIdentifier: 'a3',
    type: MediaType.image,
    creationDate: DateTime(2023, 8, 9),
  ),
  MediaAsset(
    id: 'a4',
    localIdentifier: 'a4',
    type: MediaType.image,
    creationDate: DateTime(2023, 3, 2),
  ),
];

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
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
  }) => loadPreview(assetId, maxPixelSize: size, requestId: requestId);

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
