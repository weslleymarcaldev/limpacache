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

// ---------------------------------------------------------------- Introdução
class TesteIntroScreen extends StatelessWidget {
  final TesteModel teste;
  const TesteIntroScreen({super.key, required this.teste});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final temas = teste.perguntas.map((p) => p.tema).whereType<String>().toSet().toList();
    return Scaffold(
      appBar: AppBar(title: Text(teste.titulo)),
      body: FutureView<(Map<String, String>, List<ResultadoTeste>)>(
        carregar: () async => (await s.testes.rascunho(s.usuario.id, teste.id), await s.testes.resultados(s.usuario.id, testeId: teste.id)),
        builder: (ctx, d) {
          final (rasc, hist) = d;
          return ListView(padding: const EdgeInsets.all(20), children: [
            Center(child: CircleAvatar(radius: 40, backgroundColor: cs.primaryContainer, child: Icon(AppTheme.iconeTeste(teste.icone), size: 40, color: cs.onPrimaryContainer))),
            const SizedBox(height: 16),
            Text(teste.descricao, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(teste.explicacao, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 12),
            Text('${teste.perguntas.length} perguntas · cerca de ${teste.tempoMin} minutos', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final t in temas) Chip(label: Text(t), visualDensity: VisualDensity.compact)]),
            const SizedBox(height: 16),
            const AvisoBanner(texto: 'Não existe resposta certa ou errada. Suas respostas são salvas automaticamente, e você pode revisá-las antes de finalizar.'),
            const SizedBox(height: 24),
            if (rasc.isNotEmpty) ...[
              FilledButton.icon(
                onPressed: () => _abrir(context, rasc),
                icon: const Icon(Icons.play_arrow),
                label: Text('Continuar (${rasc.length}/${teste.perguntas.length} respondidas)'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () async {
                  await s.testes.descartarRascunho(s.usuario.id, teste.id);
                  if (context.mounted) _abrir(context, {});
                },
                child: const Text('Recomeçar do zero'),
              ),
            ] else
              FilledButton.icon(onPressed: () => _abrir(context, {}), icon: const Icon(Icons.play_arrow),
                  label: Text(hist.isEmpty ? 'Começar teste' : 'Refazer teste')),
            if (hist.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HistoricoTesteScreen(teste: teste))),
                icon: const Icon(Icons.history),
                label: Text('Ver tentativas anteriores (${hist.length})'),
              ),
            ],
          ]);
        },
      ),
    );
  }

  void _abrir(BuildContext context, Map<String, String> respostas) => Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TesteRunScreen(teste: teste, respostasIniciais: respostas)));
}

// ---------------------------------------------------------------- Execução
class TesteRunScreen extends StatefulWidget {
  final TesteModel teste;
  final Map<String, String> respostasIniciais;
  const TesteRunScreen({super.key, required this.teste, required this.respostasIniciais});
  @override
  State<TesteRunScreen> createState() => _TesteRunScreenState();
}

class _TesteRunScreenState extends State<TesteRunScreen> {
  late final Map<String, String> _resp = Map.of(widget.respostasIniciais);
  late int _i;

  @override
  void initState() {
    super.initState();
    final idx = widget.teste.perguntas.indexWhere((p) => !_resp.containsKey(p.id));
    _i = idx < 0 ? widget.teste.perguntas.length - 1 : idx;
  }

