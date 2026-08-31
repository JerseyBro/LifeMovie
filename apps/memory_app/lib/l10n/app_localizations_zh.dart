// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'LifeMovie';

  @override
  String get onboardingTitle => '发现相册里那些你已经忘记的故事';

  @override
  String get onboardingSubtitle => '你的照片留在设备里。我们先在本地整理时间、地点和记忆线索。';

  @override
  String get onboardingCta => '开始看看';

  @override
  String get onboardingRetry => '再试一次';

  @override
  String get permissionUnavailable => '当前无法访问照片。你可以在系统设置里重新授权。';

  @override
  String get limitedPermissionHint => '你可以只选择一部分照片开始体验，以后也可以随时增加。';

  @override
  String get manageLimitedPhotos => '管理已选择的照片';

  @override
  String get indexingTitle => '正在整理你的照片';

  @override
  String indexingCount(int count) {
    return '已整理 $count 张照片和视频';
  }

  @override
  String get feedDateToday => '今天';

  @override
  String get feedIntro => '今天，我发现了几段故事。';

  @override
  String feedSummary(int total, int photos, int videos) {
    return '已整理 $total 个项目 · $photos 张照片 · $videos 段视频';
  }

  @override
  String get privacySummary => '原始照片留在这台设备上。';

  @override
  String get emptyFeedTitle => '还没有发现足够稳定的记忆';

  @override
  String get emptyFeedSubtitle => '你可以刷新，或在照片权限里增加更多可访问照片。';

  @override
  String get cardCtaYears => '看看这些年';

  @override
  String get cardCtaMemory => '看看这段记忆';

  @override
  String get detailTitle => '这段记忆';

  @override
  String get detailTimeline => '时间线';

  @override
  String detailPhotos(int count) {
    return '$count 张照片';
  }

  @override
  String detailVideos(int count) {
    return '$count 段视频';
  }

  @override
  String get detailLocationHint => '包含地点线索';

  @override
  String get personTimelineTitle => '这些年';

  @override
  String get memoryLab => 'Memory Lab';

  @override
  String get debugOpenLab => '打开 Memory Lab';
}
