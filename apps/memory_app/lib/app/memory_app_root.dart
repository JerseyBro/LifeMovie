import 'dart:io';

import 'package:analytics/analytics.dart';
import 'package:ai_gateway/ai_gateway.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/discovery/discovery_controller.dart';
import 'package:memory_app/discovery/discovery_home.dart';
import 'package:memory_app/discovery/place_label_resolver.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_app/media_editor/edit_recipe_store.dart';
import 'package:memory_app/media_viewer/media_viewer_page.dart';
import 'package:memory_app/media_viewer/photo_open_transition.dart';
import 'package:memory_app/memory_detail/memory_detail_page.dart';
import 'package:memory_app/screens/memory_lab_page.dart';
import 'package:memory_app/search/search_page.dart';
import 'package:memory_app/timeline/timeline_page.dart';
import 'package:memory_app/widgets/media_preview.dart';
import 'package:memory_domain/memory_domain.dart';
import 'package:memory_engine/memory_engine.dart';
import 'package:path_provider/path_provider.dart';

/// Composition root + navigation shell.
///
/// Tabs: 发现 (Discover, always first) / 时光 (Timeline) / 搜索 (Search).
class MemoryAppRoot extends StatefulWidget {
  const MemoryAppRoot({
    super.key,
    this.repository,
    this.persistentIndex,
    this.analytics,
    this.ai,
  });

  final MediaRepository? repository;
  final PersistentMediaIndex? persistentIndex;
  final Analytics? analytics;
  final AiService? ai;

  @override
  State<MemoryAppRoot> createState() => _MemoryAppRootState();
}

class _MemoryAppRootState extends State<MemoryAppRoot> {
  late final MediaRepository repository =
      widget.repository ??
      (Platform.isIOS ? PhotoKitMediaRepository() : MockMediaRepository());
  late final PersistentMediaIndex? persistentIndex =
      widget.persistentIndex ??
      (Platform.isIOS ? PersistentMediaIndex.appDatabase() : null);
  late final Analytics analytics = widget.analytics ?? const DebugAnalytics();
  late final AiService ai = widget.ai ?? const MockAiProvider();

  final DiscoveryController discoveryController = DiscoveryController();
  late final PlaceLabelResolver placeLabels = PlaceLabelResolver(repository);

  final ScanCancellationToken cancellationToken = ScanCancellationToken();
  final MemoryCandidateDeduplicator deduplicator =
      const MemoryCandidateDeduplicator();
  final FeedDiversityController diversity = const FeedDiversityController();
  final MemorySensitivityGuard sensitivityGuard =
      const MemorySensitivityGuard();

  MemoryEvaluationStore evaluationStore = InMemoryMemoryEvaluationStore();
  EditRecipeStore editStore = EditRecipeStore.inMemory();
  MemoryIntelligenceConfig intelligenceConfig =
      const MemoryIntelligenceConfig();
  Set<String> enabledRules = {
    'DateClusterRule',
    'SamePlaceRule',
    'YearRecapRule',
    'SamePlaceAcrossYearsRule',
    'FirstMemoryRule',
    'TravelStoryRule',
    'PersonTimelineRule',
    'AnnualTogetherRule',
    'LongTermEvolutionRule',
  };

  MediaPermissionStatus permission = MediaPermissionStatus.notDetermined;
  List<MediaAsset> indexedAssets = const [];
  List<MemoryCandidate> rawCandidates = const [];
  List<MemoryCandidate> rankedCandidates = const [];
  List<MemoryCandidate> feedCandidates = const [];
  MediaIndexStats? stats;
  IndexProgress? progress;
  bool onboardingComplete = false;
  bool scanning = false;
  String? failureMessage;
  int _tab = 0;

  MemoryRanker get ranker => WeightedMemoryRanker(
    weights: intelligenceConfig.rankingWeights,
    sensitivityGuard: sensitivityGuard,
  );

  @override
  void initState() {
    super.initState();
    discoveryController.onOpenCandidate = _openCandidate;
    _prepareStores();
  }

  @override
  void dispose() {
    discoveryController.dispose();
    cancellationToken.cancel();
    persistentIndex?.close();
    super.dispose();
  }

