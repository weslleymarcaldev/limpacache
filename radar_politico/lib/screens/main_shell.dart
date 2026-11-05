import 'package:flutter/material.dart';

import 'candidatos_screen.dart';
import 'correcoes_screen.dart';
import 'home_screen.dart';
import 'perfil_screen.dart';
import 'quiz_screen.dart';
import 'testes_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  static void irPara(BuildContext context, int aba) => context.findAncestorStateOfType<_MainShellState>()?.irPara(aba);
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _aba = 0;
  void irPara(int i) => setState(() => _aba = i);

  static const _telas = [HomeScreen(), TestesScreen(), PerfilScreen(), CandidatosScreen(), QuizScreen(), CorrecoesScreen()];

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _aba == 0,
        onPopInvokedWithResult: (pop, _) {
          if (!pop) setState(() => _aba = 0);
        },
        child: Scaffold(
          body: IndexedStack(index: _aba, children: _telas),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _aba,
            onDestinationSelected: irPara,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
              NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'Testes'),
              NavigationDestination(icon: Icon(Icons.radar_outlined), selectedIcon: Icon(Icons.radar), label: 'Perfil'),
              NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Candidatos'),
              NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Quiz'),
              NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Correções'),
            ],
          ),
        ),
      );
}
