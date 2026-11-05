import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/logo.dart';
import 'login_screen.dart';
import 'termos_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _pagina = 0;
  bool _aceite = false;

  static const _paginas = [
    (Icons.radar, 'Entenda sua posição política',
        'Responda testes temáticos e monte um Perfil Político Pessoal com gráficos por eixo: economia, segurança, costumes, meio ambiente, papel do Estado e outros.'),
    (Icons.balance, 'Não existe resposta certa ou errada',
        'Os testes não julgam suas opiniões. Eles apenas organizam suas respostas em eixos para ajudar você a refletir.'),
    (Icons.insights, 'Resultados são estimativas',
        'As classificações são aproximações baseadas nas suas respostas e em informações públicas. Não são rótulos definitivos e não representam recomendação de voto.'),
    (Icons.fact_check, 'Informação verificável',
        'Promessas, ações e posições públicas são apresentadas com fonte e data. Encontrou algo errado? Toque em "Reportar correção" em qualquer conteúdo.'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ultima = _pagina == _paginas.length;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView(
              controller: _pc,
              onPageChanged: (i) => setState(() => _pagina = i),
              children: [
                for (final p in _paginas)
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      CircleAvatar(radius: 48, backgroundColor: cs.primaryContainer, child: Icon(p.$1, size: 48, color: cs.onPrimaryContainer)),
                      const SizedBox(height: 28),
                      Semantics(header: true, child: Text(p.$2, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
                      const SizedBox(height: 16),
                      Text(p.$3, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45)),
                    ]),
                  ),
                _paginaTermos(context),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(children: [
              for (var i = 0; i <= _paginas.length; i++)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: i == _pagina ? 22 : 8, height: 8,
                  decoration: BoxDecoration(color: i == _pagina ? cs.primary : cs.outlineVariant, borderRadius: BorderRadius.circular(4)),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: ultima
                        ? (_aceite ? _concluir : null)
                        : () => _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                    child: Text(ultima ? 'Aceitar e continuar' : 'Próximo', textAlign: TextAlign.center),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _paginaTermos(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: LogoRadar(tamanho: 72)),
          const SizedBox(height: 16),
          Text('Termos de uso e privacidade', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const Text(
              '• O Radar Político é uma ferramenta educativa e informativa. Não recomenda votos e não defende partidos, candidatos, governos ou ideologias.\n\n'
              '• Suas respostas ficam salvas no próprio aparelho. Se você entrar com Google, os dados ficam vinculados à sua conta neste aparelho.\n\n'
              '• Ao reportar uma correção com a análise por IA ativada, o texto do reporte é enviado ao provedor de IA configurado, sem suas respostas aos testes.\n\n'
              '• Você pode apagar seus dados a qualquer momento em Configurações.',
              style: TextStyle(height: 1.4)),
          TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermosScreen())),
              child: const Text('Ler termos de uso e política de privacidade completos')),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _aceite,
            onChanged: (v) => setState(() => _aceite = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Li e aceito os termos de uso e a política de privacidade'),
          ),
        ],
      );

  void _concluir() {
    context.read<AppState>().concluirOnboarding();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }
}
