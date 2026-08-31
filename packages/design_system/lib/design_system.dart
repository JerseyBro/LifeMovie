library;

import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const xSmall = 4.0;
  static const small = 8.0;
  static const medium = 16.0;
  static const large = 24.0;
  static const xLarge = 40.0;
}

abstract final class AppRadius {
  static const card = 20.0;
  static const hero = 28.0;
  static const button = 14.0;
}

abstract final class AppColor {
  static const ink = Color(0xff1f2933);
  static const canvas = Color(0xfff5f4f0);
  static const surface = Color(0xfffffcf6);
  static const muted = Color(0xff6f746f);
  static const accent = Color(0xff496b55);
  static const film = Color(0xff2e332f);
}

ThemeData buildNeutralTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColor.canvas,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColor.accent),
  cardTheme: const CardThemeData(
    margin: EdgeInsets.zero,
    color: AppColor.surface,
    elevation: 0,
  ),
  textTheme: const TextTheme(
    displaySmall: TextStyle(
      fontSize: 34,
      height: 1.14,
      fontWeight: FontWeight.w600,
      letterSpacing: -.6,
      color: AppColor.ink,
    ),
    headlineSmall: TextStyle(
      fontSize: 26,
      height: 1.18,
      fontWeight: FontWeight.w600,
      color: AppColor.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.22,
      fontWeight: FontWeight.w600,
      color: AppColor.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: AppColor.ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.55, color: AppColor.ink),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: AppColor.muted),
  ),
);

class LifeStoryCard extends StatelessWidget {
  const LifeStoryCard({
    super.key,
    required this.hero,
    required this.title,
    required this.metadata,
    required this.cta,
    required this.onTap,
  });

  final Widget hero;
  final String title;
  final String metadata;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.hero),
    ),
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          hero,
          Padding(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.small),
                Text(metadata, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.medium),
                Text(
                  '$cta →',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppColor.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class TimelineYearLabel extends StatelessWidget {
  const TimelineYearLabel({super.key, required this.year});

  final int year;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: AppSpacing.large,
      bottom: AppSpacing.small,
    ),
    child: Text('$year', style: Theme.of(context).textTheme.headlineSmall),
  );
}