  Future<void> _prepareStores() async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationSupportDirectory();
      evaluationStore = JsonFileMemoryEvaluationStore(
        File('${dir.path}/memory_evaluations.json'),
      );
      editStore = EditRecipeStore(
        File('${dir.path}/lifemovie_edit_recipes.json'),
      );
    } on Object {
      evaluationStore = InMemoryMemoryEvaluationStore();
      editStore = EditRecipeStore.inMemory();
    }
  }

  Future<void> _start() async {
    analytics.track('onboarding_started');
    analytics.track('photo_permission_requested');
    final result = await repository.requestPermission();
    _trackPermission(result);
    setState(() => permission = result);
    if (result == MediaPermissionStatus.authorized ||
        result == MediaPermissionStatus.limited) {
      setState(() => onboardingComplete = true);
      await _scan();
    }
  }

  Future<void> _scan() async {
    setState(() {
      scanning = true;
      failureMessage = null;
      progress = null;
    });
    analytics.track('media_index_started');
    try {
      final assets = await _indexAssets();
      final memoryContext = MemoryContext(assets: assets);
      final discovered = await _discover(memoryContext);
      final ranked = ranker.rank(discovered, memoryContext);
      final deduped = deduplicator.deduplicate(ranked);
      final feed = diversity.diversify(deduped, limit: 20);

      analytics.track('media_index_completed', {'count': assets.length});
      analytics.track('memory_candidate_ranked', {'count': ranked.length});
      for (var i = 0; i < feed.take(10).length; i += 1) {
        analytics.track('memory_candidate_impression', {
          'rule': feed[i].type.name,
          'rank': i + 1,
          'scoreBucket': (feed[i].score ~/ 10) * 10,
        });
      }
      if (mounted) {
        setState(() {
          indexedAssets = assets;
          rawCandidates = discovered;
          rankedCandidates = ranked;
          feedCandidates = feed;
          scanning = false;
        });
        discoveryController.update(
          rankedCandidates: ranked,
          feedCandidates: feed,
          assets: assets,
        );
      }
    } on MediaFailure catch (error) {
      analytics.track('media_index_failed', {'code': error.code});
      if (mounted) {
        setState(() {
          failureMessage = error.message;
          scanning = false;
        });
      }
    } on IndexFailure catch (error) {
      analytics.track('media_index_failed', {'code': error.code});
      if (mounted) {
        setState(() {
          failureMessage = error.message;
          scanning = false;
        });
      }
    }
  }

  Future<List<MemoryCandidate>> _discover(MemoryContext memoryContext) async {
    final all = <MemoryCandidate>[];
    for (final rule in _activeRules()) {
      final stopwatch = Stopwatch()..start();
      final candidates = await rule.discover(memoryContext);
      stopwatch.stop();
      analytics.track('memory_rule_executed', {
        'rule': rule.runtimeType.toString(),
        'durationMs': stopwatch.elapsedMilliseconds,
      });
      for (final candidate in candidates) {
        analytics.track('memory_candidate_generated', {
          'rule': candidate.type.name,
        });
        final sensitivity = sensitivityGuard.assess(candidate);
        if (sensitivity.flags.isNotEmpty) {
          analytics.track('memory_candidate_sensitive', {
            'rule': candidate.type.name,
            'flagCount': sensitivity.flags.length,
          });
        }
      }
      all.addAll(candidates);
    }
    return all;
  }

  List<MemoryRule> _activeRules() {
    final rules = <String, MemoryRule>{
      'DateClusterRule': const DateClusterRule(),
      'SamePlaceRule': const SamePlaceRule(),
      'YearRecapRule': const YearRecapRule(),
      'SamePlaceAcrossYearsRule': SamePlaceAcrossYearsRule(
        config: intelligenceConfig.samePlaceAcrossYears,
      ),
      'FirstMemoryRule': FirstMemoryRule(
        config: intelligenceConfig.firstMemory,
      ),
      'TravelStoryRule': TravelStoryRule(
        config: intelligenceConfig.travelStory,
      ),
      'PersonTimelineRule': PersonTimelineRule(
        config: intelligenceConfig.personTimeline,
      ),
      'AnnualTogetherRule': AnnualTogetherRule(
        config: intelligenceConfig.annualTogether,
      ),
      'LongTermEvolutionRule': LongTermEvolutionRule(
        config: intelligenceConfig.longTermEvolution,
      ),
    };
    return rules.entries
        .where((entry) => enabledRules.contains(entry.key))
        .map((entry) => entry.value)
        .toList(growable: false);
  }

  Future<List<MediaAsset>> _indexAssets() async {
    final persistent = persistentIndex;
    if (persistent != null) {
      final result = await persistent.reconcile(
        repository,
        cancellationToken: cancellationToken,
        onProgress: (value) {
          if (mounted) setState(() => progress = value);
        },
      );
      if (result.cancelled) {
        analytics.track('media_index_cancelled');
      }
      if (result.failure != null) {
        throw result.failure!;
      }
      stats = await persistent.stats();
      // P0-6: never silently truncate library. Paginate for completeness.
      final count = stats?.total ?? 0;
      if (count > 50000) {
        debugPrint('Warning: library exceeds 50K ($count), paging full set.');
      }
      return persistent.allAssetsPaged();
    }

    final index = MediaIndex();
    await index.reconcile(
      repository,
      cancellationToken: cancellationToken,
      onProgress: (value) {
        if (mounted) setState(() => progress = value);
      },
    );
    stats = MediaIndexStats(
      total: index.assets.length,
      photos: index.assets
          .where(
            (a) => a.type == MediaType.image || a.type == MediaType.livePhoto,
          )
          .length,
      videos: index.assets.where((a) => a.type == MediaType.video).length,
      livePhotos: index.assets.where((a) => a.isLivePhoto).length,
      favorites: index.assets.where((a) => a.isFavorite).length,
      placeClusterCount: index.assets.where((a) => a.location != null).isEmpty
          ? 0
          : 1,
    );
    return index.assets;
  }

  Future<void> _manageLimitedLibrary() async {
    final result = await repository.presentLimitedLibraryPicker();
    setState(() => permission = result);
    await _scan();
  }

  Future<void> _saveEvaluation(
    MemoryCandidate candidate,
    List<String> labels,
  ) async {
    final evaluation = MemoryEvaluation.forCandidate(
      candidate,
      accuracy: labels.contains('不准确') ? 2 : 4,
      meaningfulness: labels.contains('有意义') || labels.contains('值得回看') ? 5 : 3,
      surprise: labels.contains('有惊喜') || labels.contains('没想到') ? 5 : 3,
      clarity: labels.contains('表达不舒服') || labels.contains('一般') ? 3 : 4,
      sensitivity:
          labels.contains('不希望看到') ||
              labels.contains('不想看到') ||
              labels.contains('太私人')
          ? 2
          : 5,
      labels: labels,
      createdAt: DateTime.now(),
    );
    await evaluationStore.save(evaluation);
    analytics.track('memory_candidate_feedback', {
      'rule': candidate.type.name,
      'feedbackType': labels.join('|'),
    });
  }

  void _openCandidate(MemoryCandidate candidate) {
    analytics.track('memory_candidate_opened', {
      'rule': candidate.type.name,
      'scoreBucket': (candidate.score ~/ 10) * 10,
    });
    analytics.track('memory_opened', {'rule': candidate.type.name});
    final assetsById = {for (final asset in indexedAssets) asset.id: asset};
    final mediaIds = candidate.representativeMediaIds.isEmpty
        ? candidate.mediaIds
        : candidate.representativeMediaIds;
    if (!mounted) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => MemoryDetailPage(
          candidate: candidate,
          allAssets: candidate.mediaIds
              .map((id) => assetsById[id])
              .whereType<MediaAsset>()
              .toList(growable: false),
          representativeAssets: mediaIds
              .map((id) => assetsById[id])
              .whereType<MediaAsset>()
              .toList(growable: false),
          onBack: () => Navigator.of(context).pop(),
          ai: ai,
          repository: repository,
          ranker: ranker,
          contextAssets: indexedAssets,
          editStore: editStore,
        ),
      ),
    );
  }

  void _trackPermission(MediaPermissionStatus status) {
    switch (status) {
      case MediaPermissionStatus.authorized:
        analytics.track('photo_permission_full');
      case MediaPermissionStatus.limited:
        analytics.track('photo_permission_limited');
      case MediaPermissionStatus.denied:
        analytics.track('photo_permission_denied');
      case MediaPermissionStatus.restricted:
        analytics.track('photo_permission_denied', {'restricted': true});
      case MediaPermissionStatus.notDetermined:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!onboardingComplete) {
      return _Onboarding(permission: permission, onStart: _start);
    }
    if (scanning) {
      return _IndexingPage(progress: progress);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          if (permission == MediaPermissionStatus.limited)
            IconButton(
              tooltip: l10n.manageLimitedPhotos,
              onPressed: _manageLimitedLibrary,
              icon: const Icon(Icons.photo_library_outlined),
            ),
          if (kDebugMode)
            IconButton(
              tooltip: l10n.debugOpenLab,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MemoryLabPage(
                    stats: stats,
                    rawCandidates: rawCandidates,
                    rankedCandidates: rankedCandidates,
                    feedCandidates: feedCandidates,
                    memoryContext: MemoryContext(assets: indexedAssets),
                    ranker: ranker,
                    sensitivityGuard: sensitivityGuard,
                    enabledRules: enabledRules,
                    config: intelligenceConfig,
                    onRulesChanged: (value) =>
                        setState(() => enabledRules = value),
                    onConfigChanged: (value) =>
                        setState(() => intelligenceConfig = value),
                    onRescan: _scan,
                    onSaveEvaluation: _saveEvaluation,
                    evaluationStore: evaluationStore,
                  ),
                ),
              ),
              icon: const Icon(Icons.science_outlined),
            ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          DiscoveryHome(
            controller: discoveryController,
            repository: repository,
            placeLabels: placeLabels,
            stats: stats,
            onOpenCandidate: _openCandidate,
            onRetryScan: _scan,
            onFeedback: _saveEvaluation,
          ),
          TimelinePage(
            assets: indexedAssets,
            repository: repository,
            onOpenAssets: _openTimelineAssets,
          ),
          DiscoverySearchPage(
            controller: discoveryController,
            repository: repository,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: l10n.navDiscover,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: l10n.navTimeline,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search),
            label: l10n.navSearch,
          ),
        ],
      ),
    );
  }

  void _openTimelineAssets(
    List<MediaAsset> assets,
    int index,
    Rect? sourceRect,
  ) {
    if (assets.isEmpty) return;
    final asset = assets[index];
    Navigator.of(context).push(
      PhotoViewerRoute(
        sourceRect: sourceRect,
        sourceThumb: ThumbnailBytesCache.instance.get(asset.id),
        targetAspectRatio: _aspectOf(asset),
        builder: (_) => MediaViewerPage(
          repository: repository,
          assets: assets,
          initialIndex: index,
          initialSourceRect: sourceRect,
          initialThumb: ThumbnailBytesCache.instance.get(asset.id),
          editStore: editStore,
        ),
      ),
    );
  }

  static double _aspectOf(MediaAsset asset) {
    final width = asset.width;
    final height = asset.height;
    if (width == null || height == null || width == 0 || height == 0) {
      return 3 / 4;
    }
    return width / height;
  }
}

class _Onboarding extends StatelessWidget {
  const _Onboarding({required this.permission, required this.onStart});

  final MediaPermissionStatus permission;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final denied =
        permission == MediaPermissionStatus.denied ||
        permission == MediaPermissionStatus.restricted;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Icon(
                Icons.photo_outlined,
                size: 42,
                color: AppColor.accent,
              ),
              const SizedBox(height: AppSpacing.large),
              Text(
                l10n.onboardingTitle,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.medium),
              Text(
                l10n.onboardingSubtitle,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.medium),
              Text(
                l10n.limitedPermissionHint,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              if (denied) ...[
                Text(l10n.permissionUnavailable),
                const SizedBox(height: AppSpacing.medium),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onStart,
                  child: Text(
                    permission == MediaPermissionStatus.notDetermined
                        ? l10n.onboardingCta
                        : l10n.onboardingRetry,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IndexingPage extends StatelessWidget {
  const _IndexingPage({required this.progress});

  final IndexProgress? progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final count = progress?.indexed ?? progress?.scanned ?? 0;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                l10n.indexingTitle,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.medium),
              Text(
                l10n.indexingCount(count),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.large),
              const LinearProgressIndicator(),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
