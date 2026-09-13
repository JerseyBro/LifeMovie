import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:memory_app/app/memory_app_root.dart';
import 'package:memory_app/l10n/app_localizations.dart';

void main() => runApp(const MemoryApp());

class MemoryApp extends StatelessWidget {
  const MemoryApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LifeMovie',
    theme: buildNeutralTheme(),
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const MemoryAppRoot(),
  );
}
