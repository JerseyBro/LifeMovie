import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_app/presentation/memory_candidate_copy_mapper.dart';
import 'package:memory_domain/memory_domain.dart';
import 'package:memory_engine/memory_engine.dart';

class MemoryLabPage extends StatefulWidget {
  const MemoryLabPage({
    super.key,
    required this.stats,
    required this.rawCandidates,
    required this.rankedCandidates,
    required this.feedCandidates,
    required this.memoryContext,
    required this.ranker,
    required this.sensitivityGuard,
    required this.enabledRules,
    required this.config,
    required this.onRulesChanged,
    required this.onConfigChanged,
    required this.onRescan,
    required this.onSaveEvaluation,
    this.evaluationStore,
  });

  final MediaIndexStats? stats;
  final List<MemoryCandidate> rawCandidates;
  final List<MemoryCandidate> rankedCandidates;
  final List<MemoryCandidate> feedCandidates;
  final MemoryContext memoryContext;
  final MemoryRanker ranker;
  final MemorySensitivityGuard sensitivityGuard;
  final Set<String> enabledRules;
  final MemoryIntelligenceConfig config;
  final ValueChanged<Set<String>> onRulesChanged;
  final ValueChanged<MemoryIntelligenceConfig> onConfigChanged;
  final Future<void> Function() onRescan;
  final Future<void> Function(MemoryCandidate candidate, List<String> labels)
  onSaveEvaluation;

  /// Local-only store backing First WOW metrics. Null hides metrics section.
  final MemoryEvaluationStore? evaluationStore;

  @override
  State<MemoryLabPage> createState() => _MemoryLabPageState();
}

class _MemoryLabPageState extends State<MemoryLabPage> {
  MemoryCandidate? compareA;
  MemoryCandidate? compareB;
  Future<List<MemoryEvaluation>>? _evaluations;

  @override
  void initState() {
    super.initState();
    _refreshEvaluations();
  }

