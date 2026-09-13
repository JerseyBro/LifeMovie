import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_app/widgets/media_preview.dart';
import 'package:memory_domain/memory_domain.dart';

/// Timeline exploration: year -> month -> asset clusters. Active discovery
/// (user-driven) complements the AI-driven For You feed.
class TimelinePage extends StatelessWidget {
  const TimelinePage({
    super.key,
    required this.assets,
    required this.repository,
    required this.onOpenAssets,
  });

  final List<MediaAsset> assets;
  final MediaRepository repository;

  /// Opens the fullscreen viewer for [assets] at [index] (with source rect).
  final void Function(List<MediaAsset> assets, int index, Rect? sourceRect)
  onOpenAssets;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.timelineEmpty,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    final byYear = _groupByYear(assets);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.large),
      children: [
        for (final year in byYear.keys)
          _YearSection(
            year: year,
            assets: byYear[year]!,
            repository: repository,
            onOpenAssets: onOpenAssets,
          ),
      ],
    );
  }

  static Map<int, List<MediaAsset>> _groupByYear(List<MediaAsset> assets) {
    final byYear = <int, List<MediaAsset>>{};
    for (final asset in assets) {
      final year = asset.creationDate?.year;
      if (year == null) continue;
      byYear.putIfAbsent(year, () => []).add(asset);
    }
    return Map.fromEntries(
      byYear.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }
}

class _YearSection extends StatelessWidget {
  const _YearSection({
    required this.year,
    required this.assets,
    required this.repository,
    required this.onOpenAssets,
  });

  final int year;
  final List<MediaAsset> assets;
  final MediaRepository repository;
  final void Function(List<MediaAsset> assets, int index, Rect? sourceRect)
  onOpenAssets;

  @override
  Widget build(BuildContext context) {
    final byMonth = _groupByMonth(assets);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.medium,
            bottom: AppSpacing.small,
          ),
          child: Text(
            '$year',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        for (final entry in byMonth.entries)
          _MonthSection(
            year: year,
            month: entry.key,
            assets: entry.value,
            repository: repository,
            onOpenAssets: onOpenAssets,
          ),
      ],
    );
  }

  static Map<int, List<MediaAsset>> _groupByMonth(List<MediaAsset> assets) {
    final byMonth = <int, List<MediaAsset>>{};
    for (final asset in assets) {
      final month = asset.creationDate?.month;
      if (month == null) continue;
      byMonth.putIfAbsent(month, () => []).add(asset);
    }
    return Map.fromEntries(
      byMonth.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }
}

class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.year,
    required this.month,
    required this.assets,
    required this.repository,
    required this.onOpenAssets,
  });

  final int year;
  final int month;
  final List<MediaAsset> assets;
  final MediaRepository repository;
  final void Function(List<MediaAsset> assets, int index, Rect? sourceRect)
  onOpenAssets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.timelineMonth(month),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xSmall),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: assets.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: AppSpacing.xSmall,
            crossAxisSpacing: AppSpacing.xSmall,
          ),
          itemBuilder: (context, index) => Builder(
            builder: (tileContext) => MediaPreviewTile(
              key: ValueKey(assets[index].id),
              repository: repository,
              assetId: assets[index].id,
              size: gridPreviewSize,
              onTap: () {
                Rect? rect;
                final box = tileContext.findRenderObject();
                if (box is RenderBox && box.hasSize) {
                  rect = box.localToGlobal(Offset.zero) & box.size;
                }
                onOpenAssets(assets, index, rect);
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
      ],
    );
  }
}
