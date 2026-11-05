import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/resultado.dart';
import '../models/teste.dart';
import '../state/app_state.dart';
import '../widgets/comum.dart';
import 'teste_screens.dart';

class TestesScreen extends StatelessWidget {
  const TestesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Testes políticos'), actions: const [BotaoComoAvaliamos(compacto: true)]),
      body: FutureView<(List<TesteModel>, Map<String, ResultadoTeste>, Set<String>)>(
        chaveRecarga: s.versaoDados,
        carregar: () async => (
          await s.testes.testes(),
          await s.testes.ultimosPorTeste(s.usuario.id),
          await s.testes.testesEmAndamento(s.usuario.id),
        ),
        builder: (ctx, d) {
          final (testes, ultimos, andamento) = d;
          final ordenados = [...testes.where((t) => t.rapido), ...testes.where((t) => !t.rapido)];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Cada teste mede eixos diferentes. Seu Perfil Político Pessoal consolida automaticamente o resultado mais recente de cada teste.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('${ultimos.length} de ${testes.length} testes concluídos', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              for (final t in ordenados) _CartaoTeste(t: t, ultimo: ultimos[t.id], emAndamento: andamento.contains(t.id)),
            ],
          );
        },
      ),
    );
  }
}

class _CartaoTeste extends StatelessWidget {
  final TesteModel t;
  final ResultadoTeste? ultimo;
  final bool emAndamento;
  const _CartaoTeste({required this.t, this.ultimo, required this.emAndamento});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = emAndamento ? 'Em andamento' : ultimo != null ? 'Concluído' : 'Não iniciado';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TesteIntroScreen(teste: t))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 24, backgroundColor: cs.primaryContainer, child: Icon(AppTheme.iconeTeste(t.icone), color: cs.onPrimaryContainer)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(t.descricao, style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  _Tag('${t.perguntas.length} perguntas'),
                  _Tag('~${t.tempoMin} min'),
                  _Tag(status, destaque: ultimo != null || emAndamento),
                ]),
                if (ultimo != null) ...[
                  const SizedBox(height: 8),
                  Text('Último resultado: ${ultimo!.rotuloDescritivo}', style: const TextStyle(fontSize: 13)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String t;
  final bool destaque;
  const _Tag(this.t, {this.destaque = false});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: destaque ? cs.secondaryContainer : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
      child: Text(t, style: TextStyle(fontSize: 12, color: destaque ? cs.onSecondaryContainer : cs.onSurfaceVariant)),
    );
  }
}
