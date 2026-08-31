// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LifeMovie';

  @override
  String get onboardingTitle => 'Rediscover the stories already in your photos';

  @override
  String get onboardingSubtitle =>
      'Your photos stay on this device. We organize time, places, and memory signals locally first.';

  @override
  String get onboardingCta => 'Start';

  @override
  String get onboardingRetry => 'Try again';

  @override
  String get permissionUnavailable =>
      'Photo access is unavailable. You can review it in Settings.';

  @override
  String get limitedPermissionHint =>
      'You can start with selected photos and add more later.';

  @override
  String get manageLimitedPhotos => 'Manage selected photos';

  @override
  String get indexingTitle => 'Organizing your photos';

  @override
  String indexingCount(int count) {
    return 'Indexed $count photos and videos';
  }

  @override
  String get feedDateToday => 'Today';

  @override
  String get feedIntro => 'Today, I found a few stories.';

  @override
  String feedSummary(int total, int photos, int videos) {
    return '$total indexed · $photos photos · $videos videos';
  }

  @override
  String get privacySummary => 'Original photos stay on this device.';

  @override
  String get emptyFeedTitle => 'No stable memories yet';

  @override
  String get emptyFeedSubtitle => 'Refresh or add more accessible photos.';

  @override
  String get cardCtaYears => 'See these years';

  @override
  String get cardCtaMemory => 'See this memory';

  @override
  String get detailTitle => 'This memory';

  @override
  String get detailTimeline => 'Timeline';

  @override
  String detailPhotos(int count) {
    return '$count photos';
  }

  @override
  String detailVideos(int count) {
    return '$count videos';
  }

  @override
  String get detailLocationHint => 'Location signals available';

  @override
  String get personTimelineTitle => 'Across the years';

  @override
  String get memoryLab => 'Memory Lab';

  @override
  String get debugOpenLab => 'Open Memory Lab';

  @override
  String samePlaceConsecutiveYears(int count) {
    return 'You have returned here for $count consecutive years.';
  }

  @override
  String samePlaceMultipleYears(int count) {
    return 'This place appears in $count different years in your library.';
  }

  @override
  String get samePlaceRepeated =>
      'Over the years, you have returned here many times.';

  @override
  String personAcrossYears(int firstYear) {
    return 'This person first appeared in $firstYear.';
  }

  @override
  String personSpanYears(int span) {
    return 'This person spans $span years in your library.';
  }

  @override
  String get firstPersonMemory =>
      'Your earliest photos with this person in the library.';

  @override
  String get firstPlaceMemory =>
      'Your earliest photos at this place in the library.';

  @override
  String travelStoryTitle(int days) {
    return 'These $days days look like a complete journey.';
  }

  @override
  String travelStorySubtitle(int places, int count) {
    return '$places places · $count photos and videos';
  }

  @override
  String get annualTogetherConsecutive =>
      'Around this time each year, this person appears.';

  @override
  String get annualTogetherRepeated =>
      'Around this time over the years, this person appears many times.';

  @override
  String longTermEvolutionSpan(int span) {
    return 'These photos span $span years.';
  }

  @override
  String longTermEvolutionMultipleYears(int count) {
    return 'This place appears in $count years.';
  }

  @override
  String get detailAiPlaceholder => 'Organizing this memory…';

  @override
  String get dateClusterTitle => 'These days left many photos.';

  @override
  String get samePlaceTitle => 'A memory worth revisiting here.';

  @override
  String yearRecapTitle(int year) {
    return '$year was full of moments worth revisiting.';
  }

  @override
  String get longTermEvolutionTitle => 'These photos record change over time.';

  @override
  String get annualTogetherTitle =>
      'Around this time each year, a similar set appears.';

  @override
  String get samePlaceAcrossYearsTitle =>
      'You have returned here across years.';
}
