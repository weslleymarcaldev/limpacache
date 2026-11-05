import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/conteudo.dart';
import '../state/app_state.dart';
import '../widgets/comum.dart';
import '../widgets/graficos.dart';

class GovernoScreen extends StatefulWidget {
  const GovernoScreen({super.key});
  @override
  State<GovernoScreen> createState() => _GovernoScreenState();
}

class _GovernoScreenState extends State<GovernoScreen> {
  String? _tema;
  String? _status;
  String? _categoria;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Análise do governo atual'), actions: const [BotaoComoAvaliamos(compacto: true)]),
      body: FutureView<(List<GovItem>, String?, String?)>(
        chaveRecarga: s.versaoDados,
        carregar: () async => (await s.conteudo.governo(), await s.conteudo.meta('titulo_governo'), await s.conteudo.meta('aviso_governo')),
        builder: (ctx, d) {
          final (itens, titulo, aviso) = d;
          final filtrados = itens.where((i) =>
              (_tema == null || i.tema == _tema) && (_status == null || i.status == _status) && (_categoria == null || i.categoria == _categoria)).toList();
          final promessas = itens.where((i) => i.categoria == 'promessa');
          final contagem = <String, int>{};
          for (final p in promessas) {
            contagem[p.status] = (contagem[p.status] ?? 0) + 1;
          }
          final porCategoria = <String, List<GovItem>>{};
          for (final i in filtrados) {
            porCategoria.putIfAbsent(i.categoria, () => []).add(i);
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text(titulo ?? 'Governo federal', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const AvisoBanner(texto: 'Esta seção apresenta fatos com fonte e data, sem juízo de valor. Os status indicam a situação verificável de cada item, não uma avaliação do governo.'),
            if (aviso != null) ...[const SizedBox(height: 8), Text(aviso, style: Theme.of(context).textTheme.bodySmall)],
            const Secao('Promessas por status'),
            Rosca(dados: contagem, rotulos: StatusGov.rotulos, cor: (k) => AppTheme.corStatus(cs, k)),
            const Secao('Filtros'),
            _filtro('Tema', TemasGov.rotulos, _tema, (v) => setState(() => _tema = v)),
            _filtro('Status', StatusGov.rotulos, _status, (v) => setState(() => _status = v)),
            _filtro('Tipo', CategoriaGov.rotulos, _categoria, (v) => setState(() => _categoria = v)),
            const SizedBox(height: 4),
            Text('${filtrados.length} itens', style: Theme.of(context).textTheme.labelLarge),
            for (final cat in CategoriaGov.rotulos.keys)
              if (porCategoria[cat] != null) ...[
                Secao(CategoriaGov.rotulos[cat]!),
                for (final i in porCategoria[cat]!) _CartaoGov(i),
              ],
            const SizedBox(height: 12),
            const Center(child: BotaoComoAvaliamos()),
          ]);
        },
      ),
    );
  }

  Widget _filtro(String rotulo, Map<String, String> opcoes, String? atual, ValueChanged<String?> set) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            SizedBox(width: 56, child: Text(rotulo, style: const TextStyle(fontWeight: FontWeight.w600))),
            ChoiceChip(label: const Text('Todos'), selected: atual == null, onSelected: (_) => set(null)),
            for (final e in opcoes.entries)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(label: Text(e.value), selected: atual == e.key, onSelected: (sel) => set(sel ? e.key : null)),
              ),
          ]),
        ),
      );
}

class _CartaoGov extends StatelessWidget {
  final GovItem i;
  const _CartaoGov(this.i);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cor = AppTheme.corStatus(cs, i.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(AppTheme.iconeStatus(i.status), color: cor),
          title: Text(i.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(border: Border.all(color: cor), borderRadius: BorderRadius.circular(8)),
                child: Text(StatusGov.rotulos[i.status] ?? i.status, style: TextStyle(fontSize: 12, color: cor, fontWeight: FontWeight.w600)),
              ),
              Text('${TemasGov.rotulos[i.tema] ?? i.tema} · ${i.data}', style: const TextStyle(fontSize: 12)),
              if (i.emRevisao) const ChipRevisao(),
            ]),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(i.descricao, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 8),
            Text('Impacto / resultado', style: Theme.of(context).textTheme.labelLarge),
            Text(i.impacto, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 6),
            FonteLink(fonte: i.fonte, url: i.url, data: i.data),
            NotaRevisao(tipo: 'governo_item', id: i.id),
            Align(alignment: Alignment.centerRight,
                child: BotaoReportar(tipo: 'governo_item', id: i.id, trecho: '${i.titulo}\n${i.descricao}')),
          ],
        ),
      ),
    );
  }
}
