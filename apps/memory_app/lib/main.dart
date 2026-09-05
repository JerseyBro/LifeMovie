import 'dart:io';

import 'package:analytics/analytics.dart';
import 'package:ai_gateway/ai_gateway.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_app/screens/memory_detail_page.dart';
import 'package:memory_app/screens/memory_lab_page.dart';
import 'package:memory_app/widgets/memory_card.dart';
import 'package:memory_domain/memory_domain.dart';
import 'package:memory_engine/memory_engine.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const MemoryApp());

class MemoryApp extends StatelessWidget {
  const MemoryApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LifeMovie',
    theme: buildNeutralTheme(),
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const MemoryHomePage(),
  );
}

class MemoryHomePage extends StatefulWidget {
  const MemoryHomePage({
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
  State<MemoryHomePage> createState() => _MemoryHomePageState();
}

class _MemoryHomePageState extends State<MemoryHomePage> {
  late final MediaRepository repository =
      widget.repository ??
      (Platform.isIOS ? PhotoKitMediaRepository() : MockMediaRepository());
  late final PersistentMediaIndex? persistentIndex =
      widget.persistentIndex ??
      (Platform.isIOS ? PersistentMediaIndex.appDatabase() : null);
  late final Analytics analytics = widget.analytics ?? const DebugAnalytics();
  late final AiService ai = widget.ai ?? const MockAiProvider();

  final ScanCancellationToken cancellationToken = ScanCancellationToken();
  final MemoryCandidateDeduplicator deduplicator =
      const MemoryCandidateDeduplicator();
  final FeedDiversityController diversity = const FeedDiversityController();
  final MemorySensitivityGuard sensitivityGuard =
      const MemorySensitivityGuard();

  MemoryEvaluationStore evaluationStore = InMemoryMemoryEvaluationStore();
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

  MemoryRanker get ranker => WeightedMemoryRanker(
    weights: intelligenceConfig.rankingWeights,
    sensitivityGuard: sensitivityGuard,
  );

  @override
  void initState() {
    super.initState();
    _prepareEvaluationStore();
  }

  @override
  void dispose() {
    cancellationToken.cancel();
    persistentIndex?.close();
    super.dispose();
  }

  Future<void> _prepareEvaluationStore() async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationSupportDirectory();
      evaluationStore = JsonFileMemoryEvaluationStore(
        File('${dir.path}/memory_evaluations.json'),
      );
    } on Object {
      evaluationStore = InMemoryMemoryEvaluationStore();
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
        // Explicit warning, not silent cap — still return full dataset paged.
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
      body: RefreshIndicator(
        onRefresh: _scan,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.large),
          children: [
            Text(
              l10n.feedDateToday,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              l10n.feedIntro,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: AppSpacing.medium),
            Text(
              _summaryText(l10n),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (failureMessage != null) ...[
              const SizedBox(height: AppSpacing.medium),
              Text(failureMessage!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: AppSpacing.large),
            if (feedCandidates.isEmpty)
              _EmptyFeed(onRefresh: _scan)
            else
              ...feedCandidates
                  .take(10)
                  .map(
                    (candidate) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.large),
                      child: MemoryCard(
                        candidate: candidate,
                        repository: repository,
                        thumbnailAssetId: _thumbnailId(candidate),
                        onFeedback: kDebugMode
                            ? (labels) => _saveEvaluation(candidate, labels)
                            : null,
                        onTap: () {
                          analytics.track('memory_candidate_opened', {
                            'rule': candidate.type.name,
                            'scoreBucket': (candidate.score ~/ 10) * 10,
                          });
                          analytics.track('memory_opened', {
                            'rule': candidate.type.name,
                          });
                          final assetsById = {
                            for (final asset in indexedAssets) asset.id: asset,
                          };
                          final mediaIds =
                              candidate.representativeMediaIds.isEmpty
                              ? candidate.mediaIds
                              : candidate.representativeMediaIds;
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
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  String? _thumbnailId(MemoryCandidate candidate) =>
      candidate.representativeMediaIds.firstOrNull ??
      candidate.mediaIds.firstOrNull;

  String _summaryText(AppLocalizations l10n) {
    final s = stats;
    if (s == null) return l10n.privacySummary;
    return l10n.feedSummary(s.total, s.photos, s.videos);
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

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.onRefresh});

  final VoidCallback onRefresh;

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
            FilledButton(
              onPressed: onRefresh,
              child: Text(l10n.onboardingRetry),
            ),
          ],
        ),
      ),
    );
  }
}
