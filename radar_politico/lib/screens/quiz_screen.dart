import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/conteudo.dart';
import '../state/app_state.dart';
import '../widgets/comum.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  String _nivel = 'facil';
  String? _tema;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz de conhecimento político')),
      body: FutureView<(List<Map<String, Object?>>, Map<String, int>, List<Map<String, Object?>>, List<Map<String, Object?>>, int)>(
        chaveRecarga: s.versaoDados,
        carregar: () async => (
          await s.conteudo.quizzes(),
          await s.conteudo.estatisticasQuiz(s.usuario.id),
          await s.conteudo.ranking(),
          await s.conteudo.historicoQuiz(s.usuario.id, limite: 5),
          await s.conteudo.totalPerguntasQuiz(),
        ),
        builder: (ctx, d) {
          final (temas, est, ranking, hist, total) = d;
          final cs = Theme.of(context).colorScheme;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('Perguntas factuais e educativas sobre instituições, eleições, Constituição e história política. $total perguntas disponíveis offline.',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(children: [
              _Stat('Melhor pontuação', '${est['melhor']}'),
              _Stat('Maior sequência', '${est['sequencia']}'),
              _Stat('Aproveitamento', est['respondidas'] == 0 ? '—' : '${(est['acertos']! * 100 / est['respondidas']!).round()}%'),
            ]),
            const Secao('Nível'),
            SegmentedButton<String>(
              segments: [for (final e in QuizPergunta.niveis.entries) ButtonSegment(value: e.key, label: Text(e.value))],
              selected: {_nivel},
              onSelectionChanged: (v) => setState(() => _nivel = v.first),
            ),
            const Secao('Tema'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              ChoiceChip(label: const Text('Todos os temas'), selected: _tema == null, onSelected: (_) => setState(() => _tema = null)),
              for (final t in temas)
                ChoiceChip(label: Text(t['titulo'] as String), selected: _tema == t['id'], onSelected: (sel) => setState(() => _tema = sel ? t['id'] as String : null)),
            ]),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                var ps = await s.conteudo.perguntasQuiz(nivel: _nivel, tema: _tema);
                if (ps.length < 5) ps = await s.conteudo.perguntasQuiz(tema: _tema);
                if (!context.mounted) return;
                if (ps.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não há perguntas para esta combinação.')));
                  return;
                }
                ps.shuffle(Random());
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => QuizPlayScreen(perguntas: ps.take(10).toList(), nivel: _nivel, tema: _tema)));
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Começar rodada (10 perguntas)'),
            ),
            const Secao('Ranking local (este aparelho)'),
            if (ranking.isEmpty) const Text('Nenhuma pontuação registrada ainda.'),
            for (var i = 0; i < ranking.length; i++)
              ListTile(
                dense: true,
                leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                title: Text('${ranking[i]['nome_jogador']}'),
                subtitle: Text('${QuizPergunta.niveis[ranking[i]['nivel']] ?? ''} · ${ranking[i]['acertos']}/${ranking[i]['total']} acertos'),
                trailing: Text('${ranking[i]['pontos']} pts', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            if (hist.isNotEmpty) ...[
              const Secao('Seu histórico recente'),
              for (final h in hist)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.history),
                  title: Text('${h['pontos']} pontos · ${h['acertos']}/${h['total']}'),
                  subtitle: Text('${QuizPergunta.niveis[h['nivel']] ?? ''}${h['tema'] != null ? ' · ${h['tema']}' : ''} · ${dataBr(DateTime.parse(h['criado_em'] as String))}'),
                ),
            ],
          ]);
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String rotulo;
  final String valor;
  const _Stat(this.rotulo, this.valor);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(children: [
              Text(valor, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(rotulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
            ]),
          ),
        ),
      );
}

class QuizPlayScreen extends StatefulWidget {
  final List<QuizPergunta> perguntas;
  final String nivel;
  final String? tema;
  const QuizPlayScreen({super.key, required this.perguntas, required this.nivel, this.tema});
  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  final _partida = DateTime.now().microsecondsSinceEpoch.toString();
  int _i = 0;
  int? _escolha;
  int _pontos = 0;
  int _acertos = 0;
  int _seq = 0;
  int _melhorSeq = 0;

  QuizPergunta get _p => widget.perguntas[_i];

  Future<void> _responder(int idx) async {
    if (_escolha != null) return;
    final certo = idx == _p.correta;
    setState(() {
      _escolha = idx;
      if (certo) {
        _acertos++;
        _seq++;
        _melhorSeq = max(_melhorSeq, _seq);
        final base = QuizPergunta.pontosPorNivel[_p.nivel] ?? 10;
        _pontos += base + (_seq >= 3 ? 5 * (_seq - 2) : 0); // bônus por sequência
      } else {
        _seq = 0;
      }
    });
    final s = context.read<AppState>();
    await s.conteudo.registrarRespostaQuiz(s.usuario.id, _partida, _p.id, idx, certo);
  }

