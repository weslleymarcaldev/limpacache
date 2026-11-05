import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../widgets/logo.dart';
import 'main_shell.dart';

class LoginScreen extends StatefulWidget {
  final bool voltarAoFinal;
  const LoginScreen({super.key, this.voltarAoFinal = false});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _carregando = false;
  String? _erro;

  Future<void> _google() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final n = await context.read<AppState>().entrarComGoogle();
      if (!mounted) return;
      if (n > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seus resultados como visitante foram vinculados à sua conta.')));
      }
      _seguir();
    } on AuthException catch (e) {
      setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _visitante() async {
    await context.read<AppState>().entrarComoVisitante();
    if (mounted) _seguir();
  }

  void _seguir() {
    if (widget.voltarAoFinal) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainShell()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.voltarAoFinal ? AppBar(title: const Text('Entrar')) : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              const LogoRadar(tamanho: 96),
              const SizedBox(height: 20),
              Text('Bem-vindo ao ${AppInfo.nome}', textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text('Entre com sua Conta Google para vincular seu perfil e histórico, ou continue sem login. '
                  'No modo visitante, tudo fica salvo apenas neste aparelho.',
                  textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _carregando ? null : _google,
                  icon: _carregando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.account_circle_outlined),
                  label: const Text('Entrar com Google'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _carregando ? null : _visitante,
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Continuar sem login'),
                ),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(12)),
                    child: Text(_erro!, style: TextStyle(color: cs.onErrorContainer)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(AppInfo.avisoPermanente, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      ),
    );
  }
}
