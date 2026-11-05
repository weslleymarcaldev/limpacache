import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/conteudo.dart';
import '../models/eixo.dart';
import '../services/compatibilidade_service.dart';
import '../state/app_state.dart';
import '../widgets/comum.dart';
import '../widgets/graficos.dart';
import 'main_shell.dart';

class CandidatosScreen extends StatefulWidget {
  const CandidatosScreen({super.key});
  @override
  State<CandidatosScreen> createState() => _CandidatosScreenState();
}

class _CandidatosScreenState extends State<CandidatosScreen> {
  String _busca = '';
  bool _porCompat = false;
  Set<String>? _temas; // eixos selecionados para a compatibilidade

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final perfil = s.perfil;
    return Scaffold(
      appBar: AppBar(title: const Text('Candidatos e políticos'), actions: const [BotaoComoAvaliamos(compacto: true)]),
      body: FutureView<(List<Candidato>, Map<String, Eixo>, String?)>(
        chaveRecarga: s.versaoDados,
        carregar: () async => (await s.conteudo.candidatos(), await s.eixos(), await s.conteudo.meta('aviso_candidatos')),
        builder: (ctx, d) {
          final (cands, defs, aviso) = d;
          var lista = cands.where((c) =>
              _busca.isEmpty ||
              '${c.nome} ${c.partido} ${c.cargo} ${c.uf}'.toLowerCase().contains(_busca.toLowerCase())).toList();
          List<ResultadoCompat>? compat;
          if (perfil != null) {
            compat = const CompatibilidadeService().ordenar(perfil.pcts, lista, defs, eixosSelecionados: _temas);
            if (_porCompat) lista = compat.map((r) => r.candidato).toList();
          }
          final mapaCompat = {for (final r in compat ?? <ResultadoCompat>[]) r.candidato.id: r};
          return ListView(padding: const EdgeInsets.all(16), children: [
            const AvisoBanner(texto: AppInfo.avisoCompatibilidade),
            if (aviso != null) ...[const SizedBox(height: 8), Text(aviso, style: Theme.of(context).textTheme.bodySmall)],
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar por nome, partido, cargo ou UF'),
              onChanged: (v) => setState(() => _busca = v),
            ),
            const SizedBox(height: 8),
            if (perfil == null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Faça ao menos um teste para ver a compatibilidade estimada com cada político.'),
                  trailing: TextButton(onPressed: () => MainShell.irPara(context, 1), child: const Text('Testes')),
                ),
              )
            else ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ordenar por compatibilidade com as suas respostas'),
                subtitle: const Text('Ordem por estimativa, não por qualidade ou preferência.'),
                value: _porCompat,
                onChanged: (v) => setState(() => _porCompat = v),
              ),
              Text('Temas considerados na compatibilidade:', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in defs.values.where((e) => perfil.eixos.containsKey(e.id)))
                  FilterChip(
                    label: Text(e.nome),
                    selected: _temas?.contains(e.id) ?? true,
                    onSelected: (sel) => setState(() {
                      final atual = _temas ?? defs.keys.where(perfil.eixos.containsKey).toSet();
                      sel ? atual.add(e.id) : atual.remove(e.id);
                      _temas = atual.isEmpty ? null : {...atual};
                    }),
                  ),
              ]),
              if (_porCompat)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Políticos com maior compatibilidade com as suas respostas nos temas selecionados:',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
            ],
            const SizedBox(height: 8),
            for (final c in lista) _CartaoCandidato(c: c, compat: mapaCompat[c.id]),
          ]);
        },
      ),
    );
  }
}

class _CartaoCandidato extends StatelessWidget {
  final Candidato c;
  final ResultadoCompat? compat;
  const _CartaoCandidato({required this.c, this.compat});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(backgroundColor: cs.secondaryContainer, child: Text(c.iniciais, style: TextStyle(color: cs.onSecondaryContainer))),
        title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${c.partido} · ${c.uf}\n${c.cargo}'),
        isThreeLine: true,
        trailing: compat == null
            ? const Icon(Icons.chevron_right)
            : Semantics(
                label: 'Compatibilidade estimada ${compat!.geral.round()} por cento',
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${compat!.geral.round()}%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: cs.primary)),
                  const Text('compat.', style: TextStyle(fontSize: 11)),
                ]),
              ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CandidatoDetalheScreen(c: c))),
      ),
    );
  }
}

