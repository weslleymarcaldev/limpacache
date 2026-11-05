import 'package:flutter/material.dart';

/// Paleta neutra (grafite/ardósia), escolhida para não remeter a cores partidárias.
class AppTheme {
  static const _semente = Color(0xFF5A6273);

  static ThemeData claro() => _base(ColorScheme.fromSeed(seedColor: _semente, brightness: Brightness.light));
  static ThemeData escuro() => _base(ColorScheme.fromSeed(seedColor: _semente, brightness: Brightness.dark));

  static ThemeData _base(ColorScheme cs) => ThemeData(
        colorScheme: cs,
        fontFamily: 'Roboto',
        useMaterial3: true,
        visualDensity: VisualDensity.standard,
        appBarTheme: AppBarTheme(centerTitle: false, backgroundColor: cs.surface, scrolledUnderElevation: 1),
        cardTheme: CardThemeData(
          elevation: 0,
          color: cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: EdgeInsets.zero,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 52), textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 52)),
        ),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        chipTheme: const ChipThemeData(showCheckmark: true),
        navigationBarTheme: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ),
      );

  /// Cores dos eixos nos gráficos: tons distintos e dessaturados, sem vermelho/verde/amarelo partidários.
  static const coresEixos = [
    Color(0xFF5B6CA8), Color(0xFF8A6FB0), Color(0xFF3F8A8C), Color(0xFFA0785A),
    Color(0xFF6B7F99), Color(0xFF9C6B8A), Color(0xFF5E8C6F), Color(0xFF8C8A5E),
  ];

  static Color corStatus(ColorScheme cs, String status) => switch (status) {
        'cumprida' => cs.primary,
        'parcialmente_cumprida' => cs.tertiary,
        'em_andamento' => cs.secondary,
        'nao_cumprida' => cs.outline,
        _ => cs.onSurfaceVariant,
      };

  static IconData iconeStatus(String status) => switch (status) {
        'cumprida' => Icons.check_circle_outline,
        'parcialmente_cumprida' => Icons.timelapse,
        'em_andamento' => Icons.pending_outlined,
        'nao_cumprida' => Icons.radio_button_unchecked,
        _ => Icons.insights_outlined,
      };

  static IconData iconeTeste(String nome) => switch (nome) {
        'payments' => Icons.payments_outlined,
        'diversity_3' => Icons.diversity_3_outlined,
        'local_police' => Icons.local_police_outlined,
        'forest' => Icons.forest_outlined,
        'account_balance' => Icons.account_balance_outlined,
        'gavel' => Icons.gavel_outlined,
        'bolt' => Icons.bolt_outlined,
        _ => Icons.quiz_outlined,
      };
}
