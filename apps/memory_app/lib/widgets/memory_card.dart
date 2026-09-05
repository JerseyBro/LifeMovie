import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_app/presentation/memory_candidate_copy_mapper.dart';
import 'package:memory_app/widgets/media_preview.dart';
import 'package:memory_domain/memory_domain.dart';

/// Editorial discovery feed card: light type eyebrow + story hero.
///
/// Formal feed copy stays product-safe via [MemoryCandidateCopyMapper].
/// Rule names and scores never surface here; they belong to Memory Lab.
class MemoryCard extends StatelessWidget {
  const MemoryCard({
    super.key,
    required this.candidate,
    required this.repository,
    required this.thumbnailAssetId,
    required this.onTap,
    this.onFeedback,
  });

  final MemoryCandidate candidate;
  final MediaRepository repository;
  final String? thumbnailAssetId;
  final VoidCallback onTap;
  final Future<void> Function(List<String> labels)? onFeedback;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final copy = const MemoryCandidateCopyMapper().map(candidate, l10n);
    final eyebrow = _eyebrow(candidate.type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(eyebrow.icon, size: 14, color: AppColor.muted),
            const SizedBox(width: AppSpacing.xSmall),
            Text(
              eyebrow.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColor.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.small),
        LifeStoryCard(
          hero: MediaPreviewTile(
            key: ValueKey(thumbnailAssetId),
            repository: repository,
            assetId: thumbnailAssetId,
            size: feedPreviewSize,
          ),
          title: copy.title,
          metadata: copy.subtitle,
          cta: _isYearBased(candidate) ? l10n.cardCtaYears : l10n.cardCtaMemory,
          onTap: onTap,
        ),
        if (onFeedback != null) ...[
          const SizedBox(height: AppSpacing.small),
          FirstWowFeedbackBar(onFeedback: onFeedback!),
        ],
      ],
    );
  }

  bool _isYearBased(MemoryCandidate c) =>
      c.type == MemoryCandidateType.samePlaceAcrossYears ||
      c.type == MemoryCandidateType.personTimeline ||
      c.type == MemoryCandidateType.longTermEvolution ||
      c.type == MemoryCandidateType.annualTogether;
}

/// Internal First WOW prototype: local-only anonymous labels.
/// Not a ranking input; stored via MemoryEvaluationStore.
class FirstWowFeedbackBar extends StatelessWidget {
  const FirstWowFeedbackBar({super.key, required this.onFeedback});

  final Future<void> Function(List<String> labels) onFeedback;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.xSmall,
    runSpacing: AppSpacing.xSmall,
    children: [
      _button('👍 值得回看', '值得回看'),
      _button('✨ 没想到', '没想到'),
      _button('😐 一般', '一般'),
      _button('❌ 不准确', '不准确'),
      _button('🙈 不想看到', '不想看到'),
    ],
  );

  Widget _button(String text, String label) =>
      OutlinedButton(onPressed: () => onFeedback([label]), child: Text(text));
}

class _Eyebrow {
  const _Eyebrow(this.label, this.icon);

  final String label;
  final IconData icon;
}

_Eyebrow _eyebrow(MemoryCandidateType type) {
  switch (type) {
    case MemoryCandidateType.personTimeline:
      return const _Eyebrow('人物', Icons.person_outline);
    case MemoryCandidateType.samePlace:
    case MemoryCandidateType.samePlaceAcrossYears:
      return const _Eyebrow('地点', Icons.place_outlined);
    case MemoryCandidateType.travelStory:
      return const _Eyebrow('旅途', Icons.map_outlined);
    case MemoryCandidateType.yearRecap:
      return const _Eyebrow('年度回顾', Icons.calendar_month_outlined);
    case MemoryCandidateType.firstMemory:
      return const _Eyebrow('初见', Icons.fiber_new_outlined);
    case MemoryCandidateType.annualTogether:
      return const _Eyebrow('每年相聚', Icons.groups_outlined);
    case MemoryCandidateType.longTermEvolution:
      return const _Eyebrow('成长变化', Icons.trending_up_outlined);
    case MemoryCandidateType.dateCluster:
      return const _Eyebrow('聚会时光', Icons.event_outlined);
  }
}
