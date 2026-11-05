import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/eixo.dart';
import '../models/resultado.dart';
import '../models/teste.dart';
import '../state/app_state.dart';
import '../widgets/comum.dart';
import '../widgets/graficos.dart';
import 'main_shell.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});
  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _cartao = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.perfil;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil Político Pessoal'), actions: const [BotaoComoAvaliamos(compacto: true)]),
      body: p == null
          ? _vazio(context)
          : FutureView<(Map<String, Eixo>, List<ResultadoTeste>, List<TesteModel>)>(
              chaveRecarga: s.versaoDados,
              carregar: () async => (await s.eixos(), await s.testes.resultados(s.usuario.id), await s.testes.testes()),
              builder: (ctx, d) {
                final (defs, todos, testes) = d;
                final ids = defs.keys.where(p.eixos.containsKey).toList();
                final analise = s.scoring.analisar(p.eixos, defs);
                final cron = todos.reversed.where((r) => r.indiceGeral != null).toList();
                final concluidos = todos.map((r) => r.testeId).toSet();
                final texto = s.scoring.textoCompartilhamento(p.rotulo);
                final cs = Theme.of(context).colorScheme;
                return ListView(padding: const EdgeInsets.all(16), children: [
                  RepaintBoundary(
                    key: _cartao,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Classificação estimada', style: TextStyle(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(p.rotulo, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        if (p.indiceGeral != null)
                          Text('Índice geral: ${p.indiceGeral!.round()} de 100 · ${p.classificacao}'),
                        Text('Consolidado de ${concluidos.length} de ${testes.length} testes · atualizado em ${dataBr(p.atualizadoEm)}',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        RadarEixos(eixos: {for (final i in ids) i: defs[i]!}, valores: p.pcts),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const AvisoBanner(texto: 'Esta classificação é uma estimativa construída a partir das suas respostas, e não um rótulo definitivo. Posições podem mudar com o tempo e variar conforme o tema.'),
                  const Secao('Pontuação por eixo'),
                  for (var k = 0; k < ids.length; k++)
                    EixoBarra(
                      eixo: defs[ids[k]]!,
                      pct: p.eixos[ids[k]]!.pct,
                      cor: AppTheme.coresEixos[k % AppTheme.coresEixos.length],
                      legenda: '${s.scoring.faixaEixo(p.eixos[ids[k]]!.pct, defs[ids[k]]!).rotulo} · baseado em ~${p.eixos[ids[k]]!.peso.round()} respostas',
                    ),
                  if (ids.length < defs.length)
                    Text('Eixos ainda sem dados: ${defs.values.where((e) => !p.eixos.containsKey(e.id)).map((e) => e.nome).join(', ')}. Faça os testes temáticos para completá-los.',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  const Secao('Como interpretar'),
                  for (final e in ids)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(defs[e]!.nome),
                      children: [Align(alignment: Alignment.centerLeft, child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text('${defs[e]!.descricao}\n\n${s.scoring.faixaEixo(p.eixos[e]!.pct, defs[e]!).explicacao}'),
                      ))],
                    ),
                  const Secao('Pontos fortes e divergências'),
                  for (final f in analise.pontosFortes) _linha(Icons.trending_flat, f),
                  for (final f in analise.divergencias) _linha(Icons.compare_arrows, f),
                  const Secao('Evolução ao longo do tempo'),
                  EvolucaoLinha(
                    valores: cron.map((r) => r.indiceGeral!).toList(),
                    rotulos: cron.map((r) => '${r.criadoEm.day}/${r.criadoEm.month}').toList(),
                  ),
                  const Secao('Exportar ou compartilhar'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.tonalIcon(
                        onPressed: () => s.share.compartilharImagem(_cartao, texto: texto, nomeArquivo: 'perfil_radar_politico.png'),
                        icon: const Icon(Icons.image_outlined), label: const Text('Imagem')),
                    FilledButton.tonalIcon(
                        onPressed: () => s.share.compartilharTexto(_resumoCompleto(p.rotulo, ids, defs, p.eixos)),
                        icon: const Icon(Icons.share_outlined), label: const Text('Texto')),
                    FilledButton.tonalIcon(
                        onPressed: () async {
                          await s.share.copiar(_resumoCompleto(p.rotulo, ids, defs, p.eixos));
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resumo copiado.')));
                        },
                        icon: const Icon(Icons.copy), label: const Text('Copiar')),
                  ]),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(onPressed: () => MainShell.irPara(context, 3), icon: const Icon(Icons.groups_outlined),
                      label: const Text('Comparar com posições de candidatos')),
                ]);
              },
            ),
    );
  }

  String _resumoCompleto(String rotulo, List<String> ids, Map<String, Eixo> defs, Map<String, EixoScore> eixos) {
    final b = StringBuffer('Meu Perfil Político Pessoal no Radar Político: $rotulo.\n\n');
    for (final i in ids) {
      b.writeln('• ${defs[i]!.nome}: ${eixos[i]!.pct.round()}% (0 = ${defs[i]!.poloA}; 100 = ${defs[i]!.poloB})');
    }
    b.write('\n${AppInfo.avisoEstimativa}');
    return b.toString();
  }

  Widget _linha(IconData i, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 20), const SizedBox(width: 8), Expanded(child: Text(t)),
        ]),
      );

  Widget _vazio(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.radar, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text('Seu perfil aparece aqui depois do primeiro teste concluído.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => MainShell.irPara(context, 1), child: const Text('Ir para os testes')),
          ]),
        ),
      );
}
