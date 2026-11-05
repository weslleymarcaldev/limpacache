import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';
import 'state/app_state.dart';

class RadarPoliticoApp extends StatelessWidget {
  const RadarPoliticoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final modo = context.select<AppState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: AppInfo.nome,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro(),
      darkTheme: AppTheme.escuro(),
      themeMode: modo,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}
