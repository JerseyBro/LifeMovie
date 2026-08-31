import 'package:memory_domain/memory_domain.dart';
import 'package:memory_app/l10n/app_localizations.dart';

class MemoryCandidateCopy {
  const MemoryCandidateCopy({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
}

/// Presentation-layer mapper. Engine provides facts/metadata; this maps to
/// user-facing Chinese/English copy via AppLocalizations.
/// Formal UI must use this, not MemoryCandidate.safeTitleTemplate.
class MemoryCandidateCopyMapper {
  const MemoryCandidateCopyMapper();

  MemoryCandidateCopy map(MemoryCandidate candidate, AppLocalizations l10n) {
    switch (candidate.type) {
      case MemoryCandidateType.samePlaceAcrossYears:
        return _samePlaceAcrossYears(candidate, l10n);
      case MemoryCandidateType.personTimeline:
        return _personTimeline(candidate, l10n);
      case MemoryCandidateType.travelStory:
        return _travelStory(candidate, l10n);
      case MemoryCandidateType.annualTogether:
        return _annualTogether(candidate, l10n);
      case MemoryCandidateType.longTermEvolution:
        return _longTermEvolution(candidate, l10n);
      case MemoryCandidateType.firstMemory:
        return _firstMemory(candidate, l10n);
      case MemoryCandidateType.dateCluster:
        return MemoryCandidateCopy(
          title: l10n.dateClusterTitle,
          subtitle: _mediaCountSubtitle(candidate, l10n),
        );
      case MemoryCandidateType.samePlace:
        return MemoryCandidateCopy(
          title: l10n.samePlaceTitle,
          subtitle: _mediaCountSubtitle(candidate, l10n),
        );
      case MemoryCandidateType.yearRecap:
        final year =
            candidate.metadata['year'] as int? ?? candidate.period.start.year;
        return MemoryCandidateCopy(
          title: l10n.yearRecapTitle(year),
          subtitle: _mediaCountSubtitle(candidate, l10n),
        );
    }
  }

  MemoryCandidateCopy _samePlaceAcrossYears(
    MemoryCandidate c,
    AppLocalizations l10n,
  ) {
    final distinct =
        c.metadata['distinctYearCount'] as int? ??
        c.metadata['yearCount'] as int? ??
        0;
    final longest = c.metadata['longestConsecutiveYearRun'] as int? ?? 0;
    final first = c.metadata['firstYear'] as int? ?? c.period.start.year;
    final last = c.metadata['lastYear'] as int? ?? c.period.end.year;
    final visits = c.metadata['visitCount'] as int? ?? 0;

    final String title;
    if (longest >= 3) {
      title = l10n.samePlaceConsecutiveYears(longest);
    } else if (distinct >= 3) {
      title = l10n.samePlaceMultipleYears(distinct);
    } else {
      title = l10n.samePlaceRepeated;
    }
    final subtitle = longest >= 3
        ? '$first — $last · $visits 次到访 · 连续 $longest 年'
        : '$first — $last · $visits 次到访 · $distinct 个年份';
    return MemoryCandidateCopy(title: title, subtitle: subtitle);
  }

  MemoryCandidateCopy _personTimeline(
    MemoryCandidate c,
    AppLocalizations l10n,
  ) {
    final firstYear = c.metadata['firstYear'] as int? ?? c.period.start.year;
    final span = c.metadata['calendarSpanYears'] as int? ?? 0;
    // Prefer "从 X 年开始" as primary; span is secondary info in subtitle
    final title = l10n.personAcrossYears(firstYear);
    final subtitle = span >= 2
        ? '${c.metadata['firstYear'] ?? firstYear} — ${c.metadata['lastYear'] ?? c.period.end.year} · 跨越 $span 年 · ${c.mediaIds.length} 张照片和视频'
        : '${c.mediaIds.length} 张照片和视频';
    return MemoryCandidateCopy(title: title, subtitle: subtitle);
  }

  MemoryCandidateCopy _travelStory(MemoryCandidate c, AppLocalizations l10n) {
    final days =
        c.metadata['durationDays'] as int? ??
        c.metadata['durationDays'] as int? ??
        (c.period.duration.inDays + 1);
    final places = c.metadata['placeCount'] as int? ?? c.placeIds.length;
    final count =
        c.metadata['totalMediaCount'] as int? ??
        c.metadata['mediaCount'] as int? ??
        c.mediaIds.length;
    return MemoryCandidateCopy(
      title: l10n.travelStoryTitle(days),
      subtitle: l10n.travelStorySubtitle(places, count),
    );
  }

  MemoryCandidateCopy _annualTogether(
    MemoryCandidate c,
    AppLocalizations l10n,
  ) {
    final longest = c.metadata['longestConsecutiveYearRun'] as int? ?? 0;
    final title = longest >= 3
        ? l10n.annualTogetherConsecutive
        : l10n.annualTogetherRepeated;
    final first = c.metadata['firstYear'] as int? ?? c.period.start.year;
    final last = c.metadata['lastYear'] as int? ?? c.period.end.year;
    final distinct =
        c.metadata['distinctYearCount'] as int? ??
        c.metadata['yearCount'] as int? ??
        0;
    final subtitle = longest >= 3
        ? '$first — $last · 连续 $longest 年'
        : '$first — $last · $distinct 年';
    return MemoryCandidateCopy(title: title, subtitle: subtitle);
  }

  MemoryCandidateCopy _longTermEvolution(
    MemoryCandidate c,
    AppLocalizations l10n,
  ) {
    final span = c.metadata['calendarSpanYears'] as int? ?? 0;
    final distinct =
        c.metadata['distinctYearCount'] as int? ??
        c.metadata['yearCount'] as int? ??
        0;
    final first = c.metadata['firstYear'] as int? ?? c.period.start.year;
    final last = c.metadata['lastYear'] as int? ?? c.period.end.year;
    final title = span >= 4
        ? l10n.longTermEvolutionSpan(span)
        : distinct >= 2
        ? l10n.longTermEvolutionMultipleYears(distinct)
        : l10n.longTermEvolutionTitle;
    final subtitle = '$first — $last';
    return MemoryCandidateCopy(title: title, subtitle: subtitle);
  }

  MemoryCandidateCopy _firstMemory(MemoryCandidate c, AppLocalizations l10n) {
    final kind = c.metadata['firstMemoryKind'] as String?;
    final title = kind == 'place'
        ? l10n.firstPlaceMemory
        : l10n.firstPersonMemory;
    final year = c.period.start.year;
    return MemoryCandidateCopy(title: title, subtitle: '$year · 相册记录');
  }

  String _mediaCountSubtitle(MemoryCandidate c, AppLocalizations l10n) =>
      '${c.mediaIds.length} 张照片和视频';
}
