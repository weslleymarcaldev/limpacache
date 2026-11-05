import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../state/app_state.dart';
import '../widgets/comum.dart';
import '../widgets/logo.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    final s = context.read<AppState>();
    await Future.wait([s.inicializar(), Future.delayed(const Duration(milliseconds: 1400))]);
    if (!mounted || !s.pronto) {
      setState(() {});
      return;
    }
    final Widget destino = s.precisaOnboarding
        ? const OnboardingScreen()
        : s.logadoOuVisitanteEscolhido
            ? const MainShell()
            : const LoginScreen();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, _, _) => destino,
      transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: s.erroInicializacao != null
            ? ErroView(s.erroInicializacao!, tentarNovamente: _iniciar)
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const LogoRadar(tamanho: 120),
                    const SizedBox(height: 24),
                    Text(AppInfo.nome, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    Text(AppInfo.avisoCurto, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
                    const SizedBox(height: 32),
                    const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
                  ]),
                ),
              ),
      ),
    );
  }
}
