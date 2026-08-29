import 'dart:io';

import 'package:analytics/analytics.dart';
import 'package:ai_gateway/ai_gateway.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_domain/memory_domain.dart';
import 'package:memory_engine/memory_engine.dart';

void main() => runApp(const MemoryApp());

class MemoryApp extends StatelessWidget {
  const MemoryApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Memory',
    theme: buildNeutralTheme(),
    home: const MemoryHomePage(),
  );
}

class MemoryHomePage extends StatefulWidget {
  const MemoryHomePage({super.key});

  @override
  State<MemoryHomePage> createState() => _MemoryHomePageState();
}

class _MemoryHomePageState extends State<MemoryHomePage> {
  late final MediaRepository repository = Platform.isIOS
      ? PhotoKitMediaRepository()
      : MockMediaRepository();
  late final PersistentMediaIndex? persistentIndex = Platform.isIOS
      ? PersistentMediaIndex.appDatabase()
      : null;
  final Analytics analytics = const DebugAnalytics();
  final AiService ai = const MockAiProvider();
  late final MemoryEngine engine = MemoryEngine(
    rules: const [
      DateClusterRule(),
      SamePlaceRule(),
      YearRecapRule(),
      PersonTimelineRule(),
    ],
  );
  final MemoryRanker ranker = const WeightedMemoryRanker();
  final ScanCancellationToken cancellationToken = ScanCancellationToken();

  MediaPermissionStatus permission = MediaPermissionStatus.notDetermined;
  List<MediaAsset> indexedAssets = const [];
  List<MemoryCandidate> candidates = const [];
  MediaIndexStats? stats;
  bool onboardingComplete = false;
  bool scanning = false;
  String? selectedId;
  String? failureMessage;