class CandidatoDetalheScreen extends StatelessWidget {
  final Candidato c;
  const CandidatoDetalheScreen({super.key, required this.c});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(c.nome), actions: [
        BotaoReportar(tipo: 'candidato', id: c.id, trecho: '${c.nome} — ${c.cargo} (${c.partido})\n${c.resumo}', icone: true),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          CircleAvatar(radius: 32, backgroundColor: cs.secondaryContainer,
              child: Text(c.iniciais, style: TextStyle(fontSize: 22, color: cs.onSecondaryContainer))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.nome, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text('${c.partido} · ${c.uf}'),
              Text(c.cargo, style: TextStyle(color: cs.onSurfaceVariant)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Text(c.resumo, style: const TextStyle(height: 1.4)),
        if (c.aviso != null) ...[const SizedBox(height: 8), AvisoBanner(texto: c.aviso!, icone: Icons.update)],
        NotaRevisao(tipo: 'candidato', id: c.id),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: s.perfil == null
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComparacaoScreen(c: c))),
          icon: const Icon(Icons.compare_arrows),
          label: Text(s.perfil == null ? 'Faça um teste para comparar' : 'Comparar com meu perfil'),
        ),
        for (final tipo in Candidato.tiposRotulo.keys)
          if ((c.itens[tipo] ?? []).isNotEmpty) ...[
            Secao(Candidato.tiposRotulo[tipo]!),
            for (final it in c.itens[tipo]!) _ItemInfoTile(it),
          ],
        const Secao('Fontes'),
        for (final f in c.fontes) FonteLink(fonte: f.titulo, url: f.url),
        const SizedBox(height: 8),
        Text('Estimativa de posição por eixo baseada em: ${c.baseEixos}', style: Theme.of(context).textTheme.bodySmall),
        Text('Dados verificados até ${c.atualizadoEm}.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        const AvisoBanner(texto: 'Políticos são apresentados como representantes públicos. Posições podem mudar ao longo do tempo, e a ausência de um item não significa que ele não exista.'),
        const SizedBox(height: 8),
        Row(children: [
          const BotaoComoAvaliamos(),
          const Spacer(),
          BotaoReportar(tipo: 'candidato', id: c.id, trecho: '${c.nome} — ${c.cargo}'),
        ]),
      ]),
    );
  }
}

class _ItemInfoTile extends StatelessWidget {
  final ItemInfo it;
  const _ItemInfoTile(this.it);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 6)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(it.texto, style: const TextStyle(height: 1.35)),
              if (it.fonte != null) FonteLink(fonte: it.fonte!, data: it.data),
              if (it.emRevisao) const Padding(padding: EdgeInsets.only(top: 4), child: ChipRevisao()),
            ]),
          ),
        ]),
      );
}

class ComparacaoScreen extends StatelessWidget {
  final Candidato c;
  const ComparacaoScreen({super.key, required this.c});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final perfil = s.perfil;
    return Scaffold(
      appBar: AppBar(title: const Text('Comparação'), actions: const [BotaoComoAvaliamos(compacto: true)]),
      body: perfil == null
          ? const Center(child: Text('Conclua um teste para comparar.'))
          : FutureView<Map<String, Eixo>>(
              carregar: s.eixos,
              builder: (ctx, defs) {
                final r = const CompatibilidadeService().comparar(perfil.pcts, c, defs);
                final ids = r.eixos.map((e) => e.eixo.id).toList();
                return ListView(padding: const EdgeInsets.all(16), children: [
                  Text('Você × ${c.nome}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Card(
                    color: cs.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Text('${r.geral.round()}%', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: cs.onPrimaryContainer)),
                        const SizedBox(width: 16),
                        Expanded(child: Text('Compatibilidade estimada em ${r.eixos.length} eixos.\n${r.frase}',
                            style: TextStyle(color: cs.onPrimaryContainer))),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (ids.length >= 3)
                    RadarEixos(
                      eixos: {for (final i in ids) i: defs[i]!},
                      valores: {for (final e in r.eixos) e.eixo.id: e.usuario},
                      comparacao: {for (final e in r.eixos) e.eixo.id: e.candidato},
                    ),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.circle, size: 12, color: cs.primary), const Text(' Você   '),
                    Icon(Icons.change_history, size: 12, color: cs.tertiary), Text(' ${c.nome.split(' ').first} (estimativa)'),
                  ]),
                  const Secao('Compatibilidade por eixo'),
                  BarrasCompat(dados: [for (final e in r.eixos) MapEntry(e.eixo.nome, e.compatibilidade)]),
                  for (final e in r.eixos)
                    EixoBarra(eixo: e.eixo, pct: e.usuario, comparacao: e.candidato, rotuloComparacao: c.nome,
                        legenda: 'Compatibilidade: ${e.compatibilidade.round()}% · Você ${e.usuario.round()} · ${c.nome.split(' ').first} ${e.candidato.round()}'),
                  const Secao('Temas com convergência'),
                  if (r.convergencias.isEmpty) const Text('Nenhum eixo com alta convergência.'),
                  for (final e in r.convergencias)
                    Text('• ${e.eixo.nome}: suas respostas e as posições públicas declaradas estão próximas (${e.compatibilidade.round()}%).'),
                  const Secao('Temas com divergência'),
                  if (r.divergencias.isEmpty) const Text('Nenhum eixo com divergência acentuada.'),
                  for (final e in r.divergencias)
                    Text('• ${e.eixo.nome}: há divergência — você tende a "${e.usuario < 50 ? e.eixo.poloA : e.eixo.poloB}", '
                        'e as posições públicas indicam "${e.candidato < 50 ? e.eixo.poloA : e.eixo.poloB}".'),
                  if (r.intermediarios.isNotEmpty) ...[
                    const Secao('Convergência parcial'),
                    Text(r.intermediarios.map((e) => e.eixo.nome).join(', ')),
                  ],
                  const SizedBox(height: 16),
                  AvisoBanner(texto: '${AppInfo.avisoCompatibilidade}\n\nBase da estimativa do político: ${c.baseEixos}'),
                  const SizedBox(height: 8),
                  const Center(child: BotaoComoAvaliamos()),
                ]);
              },
            ),
    );
  }
}
