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
}
