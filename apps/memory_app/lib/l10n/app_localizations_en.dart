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
  String get viewerLoadFailed => 'Unable to load photo';

  @override
  String get viewerRetry => 'Retry';

  @override
  String get viewerFavorite => 'Favorite';

  @override
  String get viewerShare => 'Share';

  @override
  String get viewerInfo => 'Info';

  @override
  String get viewerEdit => 'Edit';

  @override
  String get viewerVideoPlay => 'Play';

  @override
  String get viewerVideoPause => 'Pause';

  @override
  String get viewerVideoMute => 'Mute';

  @override
  String get viewerVideoUnmute => 'Unmute';

  @override
  String get viewerVideoUnavailable => 'This video can\'t be played right now';

  @override
  String get infoTitle => 'Photo Info';

  @override
  String get infoDate => 'Date';

  @override
  String get infoTime => 'Time';

  @override
  String get infoLocation => 'Location';

  @override
  String get infoType => 'Type';

  @override
  String get infoSize => 'Dimensions';

  @override
  String get infoDuration => 'Duration';

  @override
  String get infoMemory => 'Memory';

  @override
  String get infoTypePhoto => 'Photo';

  @override
  String get infoTypeVideo => 'Video';

  @override
  String get infoTypeLivePhoto => 'Live Photo';

  @override
  String get editorCancel => 'Cancel';

  @override
  String get editorDone => 'Done';

  @override
  String get editorTabAdjust => 'Adjust';

  @override
  String get editorTabFilter => 'Filters';

  @override
  String get editorTabCrop => 'Crop';

  @override
  String get editorExposure => 'Exposure';

  @override
  String get editorBrightness => 'Brightness';

  @override
  String get editorContrast => 'Contrast';

  @override
  String get editorHighlights => 'Highlights';

  @override
  String get editorShadows => 'Shadows';

  @override
  String get editorSaturation => 'Saturation';

  @override
  String get editorWarmth => 'Warmth';

  @override
  String get editorFilterNone => 'None';

  @override
  String get editorFilterVivid => 'Vivid';

  @override
  String get editorFilterWarm => 'Warm';

  @override
  String get editorFilterCool => 'Cool';

  @override
  String get editorFilterMono => 'Mono';

  @override
  String get editorRotateLeft => 'Rotate left';

  @override
  String get editorRotateRight => 'Rotate right';

  @override
  String get editorStraighten => 'Straighten';

  @override
  String get editorAspectFree => 'Free';

  @override
  String get editorAspectSquare => 'Square';

  @override
  String get editorReset => 'Reset';

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

  @override
  String get navDiscover => 'Discover';

  @override
  String get navTimeline => 'Timeline';

  @override
  String get navSearch => 'Search';

  @override
  String get discoverForYou => 'Today, I\'d like to show you these.';

  @override
  String get discoverContinue => 'Keep watching';

  @override
  String get discoverStories => 'Stories you may not have noticed';

  @override
  String get discoverNoResults => 'No memories match the current filters.';

  @override
  String get sectionRecent => 'Recently Discovered';

  @override
  String get sectionPeople => 'People';

  @override
  String get sectionPlaces => 'Places';

  @override
  String get sectionTrips => 'Trips';

  @override
  String get sectionYears => 'Years';

  @override
  String get sectionFirstMemories => 'First Memories';

  @override
  String get sectionTogether => 'Together, Every Year';

  @override
  String get sectionEvolution => 'Over the Years';

  @override
  String get memoryTypeRevisit => 'Revisit';

  @override
  String get memoryTypeGathering => 'Gatherings';

  @override
  String get filterPlacePrefix => 'Place';

  @override
  String get filterPerson => 'This person';

  @override
  String get filterPhotos => 'Photos';

  @override
  String get filterVideos => 'Videos';

  @override
  String get filterFavorites => 'Favorites';

  @override
  String get filterClearAll => 'Clear all';

  @override
  String get filterSheetTitle => 'Filters';

  @override
  String get filterGroupTime => 'Time';

  @override
  String get filterGroupPlace => 'Place';

  @override
  String get filterGroupMemory => 'Memory type';

  @override
  String get filterGroupMedia => 'Media';

  @override
  String get filterApply => 'See results';

  @override
  String get sortRecommended => 'Recommended';

  @override
  String get sortNewest => 'Newest';

  @override
  String get sortOldest => 'Oldest';

  @override
  String get sortMostPhotos => 'Most photos';

  @override
  String get searchHint => 'Search years, places, stories…';

  @override
  String get searchFilters => 'Advanced filters';

  @override
  String get searchNoResults => 'No matching memories. Try another term.';

  @override
  String get timelineEmpty =>
      'Your timeline will appear here after organizing.';

  @override
  String timelineMonth(int month) {
    return 'Month $month';
  }

  @override
  String placeAssetCount(int count) {
    return '$count photos and videos';
  }

  @override
  String get personNeutralLabel => 'This person';

  @override
  String personPhotoCount(int count) {
    return '$count photos and videos';
  }
}