  void _proxima() {
    if (_i < widget.perguntas.length - 1) {
      setState(() {
        _i++;
        _escolha = null;
      });
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => QuizResultadoScreen(
              partida: _partida, pontos: _pontos, acertos: _acertos, total: widget.perguntas.length,
              melhorSeq: _melhorSeq, nivel: widget.nivel, tema: widget.tema)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = _p;
    return Scaffold(
      appBar: AppBar(
        title: Text('Pergunta ${_i + 1} de ${widget.perguntas.length}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(value: (_i + (_escolha == null ? 0 : 1)) / widget.perguntas.length),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          Chip(label: Text(QuizPergunta.niveis[p.nivel] ?? p.nivel), visualDensity: VisualDensity.compact),
          const SizedBox(width: 6),
          Expanded(child: Text(p.tema, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12), overflow: TextOverflow.ellipsis)),
          Semantics(label: '$_pontos pontos, sequência de $_seq acertos',
              child: Text('$_pontos pts · 🔥$_seq', style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        Semantics(header: true, child: Text(p.pergunta, style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.3))),
        const SizedBox(height: 20),
        for (var k = 0; k < p.alternativas.length; k++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Alternativa(
              texto: p.alternativas[k],
              letra: 'ABCD'[k],
              estado: _escolha == null
                  ? 0
                  : k == p.correta
                      ? 1
                      : k == _escolha
                          ? 2
                          : 0,
              onTap: () => _responder(k),
            ),
          ),
        if (_escolha != null) ...[
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_escolha == p.correta ? 'Resposta correta!' : 'Resposta incorreta. A correta é a alternativa ${'ABCD'[p.correta]}.',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 6),
                Text(p.explicacao, style: const TextStyle(height: 1.4)),
                const SizedBox(height: 6),
                Text('Base: ${p.fonte}', style: TextStyle(fontSize: 13, color: cs.primary)),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerLeft,
              child: BotaoReportar(tipo: 'quiz_pergunta', id: p.id, trecho: '${p.pergunta}\nResposta: ${p.alternativas[p.correta]}\n${p.explicacao}')),
          FilledButton(onPressed: _proxima, child: Text(_i < widget.perguntas.length - 1 ? 'Próxima pergunta' : 'Ver resultado')),
        ],
      ]),
    );
  }
}

class _Alternativa extends StatelessWidget {
  final String texto;
  final String letra;
  final int estado; // 0 neutro, 1 correta, 2 errada escolhida
  final VoidCallback onTap;
  const _Alternativa({required this.texto, required this.letra, required this.estado, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borda = estado == 1 ? cs.primary : estado == 2 ? cs.error : cs.outlineVariant;
    final icone = estado == 1 ? Icons.check_circle : estado == 2 ? Icons.cancel : null;
    return Semantics(
      button: true,
      label: 'Alternativa $letra: $texto${estado == 1 ? ', correta' : estado == 2 ? ', incorreta' : ''}',
      child: Material(
        color: estado == 1 ? cs.primaryContainer : estado == 2 ? cs.errorContainer : cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: borda, width: estado == 0 ? 1 : 2)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: ExcludeSemantics(
              child: Row(children: [
                Text('$letra)', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                Expanded(child: Text(texto, style: const TextStyle(fontSize: 16))),
                if (icone != null) Icon(icone, color: borda),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class QuizResultadoScreen extends StatefulWidget {
  final String partida;
  final int pontos, acertos, total, melhorSeq;
  final String nivel;
  final String? tema;
  const QuizResultadoScreen({super.key, required this.partida, required this.pontos, required this.acertos, required this.total,
      required this.melhorSeq, required this.nivel, this.tema});
  @override
  State<QuizResultadoScreen> createState() => _QuizResultadoScreenState();
}

class _QuizResultadoScreenState extends State<QuizResultadoScreen> {
  late final TextEditingController _nome;
  final _form = GlobalKey<FormState>();
  bool _salvo = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _nome = TextEditingController(text: s.settings.nomeJogador.isNotEmpty ? s.settings.nomeJogador : (s.usuario.visitante ? '' : s.usuario.nome.split(' ').first));
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    final s = context.read<AppState>();
    s.settings.nomeJogador = _nome.text.trim();
    await s.conteudo.salvarPontuacao(
      usuarioId: s.usuario.id, partidaId: widget.partida, nome: _nome.text.trim(), nivel: widget.nivel, tema: widget.tema,
      pontos: widget.pontos, acertos: widget.acertos, total: widget.total, melhorSequencia: widget.melhorSeq,
    );
    s.recarregarSinalizacoes(); // dispara atualização das telas
    if (mounted) setState(() => _salvo = true);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final texto = 'Fiz ${widget.pontos} pontos (${widget.acertos}/${widget.total} acertos) no quiz de conhecimento político do Radar Político.';
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado do quiz')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Icon(Icons.emoji_events_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text('${widget.pontos} pontos', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        Text('${widget.acertos} de ${widget.total} acertos · maior sequência: ${widget.melhorSeq}', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Form(
          key: _form,
          child: TextFormField(
            controller: _nome,
            enabled: !_salvo,
            maxLength: 20,
            decoration: const InputDecoration(labelText: 'Nome para o ranking local'),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.length < 2) return 'Informe ao menos 2 caracteres.';
              if (RegExp(r'[<>{}]').hasMatch(t)) return 'Use apenas letras, números e espaços.';
              return null;
            },
          ),
        ),
        FilledButton.icon(onPressed: _salvo ? null : _salvar, icon: const Icon(Icons.save_outlined),
            label: Text(_salvo ? 'Pontuação salva' : 'Salvar no ranking')),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () => s.share.compartilharTexto(texto), icon: const Icon(Icons.share_outlined), label: const Text('Compartilhar')),
        const SizedBox(height: 10),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Voltar ao quiz')),
      ]),
    );
  }
}