  @override
  void didUpdateWidget(MemoryLabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.evaluationStore != widget.evaluationStore) {
      _refreshEvaluations();
    }
  }

  void _refreshEvaluations() {
    final store = widget.evaluationStore;
    _evaluations = store?.loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    return Scaffold(
      appBar: AppBar(title: const Text('Memory Lab V0.2')),
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
          Text('Rule ON / OFF', style: Theme.of(context).textTheme.titleLarge),
          ..._allRuleNames.map(_ruleSwitch),
          const Divider(),
          Text(
            'Rule Parameters',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          _samePlaceYearSlider(),
          _travelAssetsSlider(),
          FilledButton(
            onPressed: widget.onRescan,
            child: const Text('Re-run discovery'),
          ),
          const Divider(),
          Text(
            'Raw ${widget.rawCandidates.length} · Ranked ${widget.rankedCandidates.length} · Feed ${widget.feedCandidates.length}',
          ),
          const SizedBox(height: AppSpacing.small),
          if (widget.evaluationStore != null) _wowMetrics(),
          Text(
            'Top 10 Candidate Browser',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ...widget.feedCandidates.take(10).map(_candidateCard),
          const Divider(),
          Text(
            'Candidate Compare',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          _comparePane(),
        ],
      ),
    );
  }

  Widget _ruleSwitch(String name) => SwitchListTile(
    title: Text(name),
    value: widget.enabledRules.contains(name),
    onChanged: (enabled) {
      final next = {...widget.enabledRules};
      enabled ? next.add(name) : next.remove(name);
      widget.onRulesChanged(next);
      setState(() {});
    },
  );

  Widget _samePlaceYearSlider() {
    final current = widget.config.samePlaceAcrossYears.minimumYearCount;
    return ListTile(
      title: Text('SamePlaceAcrossYears minimum years: $current'),
      subtitle: Slider(
        value: current.toDouble(),
        min: 2,
        max: 8,
        divisions: 6,
        onChanged: (value) {
          widget.onConfigChanged(
            MemoryIntelligenceConfig(
              samePlaceAcrossYears: SamePlaceAcrossYearsRuleConfig(
                minimumYearCount: value.round(),
                minimumVisitCount:
                    widget.config.samePlaceAcrossYears.minimumVisitCount,
                clusterConfig: widget.config.samePlaceAcrossYears.clusterConfig,
                sessionGap: widget.config.samePlaceAcrossYears.sessionGap,
              ),
              firstMemory: widget.config.firstMemory,
              travelStory: widget.config.travelStory,
              personTimeline: widget.config.personTimeline,
              annualTogether: widget.config.annualTogether,
              longTermEvolution: widget.config.longTermEvolution,
              rankingWeights: widget.config.rankingWeights,
            ),
          );
          setState(() {});
        },
      ),
    );
  }

  Widget _travelAssetsSlider() {
    final current = widget.config.travelStory.minimumAssets;
    return ListTile(
      title: Text('TravelStory minimum media count: $current'),
      subtitle: Slider(
        value: current.toDouble(),
        min: 6,
        max: 40,
        divisions: 17,
        onChanged: (value) {
          widget.onConfigChanged(
            MemoryIntelligenceConfig(
              samePlaceAcrossYears: widget.config.samePlaceAcrossYears,
              firstMemory: widget.config.firstMemory,
              travelStory: TravelStoryRuleConfig(
                minimumAssets: value.round(),
                minimumDays: widget.config.travelStory.minimumDays,
                minimumPlaceCount: widget.config.travelStory.minimumPlaceCount,
                maxGap: widget.config.travelStory.maxGap,
                clusterConfig: widget.config.travelStory.clusterConfig,
              ),
              personTimeline: widget.config.personTimeline,
              annualTogether: widget.config.annualTogether,
              longTermEvolution: widget.config.longTermEvolution,
              rankingWeights: widget.config.rankingWeights,
            ),
          );
          setState(() {});
        },
      ),
    );
  }

  Widget _candidateCard(MemoryCandidate candidate) {
    final l10n = AppLocalizations.of(context)!;
    final copy = const MemoryCandidateCopyMapper().map(candidate, l10n);
    final breakdown = widget.ranker.explain(candidate, widget.memoryContext);
    final sensitivity = widget.sensitivityGuard.assess(candidate);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              candidate.type.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(copy.title),
            Text(
              '${candidate.mediaIds.length} media · score ${breakdown.finalScore.toStringAsFixed(1)}',
            ),
            if (sensitivity.flags.isNotEmpty)
              Text('Sensitivity flags: ${sensitivity.flags.join(', ')}'),
            Wrap(
              spacing: AppSpacing.small,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => compareA = candidate),
                  child: const Text('Set A'),
                ),
                OutlinedButton(
                  onPressed: () => setState(() => compareB = candidate),
                  child: const Text('Set B'),
                ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.small,
              children: [
                _feedback(candidate, '有意义'),
                _feedback(candidate, '有惊喜'),
                _feedback(candidate, '一般'),
                _feedback(candidate, '不准确'),
                _feedback(candidate, '不希望看到'),
              ],
            ),
            ExpansionTile(
              title: const Text('Score Breakdown / Reasons'),
              children: [
                ...breakdown.factors.entries.map(
                  (entry) => ListTile(
                    dense: true,
                    title: Text(entry.key),
                    trailing: Text(entry.value.toStringAsFixed(1)),
                  ),
                ),
                ...candidate.reasons.map(
                  (reason) => ListTile(dense: true, title: Text(reason)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedback(MemoryCandidate candidate, String label) => TextButton(
    onPressed: () async {
      await widget.onSaveEvaluation(candidate, [label]);
      _refreshEvaluations();
      if (mounted) setState(() {});
    },
    child: Text(label),
  );

  /// Internal First WOW hypothesis readout. Local labels only, no ranking use.
  Widget _wowMetrics() {
    final pending = _evaluations;
    if (pending == null) return const SizedBox.shrink();
    return FutureBuilder<List<MemoryEvaluation>>(
      future: pending,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <MemoryEvaluation>[];
        var meaningful = 0;
        var surprising = 0;
        var wrong = 0;
        var unwanted = 0;
        var meh = 0;
        for (final item in items) {
          final labels = item.labels;
          if (labels.any((e) => e == '值得回看' || e == '有意义')) {
            meaningful += 1;
          }
          if (labels.any((e) => e == '没想到' || e == '有惊喜')) {
            surprising += 1;
          }
          if (labels.any((e) => e == '不准确')) wrong += 1;
          if (labels.any((e) => e == '不想看到' || e == '不希望看到' || e == '太私人')) {
            unwanted += 1;
          }
          if (labels.any((e) => e == '一般')) meh += 1;
        }
        final total = items.length;
        String rate(int count) =>
            total == 0 ? '—' : '${(count * 100 / total).round()}%';
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.medium),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'First WOW · internal ($total evaluated)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Meaningful $meaningful (${rate(meaningful)}) · '
                  'Surprising $surprising (${rate(surprising)})',
                ),
                Text(
                  'Wrong $wrong (${rate(wrong)}) · '
                  'Unwanted $unwanted (${rate(unwanted)}) · '
                  'Meh $meh (${rate(meh)})',
                ),
                const Text(
                  'Hypothesis: meaningful Top5 >= 3, WOW >= 40%, '
                  'wrong/unwanted < 20%.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _comparePane() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: _compareItem('A', compareA)),
      const SizedBox(width: AppSpacing.medium),
      Expanded(child: _compareItem('B', compareB)),
    ],
  );

  Widget _compareItem(String label, MemoryCandidate? candidate) {
    if (candidate == null) return Text('$label: not selected');
    final breakdown = widget.ranker.explain(candidate, widget.memoryContext);
    final sensitivity = widget.sensitivityGuard.assess(candidate);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label · ${candidate.type.name}'),
            Text('Score ${breakdown.finalScore.toStringAsFixed(1)}'),
            Text(
              'Risk ${sensitivity.flags.isEmpty ? 'none' : sensitivity.flags.join(',')}',
            ),
            ...candidate.reasons.take(3).map(Text.new),
          ],
        ),
      ),
    );
  }
}

const _allRuleNames = [
  'DateClusterRule',
  'SamePlaceRule',
  'YearRecapRule',
  'SamePlaceAcrossYearsRule',
  'FirstMemoryRule',
  'TravelStoryRule',
  'PersonTimelineRule',
  'AnnualTogetherRule',
  'LongTermEvolutionRule',
];
