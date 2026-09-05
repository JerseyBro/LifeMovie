import 'package:ai_gateway/ai_gateway.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_app/presentation/memory_candidate_copy_mapper.dart';
import 'package:memory_app/screens/photo_viewer_page.dart';
import 'package:memory_app/widgets/media_preview.dart';
import 'package:memory_domain/memory_domain.dart';
import 'package:memory_engine/memory_engine.dart';

/// Story detail V2: hero, title, time/place/count, summary,
/// highlights grid, year timeline, metadata-light, feedback slot.
///
/// Every visible photo opens fullscreen viewer at tapped index.
class MemoryDetailPage extends StatelessWidget {
  const MemoryDetailPage({
    super.key,
    required this.candidate,
    required this.allAssets,
    required this.representativeAssets,
    required this.onBack,
    required this.ai,
    required this.repository,
    required this.ranker,
    required this.contextAssets,
  });

  final MemoryCandidate candidate;
  final List<MediaAsset> allAssets;
  final List<MediaAsset> representativeAssets;
  final VoidCallback onBack;
  final AiService ai;
  final MediaRepository repository;
  final MemoryRanker ranker;
  final List<MediaAsset> contextAssets;

  void _openViewer(
    BuildContext context,
    List<MediaAsset> assets,
    int initialIndex,
  ) {
    if (assets.isEmpty) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => FullscreenPhotoViewerPage(
          repository: repository,
          assets: assets,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final photos = allAssets
        .where(
          (a) => a.type == MediaType.image || a.type == MediaType.livePhoto,
        )
        .length;
    final videos = allAssets.where((a) => a.type == MediaType.video).length;
    final hasLocation = allAssets.any((a) => a.location != null);
    final breakdown = ranker.explain(
      candidate,
      MemoryContext(assets: contextAssets),
    );
    final byYear = _assetsByYear(allAssets);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: Text(l10n.detailTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: [
          if (representativeAssets.isNotEmpty)
            GestureDetector(
              onTap: () => _openViewer(context, representativeAssets, 0),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: MediaPreview(
                  repository: repository,
                  assetId: representativeAssets.first.id,
                  size: detailPreviewSize,
                  usePreview: true,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.large),
          Text(
            const MemoryCandidateCopyMapper().map(candidate, l10n).title,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            _dateRange(candidate),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.small),
          Text('${l10n.detailPhotos(photos)} · ${l10n.detailVideos(videos)}'),
          if (hasLocation) Text(l10n.detailLocationHint),
          const SizedBox(height: AppSpacing.large),
          _ThumbnailGrid(
            repository: repository,
            assets: representativeAssets.take(12).toList(),
            onOpen: (index) => _openViewer(
              context,
              representativeAssets.take(12).toList(),
              index,
            ),
          ),
          const SizedBox(height: AppSpacing.large),
          Text(
            l10n.detailTimeline,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ...byYear.entries.map(
            (entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TimelineYearLabel(year: entry.key),
                _ThumbnailGrid(
                  repository: repository,
                  assets: entry.value.take(6).toList(),
                  onOpen: (index) =>
                      _openViewer(context, entry.value.take(6).toList(), index),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.large),
          FutureBuilder<String>(
            future: ai.generateMemorySummary(memoryId: candidate.id),
            builder: (context, snapshot) => Text(
              snapshot.data ?? l10n.detailAiPlaceholder,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          if (kDebugMode) ...[
            const Divider(height: AppSpacing.xLarge),
            Text(
              'Debug: ${candidate.type.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...candidate.reasons.map(
              (reason) => ListTile(dense: true, title: Text(reason)),
            ),
            Text('Score ${breakdown.finalScore.toStringAsFixed(1)}'),
            ...breakdown.factors.entries.map(
              (entry) => ListTile(
                dense: true,
                title: Text(entry.key),
                trailing: Text(entry.value.toStringAsFixed(1)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThumbnailGrid extends StatelessWidget {
  const _ThumbnailGrid({
    required this.repository,
    required this.assets,
    required this.onOpen,
  });

  final MediaRepository repository;
  final List<MediaAsset> assets;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: assets.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: AppSpacing.small,
      crossAxisSpacing: AppSpacing.small,
    ),
    itemBuilder: (context, index) => MediaPreviewTile(
      key: ValueKey(assets[index].id),
      repository: repository,
      assetId: assets[index].id,
      size: gridPreviewSize,
      onTap: () => onOpen(index),
    ),
  );
}

String _dateRange(MemoryCandidate c) {
  final start = c.period.start;
  final end = c.period.end;
  return '${start.year}.${start.month}.${start.day} — ${end.year}.${end.month}.${end.day}';
}

Map<int, List<MediaAsset>> _assetsByYear(List<MediaAsset> assets) {
  final result = <int, List<MediaAsset>>{};
  for (final asset in assets) {
    final year = asset.creationDate?.year;
    if (year == null) continue;
    (result[year] ??= []).add(asset);
  }
  return Map.fromEntries(
    result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}
