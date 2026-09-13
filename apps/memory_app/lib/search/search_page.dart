import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/discovery/discovery_controller.dart';
import 'package:memory_app/discovery/discovery_sections.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_app/presentation/memory_candidate_copy_mapper.dart';
import 'package:memory_app/search/discovery_filter_sheet.dart';
import 'package:memory_app/widgets/media_preview.dart';
import 'package:memory_domain/memory_domain.dart';

/// Unified Discovery Search: text query + quick filters + advanced filter
/// sheet. Results are memories, not raw photos (Discovery First contract).
class DiscoverySearchPage extends StatefulWidget {
  const DiscoverySearchPage({
    super.key,
    required this.controller,
    required this.repository,
  });

  final DiscoveryController controller;
  final MediaRepository repository;

  @override
  State<DiscoverySearchPage> createState() => _DiscoverySearchPageState();
}

class _DiscoverySearchPageState extends State<DiscoverySearchPage> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final results = widget.controller.searchResults(_textController.text);
        final dimensions = widget.controller.dimensions();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.large,
                AppSpacing.medium,
                AppSpacing.large,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l10n.searchHint,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.searchFilters,
                    onPressed: () => _openFilterSheet(context),
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
            ),
            // Quick filters: first layer stays small (three groups max).
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.large,
                ),
                children: [
                  if (dimensions != null)
                    for (final year in dimensions.years.keys.take(3))
                      Padding(
                        padding: const EdgeInsets.only(
                          right: AppSpacing.xSmall,
                        ),
                        child: FilterChip(
                          label: Text('$year'),
                          selected: widget.controller.query.years.contains(
                            year,
                          ),
                          onSelected: (_) => widget.controller.toggleYear(year),
                        ),
                      ),
                  FilterChip(
                    label: Text(l10n.sectionTrips),
                    selected: widget.controller.query.memoryTypes.contains(
                      MemoryCandidateType.travelStory,
                    ),
                    onSelected: (_) => widget.controller.toggleMemoryType(
                      MemoryCandidateType.travelStory,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xSmall),
                  FilterChip(
                    label: Text(l10n.filterVideos),
                    selected: widget.controller.query.mediaTypes.contains(
                      MediaType.video,
                    ),
                    onSelected: (_) =>
                        widget.controller.toggleMediaType(MediaType.video),
                  ),
                  const SizedBox(width: AppSpacing.xSmall),
                  FilterChip(
                    label: Text(l10n.filterFavorites),
                    selected: widget.controller.query.favoritesOnly,
                    onSelected: (_) => widget.controller.toggleFavorites(),
                  ),
                ],
              ),
            ),
            ActiveFilterChips(
              query: widget.controller.query,
              onRemove: (key, value) =>
                  widget.controller.query.without(key, value),
              onClearAll: widget.controller.clearFilters,
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        l10n.searchNoResults,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.large),
                      itemCount: results.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.small),
                      itemBuilder: (context, index) {
                        final candidate = results[index];
                        final copy = const MemoryCandidateCopyMapper().map(
                          candidate,
                          l10n,
                        );
                        final coverId =
                            candidate.representativeMediaIds.firstOrNull ??
                            candidate.mediaIds.firstOrNull;
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: SizedBox(
                              width: 56,
                              height: 56,
                              child: MediaPreview(
                                repository: widget.repository,
                                assetId: coverId,
                                size: feedPreviewSize,
                                borderRadius: AppRadius.button,
                              ),
                            ),
                            title: Text(copy.title, maxLines: 1),
                            subtitle: Text(copy.subtitle, maxLines: 1),
                            onTap: () => _openCandidate(candidate),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _openCandidate(MemoryCandidate candidate) {
    widget.controller.openCandidate(candidate);
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    await showDiscoveryFilterSheet(
      context,
      controller: widget.controller,
      repository: widget.repository,
    );
    if (mounted) setState(() {});
  }
}
