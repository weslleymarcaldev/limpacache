import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/resultado.dart';
import '../models/teste.dart';
import '../state/app_state.dart';
import '../widgets/comum.dart';
import '../widgets/logo.dart';
import 'configuracoes_screen.dart';
import 'governo_screen.dart';
import 'main_shell.dart';
import 'teste_screens.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [LogoRadar(tamanho: 30), SizedBox(width: 10), Text('Radar Político')]),
        actions: [
          const BotaoComoAvaliamos(compacto: true),
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConfiguracoesScreen())),
          ),
        ],
      ),
      body: FutureView<(List<TesteModel>, List<ResultadoTeste>)>(
        chaveRecarga: s.versaoDados,
        carregar: () async => (await s.testes.testes(), await s.testes.resultados(s.usuario.id, limite: 3)),
        builder: (ctx, d) {
          final (todos, ultimos) = d;
          final testes = [...todos.where((t) => t.rapido), ...todos.where((t) => !t.rapido)];
          final titulos = {for (final t in todos) t.id: t.titulo};
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text('Olá, ${s.usuario.nome.split(' ').first}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const AvisoBanner(),
              const Secao('Seu Perfil Político Pessoal'),
              _CartaoPerfil(s: s),
              const Secao('Acesso rápido aos testes'),
              SizedBox(
                height: 116,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: testes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _MiniTeste(t: testes[i]),
                ),
              ),
              if (ultimos.isNotEmpty) ...[
                Secao('Últimos resultados', acao: TextButton(onPressed: () => MainShell.irPara(context, 1), child: const Text('Ver todos'))),
                for (final r in ultimos)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.assessment_outlined),
                      title: Text(titulos[r.testeId] ?? r.testeId),
                      subtitle: Text('${r.rotuloDescritivo}\n${dataBr(r.criadoEm)}'),
                      isThreeLine: true,
                      onTap: () async {
                        final t = await s.testes.teste(r.testeId);
                        if (t != null && context.mounted) {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultadoScreen(teste: t, resultado: r)));
                        }
                      },
                    ),
                  ),
              ],
              const Secao('Explorar'),
              _Atalho(Icons.groups_outlined, 'Comparador de candidatos', 'Compare suas posições com posições públicas declaradas.', () => MainShell.irPara(context, 3)),
              _Atalho(Icons.account_balance_outlined, 'Análise do governo atual', 'Promessas, medidas e indicadores com fonte e data.',
                  () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GovernoScreen()))),
              _Atalho(Icons.emoji_events_outlined, 'Quiz de conhecimento político', 'Perguntas factuais sobre instituições, eleições e Constituição.', () => MainShell.irPara(context, 4)),
              _Atalho(Icons.flag_outlined, 'Correções e revisões', 'Reporte erros ou informações desatualizadas.', () => MainShell.irPara(context, 5)),
              const SizedBox(height: 8),
              const Center(child: BotaoComoAvaliamos()),
            ],
          );
        },
      ),
    );
  }
}

class _CartaoPerfil extends StatelessWidget {
  final AppState s;
  const _CartaoPerfil({required this.s});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = s.perfil;
    return Card(
      color: cs.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => MainShell.irPara(context, p == null ? 1 : 2),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: p == null
              ? Row(children: [
                  Icon(Icons.radar, size: 40, color: cs.onPrimaryContainer),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text('Você ainda não concluiu nenhum teste. Comece pelo Teste Rápido (3 minutos).',
                        style: TextStyle(color: cs.onPrimaryContainer, fontSize: 15)),
                  ),
                  Icon(Icons.chevron_right, color: cs.onPrimaryContainer),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Classificação estimada', style: TextStyle(color: cs.onPrimaryContainer, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(p.rotulo, style: TextStyle(color: cs.onPrimaryContainer, fontSize: 18, fontWeight: FontWeight.w700)),
                  if (p.indiceGeral != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      label: 'Índice geral ${p.indiceGeral!.round()} de 100',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: p.indiceGeral! / 100, minHeight: 10,
                            backgroundColor: cs.surface.withValues(alpha: .5), color: cs.primary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text('Esquerda', style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer)),
                      const Spacer(),
                      Text('Direita', style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer)),
                    ]),
                  ],
                  const SizedBox(height: 8),
                  Text('Estimativa baseada em ${p.eixos.length} eixos. Toque para ver detalhes.',
                      style: TextStyle(color: cs.onPrimaryContainer, fontSize: 12)),
                ]),
        ),
      ),
    );
  }
}

class _MiniTeste extends StatelessWidget {
  final TesteModel t;
  const _MiniTeste({required this.t});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 150,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TesteIntroScreen(teste: t))),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(AppTheme.iconeTeste(t.icone), color: cs.primary),
              const Spacer(),
              Text(t.titulo.replaceFirst(RegExp(r'^Teste (de )?'), ''), maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${t.perguntas.length} perguntas', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Atalho extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String sub;
  final VoidCallback onTap;
  const _Atalho(this.icone, this.titulo, this.sub, this.onTap);
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(child: Icon(icone)),
          title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(sub),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