  Future<void> _responder(Pergunta p, String letra) async {
    setState(() => _resp[p.id] = letra);
    final s = context.read<AppState>();
    try {
      await s.testes.salvarResposta(s.usuario.id, widget.teste.id, p.id, letra);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível salvar a resposta automaticamente.')));
      }
    }
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    if (_i < widget.teste.perguntas.length - 1) {
      setState(() => _i++);
    } else {
      _revisar();
    }
  }

  void _revisar() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RevisaoScreen(teste: widget.teste, respostas: _resp, irPara: (i) => setState(() => _i = i))));

  @override
  Widget build(BuildContext context) {
    final t = widget.teste;
    final p = t.perguntas[_i];
    final cs = Theme.of(context).colorScheme;
    final progresso = _resp.length / t.perguntas.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.titulo),
        actions: [TextButton(onPressed: _resp.isEmpty ? null : _revisar, child: const Text('Revisar'))],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Semantics(
              label: 'Progresso: ${_resp.length} de ${t.perguntas.length} perguntas respondidas',
              child: Row(children: [
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progresso, minHeight: 8))),
                const SizedBox(width: 10),
                Text('${_i + 1}/${t.perguntas.length}'),
              ]),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (p.tema != null) Text(p.tema!.toUpperCase(), style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, letterSpacing: .8, fontSize: 12)),
          const SizedBox(height: 8),
          Semantics(header: true, child: Text(p.texto, style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.3))),
          const SizedBox(height: 20),
          for (final a in p.alternativas)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Opcao(letra: a.letra, texto: a.texto, selecionada: _resp[p.id] == a.letra, onTap: () => _responder(p, a.letra)),
            ),
          const SizedBox(height: 8),
          Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, runSpacing: 8, children: [
            if (_i > 0) OutlinedButton.icon(onPressed: () => setState(() => _i--), icon: const Icon(Icons.arrow_back), label: const Text('Anterior')),
            if (_i < t.perguntas.length - 1 && _resp.containsKey(p.id))
              OutlinedButton.icon(onPressed: () => setState(() => _i++), icon: const Icon(Icons.arrow_forward), label: const Text('Próxima')),
            if (_resp.length == t.perguntas.length && _i == t.perguntas.length - 1)
              FilledButton(onPressed: _revisar, child: const Text('Revisar e finalizar')),
          ]),
          const SizedBox(height: 12),
          BotaoReportar(tipo: 'teste_pergunta', id: p.id, trecho: p.texto),
        ]),
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  final String letra;
  final String texto;
  final bool selecionada;
  final VoidCallback onTap;
  const _Opcao({required this.letra, required this.texto, required this.selecionada, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selecionada,
      label: 'Alternativa $letra: $texto',
      child: Material(
        color: selecionada ? cs.primaryContainer : cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: selecionada ? cs.primary : cs.outlineVariant, width: selecionada ? 2 : 1)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: ExcludeSemantics(
                child: Row(children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: selecionada ? cs.primary : cs.surfaceContainerHighest,
                    child: Text(letra, style: TextStyle(color: selecionada ? cs.onPrimary : cs.onSurface, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(texto, style: const TextStyle(fontSize: 16))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Revisão
class RevisaoScreen extends StatelessWidget {
  final TesteModel teste;
  final Map<String, String> respostas;
  final void Function(int) irPara;
  const RevisaoScreen({super.key, required this.teste, required this.respostas, required this.irPara});

  @override
  Widget build(BuildContext context) {
    final faltam = teste.perguntas.where((p) => !respostas.containsKey(p.id)).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar respostas')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: teste.perguntas.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Text(faltam == 0
                ? 'Todas as perguntas foram respondidas. Toque em uma pergunta para alterar a resposta.'
                : 'Faltam $faltam perguntas. Toque nelas para responder.');
          }
          final p = teste.perguntas[i - 1];
          final alt = p.alternativa(respostas[p.id]);
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('$i')),
              title: Text(p.texto),
              subtitle: Text(alt == null ? 'Sem resposta' : '${alt.letra}) ${alt.texto}',
                  style: TextStyle(color: alt == null ? Theme.of(context).colorScheme.error : null)),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () {
                irPara(i - 1);
                Navigator.of(context).pop();
              },
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: faltam > 0 ? null : () => _finalizar(context),
            icon: const Icon(Icons.check),
            label: Text(faltam > 0 ? 'Responda todas para finalizar' : 'Finalizar e ver resultado'),
          ),
        ),
      ),
    );
  }

  Future<void> _finalizar(BuildContext context) async {
    final s = context.read<AppState>();
    try {
      final defs = await s.eixos();
      final r = s.scoring.calcular(teste, respostas, defs);
      final id = await s.salvarResultado(r);
      if (!context.mounted) return;
      final salvo = ResultadoTeste(
        id: id, testeId: r.testeId, criadoEm: r.criadoEm, pontuacaoTotal: r.pontuacaoTotal,
        pontuacaoMin: r.pontuacaoMin, pontuacaoMax: r.pontuacaoMax, indiceGeral: r.indiceGeral,
        classificacao: r.classificacao, rotuloDescritivo: r.rotuloDescritivo, eixos: r.eixos, respostas: r.respostas, salvo: true,
      );
      Navigator.of(context)
        ..pop()
        ..pushReplacement(MaterialPageRoute(builder: (_) => ResultadoScreen(teste: teste, resultado: salvo, novo: true)));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível calcular o resultado. Tente novamente.')));
      }
    }
  }
}

