import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/discovery/discovery_controller.dart';
import 'package:memory_app/discovery/discovery_sections.dart';
import 'package:memory_app/discovery/place_label_resolver.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_app/presentation/memory_candidate_copy_mapper.dart';
import 'package:memory_app/widgets/media_preview.dart';
import 'package:memory_app/widgets/memory_card.dart';
import 'package:memory_domain/memory_domain.dart';
import 'package:memory_engine/memory_engine.dart';

/// Memory Discovery Home (For You).
///
/// 第一屏只突出一个最值得看的 Memory（Hero），随后是按真实数据出现的
/// Explore 维度（地点/人物/旅途/年份/初见/相聚/变化）与 Memory Cards。
/// 禁止 score / rule / AI badge / 技术标签。
class DiscoveryHome extends StatelessWidget {
  const DiscoveryHome({
    super.key,
    required this.controller,
    required this.repository,
    required this.placeLabels,
    required this.stats,
    required this.onOpenCandidate,
    required this.onRetryScan,
    required this.onFeedback,
  });

  final DiscoveryController controller;
  final MediaRepository repository;
  final PlaceLabelResolver placeLabels;
  final MediaIndexStats? stats;
  final ValueChanged<MemoryCandidate> onOpenCandidate;
  final VoidCallback onRetryScan;
  final Future<void> Function(MemoryCandidate candidate, List<String> labels)?
  onFeedback;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final dimensions = controller.dimensions();
        final visible = controller.visibleCandidates();
        final hero = controller.feedCandidates.isEmpty
            ? null
            : controller.feedCandidates.first;
        return RefreshIndicator(
          onRefresh: () async => onRetryScan(),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.large),
            children: [
              Text(
                l10n.discoverForYou,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xSmall),
              if (hero != null) ...[
                _HeroMemory(
                  repository: repository,
                  candidate: hero,
                  onTap: () => onOpenCandidate(hero),
                ),
                const SizedBox(height: AppSpacing.large),
              ] else
                _EmptyDiscover(onRetry: onRetryScan),
              if (dimensions != null && dimensions.recentDiscoveries.length > 1)
                ExploreRow(
                  title: l10n.sectionRecent,
                  children: [
                    for (final candidate in dimensions.recentDiscoveries.skip(
                      1,
                    ))
                      MemoryCandidateTile(
                        repository: repository,
                        candidate: candidate,
                        onTap: () => onOpenCandidate(candidate),
                      ),
                  ],
                ),
              if (dimensions != null && dimensions.places.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.large),
                _PlacesRow(
                  repository: repository,
                  places: dimensions.places,
                  placeLabels: placeLabels,
                  onOpen: (place) {
                    controller.clearFilters();
                    controller.togglePlace(place.placeId);
                  },
                ),
              ],
              if (dimensions != null &&
                  dimensions.hasPersonData &&
                  dimensions.people.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.large),
                ExploreRow(
                  title: l10n.sectionPeople,
                  children: [
                    for (final person in dimensions.people.take(10))
                      _PersonCard(
                        repository: repository,
                        person: person,
                        onTap: () {
                          controller.clearFilters();
                          controller.togglePerson(person.personId);
                        },
                      ),
                  ],
                ),
              ],
              if (dimensions != null && dimensions.trips.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.large),
                ExploreRow(
                  title: l10n.sectionTrips,
                  children: [
                    for (final candidate in dimensions.trips.take(10))
                      MemoryCandidateTile(
                        repository: repository,
                        candidate: candidate,
                        onTap: () => onOpenCandidate(candidate),
                      ),
                  ],
                ),
              ],
              if (dimensions != null && dimensions.years.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.large),
                Text(
                  l10n.sectionYears,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.small),
                Wrap(
                  spacing: AppSpacing.xSmall,
                  runSpacing: AppSpacing.xSmall,
                  children: [
                    for (final year in dimensions.years.keys.take(8))
                      ActionChip(
                        label: Text('$year · ${dimensions.years[year]}'),
                        onPressed: () {
                          controller.clearFilters();
                          controller.toggleYear(year);
                        },
                      ),
                  ],
                ),
              ],
              if (dimensions != null &&
                  dimensions.firstMemories.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.large),
                ExploreRow(
                  title: l10n.sectionFirstMemories,
                  children: [
                    for (final candidate in dimensions.firstMemories.take(10))
                      MemoryCandidateTile(
                        repository: repository,
                        candidate: candidate,
                        onTap: () => onOpenCandidate(candidate),
                      ),
                  ],
                ),
              ],
              if (dimensions != null &&
                  dimensions.annualTogether.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.large),
                ExploreRow(
                  title: l10n.sectionTogether,
                  children: [
                    for (final candidate in dimensions.annualTogether.take(10))
                      MemoryCandidateTile(
                        repository: repository,
                        candidate: candidate,
                        onTap: () => onOpenCandidate(candidate),
                      ),
                  ],
                ),
              ],
              if (dimensions != null && dimensions.evolutions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.large),
                ExploreRow(
                  title: l10n.sectionEvolution,
                  children: [
                    for (final candidate in dimensions.evolutions.take(10))
                      MemoryCandidateTile(
                        repository: repository,
                        candidate: candidate,
                        onTap: () => onOpenCandidate(candidate),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.large),
              Text(
                l10n.discoverStories,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (controller.hasActiveFilters) ...[
                ActiveFilterChips(
                  query: controller.query,
                  onRemove: (key, value) {
                    final updated = controller.query.without(key, value);
                    controller.clearFilters();
                    // Re-apply the remaining selections.
                    for (final year in updated.years) {
                      controller.toggleYear(year);
                    }
                    for (final place in updated.placeIds) {
                      controller.togglePlace(place);
                    }
                    for (final person in updated.personIds) {
                      controller.togglePerson(person);
                    }
                    for (final type in updated.memoryTypes) {
                      controller.toggleMemoryType(type);
                    }
                    for (final media in updated.mediaTypes) {
                      controller.toggleMediaType(media);
                    }
                    if (updated.favoritesOnly) controller.toggleFavorites();
                  },
                  onClearAll: controller.clearFilters,
                ),
                SortBar(
                  sort: controller.query.sort,
                  onSort: controller.setSort,
                ),
              ],
              const SizedBox(height: AppSpacing.small),
              if (visible.isEmpty && controller.hasActiveFilters)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xLarge,
                  ),
                  child: Text(
                    l10n.discoverNoResults,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else if (hero == null)
                const SizedBox.shrink()
              else
                ...visible.map(
                  (candidate) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.large),
                    child: MemoryCard(
                      candidate: candidate,
                      repository: repository,
                      thumbnailAssetId:
                          candidate.representativeMediaIds.firstOrNull ??
                          candidate.mediaIds.firstOrNull,
                      onFeedback: kDebugMode && onFeedback != null
                          ? (labels) => onFeedback!(candidate, labels)
                          : null,
                      onTap: () => onOpenCandidate(candidate),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroMemory extends StatelessWidget {
  const _HeroMemory({
    required this.repository,
    required this.candidate,
    required this.onTap,
  });

  final MediaRepository repository;
  final MemoryCandidate candidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final copy = const MemoryCandidateCopyMapper().map(candidate, l10n);
    final coverId =
        candidate.representativeMediaIds.firstOrNull ??
        candidate.mediaIds.firstOrNull;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 320,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MediaPreview(
                repository: repository,
                assetId: coverId,
                size: detailPreviewSize,
                usePreview: true,
                borderRadius: 0,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .75),
                    ],
                    stops: const [.45, 1],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.large,
                right: AppSpacing.large,
                bottom: AppSpacing.large,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.title,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.xSmall),
                    Text(
                      copy.subtitle,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    Text(
                      '${l10n.discoverContinue} →',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
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

class _PlacesRow extends StatelessWidget {
  const _PlacesRow({
    required this.repository,
    required this.places,
    required this.placeLabels,
    required this.onOpen,
  });

  final MediaRepository repository;
  final List<DiscoveryPlaceSummary> places;
  final PlaceLabelResolver placeLabels;
  final ValueChanged<DiscoveryPlaceSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sectionPlaces, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.small),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: places.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.small),
            itemBuilder: (context, index) {
              final place = places[index];
              return FutureBuilder<String>(
                future: placeLabels.labelFor(place),
                builder: (context, snapshot) {
                  final label = snapshot.data;
                  return _PlaceCard(
                    repository: repository,
                    place: place,
                    label: label,
                    placeCountLabel: l10n.placeAssetCount(place.assetCount),
                    onTap: () => onOpen(place),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.repository,
    required this.place,
    required this.label,
    required this.placeCountLabel,
    required this.onTap,
  });

  final MediaRepository repository;
  final DiscoveryPlaceSummary place;
  final String? label;
  final String placeCountLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
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
                height: 100,
                width: double.infinity,
                child: MediaPreview(
                  repository: repository,
                  assetId: place.coverAssetId,
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
                      label ?? placeCountLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (label != null)
                      Text(
                        placeCountLabel,
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

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.repository,
    required this.person,
    required this.onTap,
  });

  final MediaRepository repository;
  final DiscoveryPersonSummary person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: 120,
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
                  assetId: person.coverAssetId,
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
                      l10n.personNeutralLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      l10n.personPhotoCount(person.assetCount),
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

class _EmptyDiscover extends StatelessWidget {
  const _EmptyDiscover({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.emptyFeedTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(l10n.emptyFeedSubtitle),
            const SizedBox(height: AppSpacing.medium),
            FilledButton(onPressed: onRetry, child: Text(l10n.onboardingRetry)),
          ],
        ),
      ),
    );
  }
}
