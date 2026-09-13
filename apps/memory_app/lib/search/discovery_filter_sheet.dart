import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/discovery/discovery_controller.dart';
import 'package:memory_app/discovery/place_label_resolver.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_domain/memory_domain.dart';

/// Advanced filter sheet (Immich-style grouped composition, constrained to
/// dimensions with real data): Time / Place / Memory / Media.
/// Within a group selections OR; across groups they AND.
Future<void> showDiscoveryFilterSheet(
  BuildContext context, {
  required DiscoveryController controller,
  required MediaRepository repository,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _FilterSheet(
      controller: controller,
      placeLabels: PlaceLabelResolver(repository),
    ),
  );
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.controller, required this.placeLabels});

  final DiscoveryController controller;
  final PlaceLabelResolver placeLabels;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dimensions = controller.dimensions();
    return SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final query = controller.query;
          return SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.75,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  child: Row(
                    children: [
                      Text(
                        l10n.filterSheetTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: controller.clearFilters,
                        child: Text(l10n.filterClearAll),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.large,
                    ),
                    children: [
                      _group(context, l10n.filterGroupTime, [
                        if (dimensions != null)
                          for (final year in dimensions.years.keys.take(12))
                            _toggle(
                              '$year · ${dimensions.years[year]}',
                              query.years.contains(year),
                              () => controller.toggleYear(year),
                            ),
                      ]),
                      if (dimensions != null && dimensions.places.isNotEmpty)
                        _group(context, l10n.filterGroupPlace, [
                          for (final place in dimensions.places.take(12))
                            FutureBuilder<String>(
                              future: placeLabels.labelFor(place),
                              builder: (context, snapshot) => _toggle(
                                '${snapshot.data ?? l10n.filterPlacePrefix} · ${place.assetCount}',
                                query.placeIds.contains(place.placeId),
                                () => controller.togglePlace(place.placeId),
                              ),
                            ),
                        ]),
                      _group(context, l10n.filterGroupMemory, [
                        for (final entry in _memoryTypeOptions(l10n).entries)
                          _toggle(
                            entry.value,
                            query.memoryTypes.contains(entry.key),
                            () => controller.toggleMemoryType(entry.key),
                          ),
                      ]),
                      _group(context, l10n.filterGroupMedia, [
                        _toggle(
                          l10n.filterPhotos,
                          query.mediaTypes.contains(MediaType.image),
                          () => controller.toggleMediaType(MediaType.image),
                        ),
                        _toggle(
                          l10n.filterVideos,
                          query.mediaTypes.contains(MediaType.video),
                          () => controller.toggleMediaType(MediaType.video),
                        ),
                        _toggle(
                          l10n.filterFavorites,
                          query.favoritesOnly,
                          () => controller.toggleFavorites(),
                        ),
                      ]),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.large),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.filterApply),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<MemoryCandidateType, String> _memoryTypeOptions(AppLocalizations l10n) =>
      {
        MemoryCandidateType.travelStory: l10n.sectionTrips,
        MemoryCandidateType.samePlaceAcrossYears: l10n.memoryTypeRevisit,
        MemoryCandidateType.personTimeline: l10n.sectionPeople,
        MemoryCandidateType.firstMemory: l10n.sectionFirstMemories,
        MemoryCandidateType.annualTogether: l10n.sectionTogether,
        MemoryCandidateType.longTermEvolution: l10n.sectionEvolution,
        MemoryCandidateType.yearRecap: l10n.sectionYears,
        MemoryCandidateType.samePlace: l10n.sectionPlaces,
        MemoryCandidateType.dateCluster: l10n.memoryTypeGathering,
      };

  Widget _group(BuildContext context, String title, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xSmall),
            Wrap(
              spacing: AppSpacing.xSmall,
              runSpacing: AppSpacing.xSmall,
              children: children,
            ),
          ],
        ),
      );

  Widget _toggle(String label, bool selected, VoidCallback onToggle) =>
      FilterChip(
        label: Text(label),
        selected: selected,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => onToggle(),
      );
}