// ---------------------------------------------------------------- Resultado
class ResultadoScreen extends StatefulWidget {
  final TesteModel teste;
  final ResultadoTeste resultado;
  final bool novo;
  const ResultadoScreen({super.key, required this.teste, required this.resultado, this.novo = false});
  @override
  State<ResultadoScreen> createState() => _ResultadoScreenState();
}

class _ResultadoScreenState extends State<ResultadoScreen> {
  final _cartaoKey = GlobalKey();

  String get _textoShare {
    final s = context.read<AppState>();
    return s.scoring.textoCompartilhamento(widget.resultado.rotuloDescritivo, titulo: widget.teste.titulo);
  }

  Future<void> _acao(Future<void> Function() f, String ok) async {
    try {
      await f();
      if (mounted && ok.isNotEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível concluir a ação.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final r = widget.resultado;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado'), actions: const [BotaoComoAvaliamos(compacto: true)]),
      body: FutureView<Map<String, Eixo>>(
        carregar: s.eixos,
        builder: (ctx, defs) {
          final analise = s.scoring.analisar(r.eixos, defs, teste: widget.teste, respostas: r.respostas);
          final ids = defs.keys.where(r.eixos.containsKey).toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (widget.novo)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: AvisoBanner(icone: Icons.check_circle_outline, texto: 'Resultado salvo no seu perfil. O Perfil Político Pessoal foi atualizado.'),
              ),
            RepaintBoundary(
              key: _cartaoKey,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Radar Político · ${widget.teste.titulo}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(r.rotuloDescritivo, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Pontuação total: ${r.pontuacaoTotal.toStringAsFixed(1)} (mín. ${r.pontuacaoMin.toStringAsFixed(0)} · máx. ${r.pontuacaoMax.toStringAsFixed(0)})',
                      style: const TextStyle(fontSize: 13)),
                  if (r.indiceGeral != null) Text('Índice geral: ${r.indiceGeral!.round()} de 100 (${r.classificacao})', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  if (ids.length >= 3) RadarEixos(eixos: {for (final i in ids) i: defs[i]!}, valores: {for (final i in ids) i: r.eixos[i]!.pct}),
                  for (var k = 0; k < ids.length; k++)
                    EixoBarra(
                      eixo: defs[ids[k]]!,
                      pct: r.eixos[ids[k]]!.pct,
                      cor: AppTheme.coresEixos[k % AppTheme.coresEixos.length],
                      legenda: '${s.scoring.faixaEixo(r.eixos[ids[k]]!.pct, defs[ids[k]]!).rotulo} · '
                          '${r.eixos[ids[k]]!.bruto.toStringAsFixed(1)} pts (${r.eixos[ids[k]]!.minimo.toStringAsFixed(0)}–${r.eixos[ids[k]]!.maximo.toStringAsFixed(0)})',
                    ),
                  const SizedBox(height: 8),
                  Text('Estimativa baseada nas respostas. Não representa apoio a partidos ou candidatos.',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ]),
              ),
            ),
            const Secao('Explicação do resultado'),
            Text(analise.explicacao, style: const TextStyle(height: 1.4)),
            if (widget.teste.rapido && (analise.aproximaA.isNotEmpty || analise.aproximaB.isNotEmpty)) ...[
              const Secao('O que aproxima você de cada lado'),
              if (analise.aproximaA.isNotEmpty) _Lista('Temas em que suas respostas se aproximam de posições associadas à esquerda', analise.aproximaA),
              if (analise.aproximaB.isNotEmpty) _Lista('Temas em que suas respostas se aproximam de posições associadas à direita', analise.aproximaB),
            ],
            const Secao('Pontos fortes do perfil'),
            for (final p in analise.pontosFortes) _Item(Icons.trending_flat, p),
            const Secao('Possíveis divergências internas'),
            if (analise.divergencias.isEmpty) const _Item(Icons.done_all, 'Suas respostas foram consistentes dentro de cada eixo.'),
            for (final p in analise.divergencias) _Item(Icons.compare_arrows, p),
            const SizedBox(height: 12),
            const AvisoBanner(texto: AppInfo.avisoEstimativa),
            const Secao('Salvar e compartilhar'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.tonalIcon(
                  onPressed: () => _acao(() => s.share.compartilharImagem(_cartaoKey, texto: _textoShare), ''),
                  icon: const Icon(Icons.image_outlined), label: const Text('Compartilhar imagem')),
              FilledButton.tonalIcon(
                  onPressed: () => _acao(() => s.share.compartilharTexto(_textoShare), ''),
                  icon: const Icon(Icons.share_outlined), label: const Text('Compartilhar texto')),
              FilledButton.tonalIcon(
                  onPressed: () => _acao(() => s.share.copiar(_textoShare), 'Resumo copiado.'),
                  icon: const Icon(Icons.copy), label: const Text('Copiar resumo')),
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HistoricoTesteScreen(teste: widget.teste))),
                icon: const Icon(Icons.history), label: const Text('Histórico de tentativas')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => TesteIntroScreen(teste: widget.teste))),
                icon: const Icon(Icons.replay), label: const Text('Refazer o teste')),
            const SizedBox(height: 8),
            const Center(child: BotaoComoAvaliamos()),
          ]);
        },
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icone;
  final String texto;
  const _Item(this.icone, this.texto);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(height: 1.35))),
        ]),
      );
}

