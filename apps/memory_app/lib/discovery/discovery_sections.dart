import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_app/presentation/memory_candidate_copy_mapper.dart';
import 'package:memory_app/widgets/media_preview.dart';
import 'package:memory_domain/memory_domain.dart';

/// Reusable pieces of the Discovery surfaces: active filter chips, sort bar,
/// and compact candidate cards for explore rows.

class ActiveFilterChips extends StatelessWidget {
  const ActiveFilterChips({
    super.key,
    required this.query,
    required this.onRemove,
    required this.onClearAll,
  });

  final MemoryDiscoveryQuery query;
  final void Function(DiscoveryFilterKey key, Object? value) onRemove;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chips = <Widget>[
      for (final year in query.years)
        _chip('$year', () => onRemove(DiscoveryFilterKey.years, year)),
      for (final place in query.placeIds)
        _chip(
          place.startsWith('cluster-')
              ? '$l10n.filterPlacePrefix ${place.substring(8)}'
              : place,
          () => onRemove(DiscoveryFilterKey.places, place),
        ),
      for (final person in query.personIds)
        _chip(
          l10n.filterPerson,
          () => onRemove(DiscoveryFilterKey.people, person),
        ),
      for (final type in query.memoryTypes)
        _chip(
          _memoryTypeLabel(type, l10n),
          () => onRemove(DiscoveryFilterKey.memoryTypes, type),
        ),
      for (final media in query.mediaTypes)
        _chip(
          media == MediaType.video ? l10n.filterVideos : l10n.filterPhotos,
          () => onRemove(DiscoveryFilterKey.mediaTypes, media),
        ),
      if (query.favoritesOnly)
        _chip(
          l10n.filterFavorites,
          () => onRemove(DiscoveryFilterKey.favorites, null),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: AppSpacing.xSmall,
              runSpacing: AppSpacing.xSmall,
              children: chips,
            ),
          ),
          TextButton(onPressed: onClearAll, child: Text(l10n.filterClearAll)),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onDeleted) => InputChip(
    label: Text(label),
    onDeleted: onDeleted,
    visualDensity: VisualDensity.compact,
  );
}

String _memoryTypeLabel(MemoryCandidateType type, AppLocalizations l10n) =>
    switch (type) {
      MemoryCandidateType.travelStory => l10n.sectionTrips,
      MemoryCandidateType.yearRecap => l10n.sectionYears,
      MemoryCandidateType.personTimeline => l10n.sectionPeople,
      MemoryCandidateType.samePlace => l10n.sectionPlaces,
      MemoryCandidateType.samePlaceAcrossYears => l10n.memoryTypeRevisit,
      MemoryCandidateType.firstMemory => l10n.sectionFirstMemories,
      MemoryCandidateType.annualTogether => l10n.sectionTogether,
      MemoryCandidateType.longTermEvolution => l10n.sectionEvolution,
      MemoryCandidateType.dateCluster => l10n.memoryTypeGathering,
    };

class SortBar extends StatelessWidget {
  const SortBar({super.key, required this.sort, required this.onSort});

  final DiscoverySortMode sort;
  final ValueChanged<DiscoverySortMode> onSort;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final modes = <DiscoverySortMode, String>{
      DiscoverySortMode.recommended: l10n.sortRecommended,
      DiscoverySortMode.newest: l10n.sortNewest,
      DiscoverySortMode.oldest: l10n.sortOldest,
      DiscoverySortMode.mostPhotos: l10n.sortMostPhotos,
    };
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final entry in modes.entries)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xSmall),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: sort == entry.key,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onSort(entry.key),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact story card used in explore rows and search results.
class MemoryCandidateTile extends StatelessWidget {
  const MemoryCandidateTile({
    super.key,
    required this.repository,
    required this.candidate,
    required this.onTap,
    this.width = 200,
  });

  final MediaRepository repository;
  final MemoryCandidate candidate;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final copy = const MemoryCandidateCopyMapper().map(candidate, l10n);
    final coverId =
        candidate.representativeMediaIds.firstOrNull ??
        candidate.mediaIds.firstOrNull;
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 110,
                width: double.infinity,
                child: MediaPreview(
                  repository: repository,
                  assetId: coverId,
                  size: feedPreviewSize,
                  borderRadius: 0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.small),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xSmall),
                    Text(
                      copy.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal explore row: title + cards, only rendered by callers when the
/// dimension actually has data (no empty shells).
class ExploreRow extends StatelessWidget {
  const ExploreRow({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.small),
      SizedBox(
        height: 210,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.small),
          itemBuilder: (_, index) => children[index],
        ),
      ),
    ],
  );
}