  @override
  void dispose() {
    cancellationToken.cancel();
    persistentIndex?.close();
    super.dispose();
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
    });
    analytics.track('media_index_started');
    try {
      final assets = await _indexAssets();
      final memoryContext = MemoryContext(assets: assets);
      final discovered = await engine.discover(memoryContext);
      final ranked = ranker.rank(discovered, memoryContext);
      analytics.track('media_index_completed', {'count': assets.length});
      analytics.track('memory_discovered', {'count': ranked.length});
      for (final candidate in ranked.take(3)) {
        analytics.track('memory_impression', {'id': candidate.id});
      }
      if (mounted) {
        setState(() {
          indexedAssets = assets;
          candidates = ranked;
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

  Future<List<MediaAsset>> _indexAssets() async {
    final persistent = persistentIndex;
    if (persistent != null) {
      final result = await persistent.reconcile(
        repository,
        cancellationToken: cancellationToken,
      );
      if (result.cancelled) {
        analytics.track('media_index_cancelled');
      }
      if (result.failure != null) {
        throw result.failure!;
      }
      stats = await persistent.stats();
      return persistent.allAssets(limit: 2000);
    }

    final index = MediaIndex();
    await index.reconcile(repository, cancellationToken: cancellationToken);
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
    if (!onboardingComplete) {
      return _Onboarding(permission: permission, onStart: _start);
    }
    if (scanning) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (selectedId != null) {
      final candidate = candidates.firstWhere((c) => c.id == selectedId);
      final assetsById = {for (final asset in indexedAssets) asset.id: asset};
      return _Detail(
        candidate: candidate,
        assets: candidate.mediaIds
            .map((id) => assetsById[id])
            .whereType<MediaAsset>()
            .toList(growable: false),
        onBack: () => setState(() => selectedId = null),
        ai: ai,
        repository: repository,
        ranker: ranker,
        contextAssets: indexedAssets,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory discovery'),
        actions: [
          if (permission == MediaPermissionStatus.limited)
            IconButton(
              tooltip: 'Manage limited photos',
              onPressed: _manageLimitedLibrary,
              icon: const Icon(Icons.photo_library_outlined),
            ),
          if (kDebugMode)
            IconButton(
              tooltip: 'Memory Lab',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _MemoryLab(
                    stats: stats,
                    candidates: candidates,
                    context: MemoryContext(assets: indexedAssets),
                    ranker: ranker,
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
          padding: const EdgeInsets.all(AppSpacing.medium),
          children: [
            Text(
              'Stories waiting to be noticed',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(_summaryText),
            if (failureMessage != null) ...[
              const SizedBox(height: AppSpacing.medium),
              Text(failureMessage!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: AppSpacing.large),
            ...candidates
                .take(10)
                .map(
                  (candidate) => _MemoryCard(
                    candidate: candidate,
                    repository: repository,
                    thumbnailAssetId: candidate.mediaIds.firstOrNull,
                    onTap: () {
                      analytics.track('memory_opened', {'id': candidate.id});
                      setState(() => selectedId = candidate.id);
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String get _summaryText {
    final s = stats;
    if (s == null) return 'Your originals stay on this device.';
    return '${s.total} indexed assets · ${s.photos} photos · ${s.videos} videos';
  }
}

class _Onboarding extends StatelessWidget {
  const _Onboarding({required this.permission, required this.onStart});

  final MediaPermissionStatus permission;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            const Icon(Icons.auto_awesome, size: 48),
            const SizedBox(height: AppSpacing.large),
            Text(
              'Rediscover the stories already in your photos.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.medium),
            const Text(
              'We use photo metadata on your device to find meaningful moments. Original photos stay on your device.',
            ),
            const Spacer(),
            if (permission == MediaPermissionStatus.denied ||
                permission == MediaPermissionStatus.restricted)
              const Text(
                'Photo access is unavailable. You can review it in Settings.',
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onStart,
                child: Text(
                  permission == MediaPermissionStatus.notDetermined
                      ? 'Choose photos'
                      : 'Try again',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.candidate,
    required this.repository,
    required this.thumbnailAssetId,
    required this.onTap,
  });

  final MemoryCandidate candidate;
  final MediaRepository repository;
  final String? thumbnailAssetId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.medium),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumbnail(
              repository: repository,
              assetId: thumbnailAssetId,
              size: 420,
            ),
            const SizedBox(height: AppSpacing.medium),
            Text(
              _title(candidate),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${candidate.period.start.year} · ${candidate.mediaIds.length} assets',
            ),
            const SizedBox(height: 8),
            Text(
              candidate.reasons.firstOrNull ??
                  'A memory candidate from your library',
            ),
          ],
        ),
      ),
    ),
  );

  String _title(MemoryCandidate c) => switch (c.type) {
    MemoryCandidateType.dateCluster => 'A dense stretch of days',
    MemoryCandidateType.samePlace => 'A visit worth remembering',
    MemoryCandidateType.yearRecap => '${c.period.start.year} in review',
    MemoryCandidateType.personTimeline => 'A person story seed',
  };
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.candidate,
    required this.assets,
    required this.onBack,
    required this.ai,
    required this.repository,
    required this.ranker,
    required this.contextAssets,
  });

  final MemoryCandidate candidate;
  final List<MediaAsset> assets;
  final VoidCallback onBack;
  final AiService ai;
  final MediaRepository repository;
  final MemoryRanker ranker;
  final List<MediaAsset> contextAssets;

  @override
  Widget build(BuildContext context) {
    final photos = assets
        .where(
          (a) => a.type == MediaType.image || a.type == MediaType.livePhoto,
        )
        .length;
    final videos = assets.where((a) => a.type == MediaType.video).length;
    final hasLocation = assets.any((a) => a.location != null);
    final breakdown = ranker.explain(
      candidate,
      MemoryContext(assets: contextAssets),
    );

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: const Text('Memory detail'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        children: [
          Text(_dateRange, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.small),
          Text('${assets.length} assets · $photos photos · $videos videos'),
          if (hasLocation) const Text('Location metadata available'),
          const SizedBox(height: AppSpacing.medium),
          _ThumbnailGrid(
            repository: repository,
            assets: assets.take(12).toList(),
          ),
          const SizedBox(height: AppSpacing.large),
          FutureBuilder<String>(
            future: ai.generateMemorySummary(memoryId: candidate.id),
            builder: (context, snapshot) => Text(
              snapshot.data ?? 'Preparing a summary...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          if (kDebugMode) ...[
            const Divider(height: AppSpacing.large),
            Text(
              'Debug reasons',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...candidate.reasons.map(
              (reason) => ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(reason),
              ),
            ),
            Text('Score ${breakdown.finalScore.toStringAsFixed(1)}'),
            ...breakdown.factors.entries.map(
              (entry) => ListTile(
                dense: true,
                title: Text(entry.key),
                trailing: Text('+${entry.value.toStringAsFixed(1)}'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _dateRange =>
      '${candidate.period.start.toLocal()} - ${candidate.period.end.toLocal()}';
}

class _ThumbnailGrid extends StatelessWidget {
  const _ThumbnailGrid({required this.repository, required this.assets});

  final MediaRepository repository;
  final List<MediaAsset> assets;

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
    itemBuilder: (context, index) => _Thumbnail(
      repository: repository,
      assetId: assets[index].id,
      size: 220,
    ),
  );
}

class _Thumbnail extends StatefulWidget {
  const _Thumbnail({
    required this.repository,
    required this.assetId,
    required this.size,
  });

  final MediaRepository repository;
  final String? assetId;
  final int size;

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  late final String requestId =
      '${widget.assetId ?? 'empty'}-${DateTime.now().microsecondsSinceEpoch}';
  late final Future<Uint8List?> thumbnail = widget.assetId == null
      ? Future.value()
      : widget.repository.loadThumbnail(
          widget.assetId!,
          size: widget.size,
          requestId: requestId,
        );

  @override
  void dispose() {
    widget.repository.cancelThumbnailRequest(requestId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.card),
    child: AspectRatio(
      aspectRatio: 1,
      child: FutureBuilder<Uint8List?>(
        future: thumbnail,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            return ColoredBox(
              color: AppColor.accent.withValues(alpha: .18),
              child: const Icon(Icons.photo_library_outlined),
            );
          }
          return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
        },
      ),
    ),
  );
}

class _MemoryLab extends StatelessWidget {
  const _MemoryLab({
    required this.stats,
    required this.candidates,
    required this.context,
    required this.ranker,
  });

  final MediaIndexStats? stats;
  final List<MemoryCandidate> candidates;
  final MemoryContext context;
  final MemoryRanker ranker;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Scaffold(
      appBar: AppBar(title: const Text('Memory Lab')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        children: [
          Text('Index', style: Theme.of(context).textTheme.titleLarge),
          Text(
            s == null
                ? 'No index stats yet'
                : '${s.total} indexed · ${s.photos} photos · ${s.videos} videos · ${s.placeClusterCount} place clusters',
          ),
          const SizedBox(height: AppSpacing.medium),
          const Text(
            'Rules: DateClusterRule, SamePlaceRule, YearRecapRule, PersonTimelineRule',
          ),
          Text('Candidates: ${candidates.length}'),
          const Divider(),
          ...candidates.take(20).map((candidate) {
            final breakdown = ranker.explain(candidate, this.context);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.type.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${candidate.mediaIds.length} assets · score ${breakdown.finalScore.toStringAsFixed(1)}',
                    ),
                    ...breakdown.factors.entries.map(
                      (entry) => Text(
                        '${entry.key}: +${entry.value.toStringAsFixed(1)}',
                      ),
                    ),
                    ...candidate.reasons.map((reason) => Text(reason)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
