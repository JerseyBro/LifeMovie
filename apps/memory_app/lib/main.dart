import 'dart:io';

import 'package:analytics/analytics.dart';
import 'package:ai_gateway/ai_gateway.dart';
import 'package:design_system/design_system.dart';
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
  final Analytics analytics = const DebugAnalytics();
  final AiService ai = const MockAiProvider();
  late final MemoryEngine engine = MemoryEngine(
    rules: const [DateClusterRule(), SamePlaceRule(), YearRecapRule()],
  );
  final MemoryRanker ranker = const WeightedMemoryRanker();
  MediaPermissionStatus permission = MediaPermissionStatus.notDetermined;
  List<MemoryCandidate> candidates = const [];
  bool onboardingComplete = false;
  bool scanning = false;
  String? selectedId;

  Future<void> _start() async {
    analytics.track('onboarding_started');
    final result = await repository.requestPermission();
    analytics.track('photo_permission_requested');
    setState(() => permission = result);
    if (result == MediaPermissionStatus.authorized ||
        result == MediaPermissionStatus.limited) {
      setState(() => onboardingComplete = true);
      await _scan();
    }
  }

  Future<void> _scan() async {
    setState(() => scanning = true);
    analytics.track('media_index_started');
    final index = MediaIndex();
    await index.rebuild(repository);
    final memoryContext = MemoryContext(assets: index.assets);
    final ranked = ranker.rank(
      await engine.discover(memoryContext),
      memoryContext,
    );
    analytics.track('media_index_completed');
    analytics.track('memory_discovered', {'count': ranked.length});
    if (mounted) {
      setState(() {
        candidates = ranked;
        scanning = false;
      });
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
      return _Detail(
        candidate: candidate,
        onBack: () => setState(() => selectedId = null),
        ai: ai,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Memory discovery')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        children: [
          const Text(
            'Stories waiting to be noticed',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.small),
          const Text('Your originals stay on this device.'),
          const SizedBox(height: AppSpacing.large),
          ...candidates
              .take(3)
              .map(
                (c) => _MemoryCard(
                  candidate: c,
                  onTap: () {
                    analytics.track('memory_opened', {'id': c.id});
                    setState(() => selectedId = c.id);
                  },
                ),
              ),
        ],
      ),
    );
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
            const Text(
              'Rediscover the stories already in your photos.',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.medium),
            const Text(
              'We use photo metadata on your device to find meaningful moments. Original photos stay on your device.',
            ),
            const Spacer(),
            if (permission == MediaPermissionStatus.denied)
              const Text(
                'Photo access was denied. You can enable it in Settings.',
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
  const _MemoryCard({required this.candidate, required this.onTap});
  final MemoryCandidate candidate;
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
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColor.accent.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: const Center(
                child: Icon(Icons.photo_library_outlined, size: 42),
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            Text(
              _title(candidate),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${candidate.period.start.year} · ${candidate.mediaIds.length} photos',
            ),
            const SizedBox(height: 8),
            Text(candidate.reasons.first),
          ],
        ),
      ),
    ),
  );
  String _title(MemoryCandidate c) => switch (c.type) {
    MemoryCandidateType.dateCluster => 'A summer worth remembering',
    MemoryCandidateType.samePlace => 'Moments from a familiar place',
    MemoryCandidateType.yearRecap => '${c.period.start.year} in review',
  };
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.candidate,
    required this.onBack,
    required this.ai,
  });
  final MemoryCandidate candidate;
  final VoidCallback onBack;
  final AiService ai;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: onBack),
      title: const Text('Memory detail'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        Text('Why this memory?', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...candidate.reasons.map(
          (reason) => ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(reason),
          ),
        ),
        const Divider(),
        Text(
          '${candidate.period.start.toLocal()} – ${candidate.period.end.toLocal()}',
        ),
        const SizedBox(height: 8),
        Text('${candidate.mediaIds.length} media assets'),
        const SizedBox(height: AppSpacing.large),
        FutureBuilder<String>(
          future: ai.generateMemorySummary(memoryId: candidate.id),
          builder: (context, snapshot) => Text(
            snapshot.data ?? 'Preparing a gentle summary…',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    ),
  );
}