class _Lista extends StatelessWidget {
  final String titulo;
  final List<String> itens;
  const _Lista(this.titulo, this.itens);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final i in itens) Chip(label: Text(i), visualDensity: VisualDensity.compact)]),
        ]),
      );
}

// ---------------------------------------------------------------- Histórico
class HistoricoTesteScreen extends StatelessWidget {
  final TesteModel teste;
  const HistoricoTesteScreen({super.key, required this.teste});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Tentativas anteriores')),
      body: FutureView<List<ResultadoTeste>>(
        chaveRecarga: s.versaoDados,
        carregar: () => s.testes.resultados(s.usuario.id, testeId: teste.id),
        builder: (ctx, lista) {
          if (lista.isEmpty) return const Center(child: Text('Nenhuma tentativa registrada.'));
          final cron = lista.reversed.toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text(teste.titulo, style: Theme.of(context).textTheme.titleMedium),
            if (cron.first.indiceGeral != null) ...[
              const Secao('Evolução do índice geral'),
              EvolucaoLinha(
                valores: cron.map((r) => r.indiceGeral ?? 50).toList(),
                rotulos: cron.map((r) => '${r.criadoEm.day}/${r.criadoEm.month}').toList(),
              ),
            ],
            const Secao('Tentativas'),
            for (final r in lista)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(r.rotuloDescritivo),
                  subtitle: Text(dataBr(r.criadoEm)),
                  trailing: IconButton(
                    tooltip: 'Excluir tentativa',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Excluir tentativa?'),
                          content: const Text('O Perfil Político Pessoal será recalculado.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
                          ],
                        ),
                      );
                      if (ok == true && r.id != null) {
                        await s.testes.excluirResultado(r.id!);
                        await s.recalcularPerfil();
                      }
                    },
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultadoScreen(teste: teste, resultado: r))),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
