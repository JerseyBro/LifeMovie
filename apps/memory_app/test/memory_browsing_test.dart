import 'dart:typed_data';

import 'package:ai_gateway/ai_gateway.dart';
import 'package:flutter/material.dart' hide DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_app/screens/memory_detail_page.dart';
import 'package:memory_app/widgets/media_preview.dart';
import 'package:memory_app/widgets/memory_card.dart';
import 'package:memory_domain/memory_domain.dart';
import 'package:memory_engine/memory_engine.dart';

void main() {
  testWidgets('memory card shows light type eyebrow, no rule name', (
    tester,
  ) async {
    final repository = _RecordingMediaRepository();
    final candidate = _candidate(MemoryCandidateType.samePlace);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: ListView(
            children: [
              MemoryCard(
                candidate: candidate,
                repository: repository,
                thumbnailAssetId: 'asset-0',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('地点'), findsOneWidget);
    expect(find.text('SamePlaceRule'), findsNothing);
  });

  testWidgets('detail hero loads medium preview and grid opens viewer', (
    tester,
  ) async {
    final repository = _RecordingMediaRepository();
    final candidate = _candidate(MemoryCandidateType.dateCluster);
    final assets = _assets(3);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: MemoryDetailPage(
          candidate: candidate,
          allAssets: assets,
          representativeAssets: assets,
          onBack: () {},
          ai: const MockAiProvider(),
          repository: repository,
          ranker: _NoopRanker(),
          contextAssets: assets,
        ),
      ),
    );
    await tester.pump();

    expect(repository.previewSizes, contains(detailPreviewSize));
  });
}

MemoryCandidate _candidate(MemoryCandidateType type) => MemoryCandidate(
  id: 'candidate-1',
  type: type,
  period: DateTimeRange(DateTime(2026, 8, 1), DateTime(2026, 8, 3)),
  mediaIds: const ['asset-0', 'asset-1', 'asset-2'],
  representativeMediaIds: const ['asset-0', 'asset-1', 'asset-2'],
);

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

class _NoopRanker implements MemoryRanker {
  @override
  MemoryScoreBreakdown explain(
    MemoryCandidate candidate,
    MemoryContext context,
  ) => const MemoryScoreBreakdown(score: 80, factors: {'accuracy': 80});

  @override
  List<MemoryCandidate> rank(
    List<MemoryCandidate> candidates,
    MemoryContext context,
  ) => candidates;
}

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
