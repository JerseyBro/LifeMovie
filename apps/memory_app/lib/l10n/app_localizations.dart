import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'LifeMovie'**
  String get appTitle;

  /// No description provided for @onboardingTitle.
  ///
  /// In zh, this message translates to:
  /// **'发现相册里那些你已经忘记的故事'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'你的照片留在设备里。我们先在本地整理时间、地点和记忆线索。'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingCta.
  ///
  /// In zh, this message translates to:
  /// **'开始看看'**
  String get onboardingCta;

  /// No description provided for @onboardingRetry.
  ///
  /// In zh, this message translates to:
  /// **'再试一次'**
  String get onboardingRetry;

  /// No description provided for @permissionUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前无法访问照片。你可以在系统设置里重新授权。'**
  String get permissionUnavailable;

  /// No description provided for @limitedPermissionHint.
  ///
  /// In zh, this message translates to:
  /// **'你可以只选择一部分照片开始体验，以后也可以随时增加。'**
  String get limitedPermissionHint;

  /// No description provided for @manageLimitedPhotos.
  ///
  /// In zh, this message translates to:
  /// **'管理已选择的照片'**
  String get manageLimitedPhotos;

  /// No description provided for @indexingTitle.
  ///
  /// In zh, this message translates to:
  /// **'正在整理你的照片'**
  String get indexingTitle;

  /// No description provided for @indexingCount.
  ///
  /// In zh, this message translates to:
  /// **'已整理 {count} 张照片和视频'**
  String indexingCount(int count);

  /// No description provided for @feedDateToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get feedDateToday;

  /// No description provided for @feedIntro.
  ///
  /// In zh, this message translates to:
  /// **'今天，我发现了几段故事。'**
  String get feedIntro;

  /// No description provided for @feedSummary.
  ///
  /// In zh, this message translates to:
  /// **'已整理 {total} 个项目 · {photos} 张照片 · {videos} 段视频'**
  String feedSummary(int total, int photos, int videos);

  /// No description provided for @privacySummary.
  ///
  /// In zh, this message translates to:
  /// **'原始照片留在这台设备上。'**
  String get privacySummary;

  /// No description provided for @emptyFeedTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有发现足够稳定的记忆'**
  String get emptyFeedTitle;

  /// No description provided for @emptyFeedSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'你可以刷新，或在照片权限里增加更多可访问照片。'**
  String get emptyFeedSubtitle;

  /// No description provided for @cardCtaYears.
  ///
  /// In zh, this message translates to:
  /// **'看看这些年'**
  String get cardCtaYears;

  /// No description provided for @cardCtaMemory.
  ///
  /// In zh, this message translates to:
  /// **'看看这段记忆'**
  String get cardCtaMemory;

  /// No description provided for @detailTitle.
  ///
  /// In zh, this message translates to:
  /// **'这段记忆'**
  String get detailTitle;

  /// No description provided for @detailTimeline.
  ///
  /// In zh, this message translates to:
  /// **'时间线'**
  String get detailTimeline;

  /// No description provided for @detailPhotos.
  ///
  /// In zh, this message translates to:
  /// **'{count} 张照片'**
  String detailPhotos(int count);

  /// No description provided for @detailVideos.
  ///
  /// In zh, this message translates to:
  /// **'{count} 段视频'**
  String detailVideos(int count);

  /// No description provided for @detailLocationHint.
  ///
  /// In zh, this message translates to:
  /// **'包含地点线索'**
  String get detailLocationHint;

  /// No description provided for @personTimelineTitle.
  ///
  /// In zh, this message translates to:
  /// **'这些年'**
  String get personTimelineTitle;

  /// No description provided for @memoryLab.
  ///
  /// In zh, this message translates to:
  /// **'Memory Lab'**
  String get memoryLab;

  /// No description provided for @debugOpenLab.
  ///
  /// In zh, this message translates to:
  /// **'打开 Memory Lab'**
  String get debugOpenLab;

  /// No description provided for @samePlaceConsecutiveYears.
  ///
  /// In zh, this message translates to:
  /// **'你已经连续 {count} 年来到这里。'**
  String samePlaceConsecutiveYears(int count);

  /// No description provided for @samePlaceMultipleYears.
  ///
  /// In zh, this message translates to:
  /// **'这个地方在 {count} 个不同年份出现在你的相册里。'**
  String samePlaceMultipleYears(int count);

  /// No description provided for @samePlaceRepeated.
  ///
  /// In zh, this message translates to:
  /// **'这些年，你已经多次回到这里。'**
  String get samePlaceRepeated;

  /// No description provided for @personAcrossYears.
  ///
  /// In zh, this message translates to:
  /// **'这个人从 {firstYear} 年开始出现在你的镜头里。'**
  String personAcrossYears(int firstYear);

  /// No description provided for @personSpanYears.
  ///
  /// In zh, this message translates to:
  /// **'这个人已经在你的相册里跨越了 {span} 年。'**
  String personSpanYears(int span);

  /// No description provided for @firstPersonMemory.
  ///
  /// In zh, this message translates to:
  /// **'这是相册里最早的一组你们合照。'**
  String get firstPersonMemory;

  /// No description provided for @firstPlaceMemory.
  ///
  /// In zh, this message translates to:
  /// **'这是相册里最早记录这个地方的一组照片。'**
  String get firstPlaceMemory;

  /// No description provided for @travelStoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'这 {days} 天，看起来像一段完整的旅程。'**
  String travelStoryTitle(int days);

  /// No description provided for @travelStorySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'{places} 个地点 · {count} 张照片和视频'**
  String travelStorySubtitle(int places, int count);

  /// No description provided for @annualTogetherConsecutive.
  ///
  /// In zh, this message translates to:
  /// **'每年差不多这个时候，这个人都会出现在你的照片里。'**
  String get annualTogetherConsecutive;

  /// No description provided for @annualTogetherRepeated.
  ///
  /// In zh, this message translates to:
  /// **'这些年，差不多这个时候，这个人多次出现在你的照片里。'**
  String get annualTogetherRepeated;

  /// No description provided for @longTermEvolutionSpan.
  ///
  /// In zh, this message translates to:
  /// **'这些照片跨越了 {span} 年。'**
  String longTermEvolutionSpan(int span);

  /// No description provided for @longTermEvolutionMultipleYears.
  ///
  /// In zh, this message translates to:
  /// **'这个地方在你的相册里出现了 {count} 个年份。'**
  String longTermEvolutionMultipleYears(int count);

  /// No description provided for @detailAiPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'正在整理这段记忆……'**
  String get detailAiPlaceholder;

  /// No description provided for @dateClusterTitle.
  ///
  /// In zh, this message translates to:
  /// **'这几天留下了很多照片。'**
  String get dateClusterTitle;

  /// No description provided for @samePlaceTitle.
  ///
  /// In zh, this message translates to:
  /// **'这里有一段值得回看的记忆。'**
  String get samePlaceTitle;

  /// No description provided for @yearRecapTitle.
  ///
  /// In zh, this message translates to:
  /// **'{year} 年，有很多值得回看的片段。'**
  String yearRecapTitle(int year);

  /// No description provided for @longTermEvolutionTitle.
  ///
  /// In zh, this message translates to:
  /// **'这些照片记录了一段时间的变化。'**
  String get longTermEvolutionTitle;

  /// No description provided for @annualTogetherTitle.
  ///
  /// In zh, this message translates to:
  /// **'每年差不多这个时候，都有一组相似的记录。'**
  String get annualTogetherTitle;

  /// No description provided for @samePlaceAcrossYearsTitle.
  ///
  /// In zh, this message translates to:
  /// **'你已经连续几年来到这里。'**
  String get samePlaceAcrossYearsTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
