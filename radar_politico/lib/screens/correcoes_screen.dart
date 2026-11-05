import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/conteudo.dart';
import '../services/ai_correction_service.dart';
import '../state/app_state.dart';
import '../widgets/comum.dart';

class CorrecoesScreen extends StatelessWidget {
  const CorrecoesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Correções e revisões'), actions: const [BotaoComoAvaliamos(compacto: true)]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const ReportarCorrecaoScreen(conteudoTipo: 'texto_app', conteudoId: 'geral', trechoInicial: ''))),
        icon: const Icon(Icons.add),
        label: const Text('Nova correção'),
      ),
      body: FutureView<(List<Correcao>, List<Map<String, Object?>>)>(
        chaveRecarga: s.versaoDados,
        carregar: () async => (await s.correcoes.listar(s.usuario.id), await s.correcoes.historico()),
        builder: (ctx, d) {
          final (lista, hist) = d;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
            Text('Viu algum erro, dado desatualizado ou trecho ambíguo? Toque em "Reportar correção" no próprio conteúdo ou use o botão abaixo. '
                'Cada reporte é analisado (${s.rotuloIa}) e classificado com transparência.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const Secao('Meus reportes'),
            if (lista.isEmpty) const Text('Você ainda não enviou reportes.'),
            for (final c in lista) _CartaoCorrecao(c),
            const Secao('Histórico de alterações e sinalizações'),
            if (hist.isEmpty) const Text('Nenhuma alteração registrada neste aparelho.'),
            for (final h in hist)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_note),
                title: Text('${h['conteudo_tipo']} · ${h['conteudo_id']}'),
                subtitle: Text('${h['descricao']}\n${dataBr(DateTime.parse(h['criado_em'] as String))}'),
                isThreeLine: true,
              ),
          ]);
        },
      ),
    );
  }
}

class _CartaoCorrecao extends StatelessWidget {
  final Correcao c;
  const _CartaoCorrecao(this.c);
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ExpansionTile(
          leading: Icon(c.status == ClassificacaoCorrecao.valida ? Icons.verified_outlined : Icons.flag_outlined),
          title: Text(ClassificacaoCorrecao.rotulos[c.status] ?? c.status, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${c.motivo}\n${dataBr(c.criadoEm)}${c.viaIa ? ' · analisado por IA' : ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.trecho.isNotEmpty) Text('Trecho: ${c.trecho}', style: const TextStyle(fontStyle: FontStyle.italic)),
            if (c.fonteUsuario.isNotEmpty) Text('Fonte informada: ${c.fonteUsuario}'),
            const SizedBox(height: 8),
            if (c.respostaUsuario != null) Text(c.respostaUsuario!),
            if (c.justificativa != null && c.justificativa!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Justificativa: ${c.justificativa}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      );
}

class ReportarCorrecaoScreen extends StatefulWidget {
  final String conteudoTipo;
  final String conteudoId;
  final String trechoInicial;
  const ReportarCorrecaoScreen({super.key, required this.conteudoTipo, required this.conteudoId, required this.trechoInicial});
  @override
  State<ReportarCorrecaoScreen> createState() => _ReportarCorrecaoScreenState();
}

class _ReportarCorrecaoScreenState extends State<ReportarCorrecaoScreen> {
  final _form = GlobalKey<FormState>();
  late final _trecho = TextEditingController(text: widget.trechoInicial);
  final _motivo = TextEditingController();
  final _fonte = TextEditingController();
  String _tipoMotivo = 'Erro factual';
  bool _enviando = false;
  bool _tentouEnviar = false;

  static const _tipos = ['Erro factual', 'Informação desatualizada', 'Texto ambíguo', 'Possível viés na redação', 'Fonte ausente ou incorreta', 'Outro'];

  Future<void> _enviar() async {
    setState(() => _tentouEnviar = true);
    if (!_form.currentState!.validate()) return;
    setState(() => _enviando = true);
    final s = context.read<AppState>();
    final motivo = '[$_tipoMotivo] ${_motivo.text.trim()}';
    try {
      final id = await s.correcoes.criar(
          s.usuario.id,
          Correcao(
            conteudoTipo: widget.conteudoTipo, conteudoId: widget.conteudoId, trecho: _trecho.text.trim(), motivo: motivo,
            fonteUsuario: _fonte.text.trim(), status: ClassificacaoCorrecao.pendente, criadoEm: DateTime.now(),
          ));
      final pedido = PedidoCorrecao(conteudoTipo: widget.conteudoTipo, conteudoId: widget.conteudoId,
          trecho: _trecho.text.trim(), motivo: motivo, fonte: _fonte.text.trim());
      final a = await s.ia.analisar(pedido, apiKey: s.settings.apiKeyIa, modelo: s.settings.modeloIa);

      var resposta = a.respostaUsuario;
      final hoje = DateTime.now();
      final dataTxt = '${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}';
      if (a.classificacao == ClassificacaoCorrecao.valida) {
        resposta = 'Obrigado pela contribuição. Após análise, identificamos que sua observação procede e o conteúdo foi corrigido/atualizado.\n\n${a.respostaUsuario}';
        await s.correcoes.sinalizar(widget.conteudoTipo, widget.conteudoId,
            'Correção validada em $dataTxt: ${a.justificativa}${a.sugestaoTexto.isNotEmpty ? '\nTexto atualizado: ${a.sugestaoTexto}' : ''}',
            correcaoId: id);
      } else if (a.classificacao == ClassificacaoCorrecao.pendente ||
          (a.classificacao == ClassificacaoCorrecao.maisInfo && a.tipoProblema != 'nenhum')) {
        await s.correcoes.sinalizar(widget.conteudoTipo, widget.conteudoId,
            'Em revisão desde $dataTxt: um usuário apontou possível ${_tipoMotivo.toLowerCase()}.', correcaoId: id);
      }
      await s.correcoes.atualizarAnalise(id,
          status: a.classificacao, classificacao: a.classificacao, resposta: resposta, justificativa: a.justificativa,
          analise: a.toJson(), viaIa: a.viaIa);
      await s.recarregarSinalizacoes();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          icon: Icon(a.classificacao == ClassificacaoCorrecao.valida ? Icons.verified_outlined : Icons.mark_email_read_outlined),
          title: Text(ClassificacaoCorrecao.rotulos[a.classificacao] ?? 'Recebido'),
          content: SingleChildScrollView(child: Text(resposta)),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi'))],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível enviar agora. Seu texto foi mantido; tente novamente.')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar correção')),
      body: Form(
        key: _form,
        autovalidateMode: _tentouEnviar ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const AvisoBanner(texto: 'Correções são avaliadas por critérios factuais. Nenhuma alteração é feita para favorecer ou prejudicar partidos, candidatos, governos ou ideologias.'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _trecho,
            minLines: 2, maxLines: 6,
            decoration: const InputDecoration(labelText: 'Trecho ou conteúdo com possível erro *'),
            validator: (v) => (v ?? '').trim().length < 5 ? 'Descreva ou cole o trecho (mínimo 5 caracteres).' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _tipoMotivo,
            decoration: const InputDecoration(labelText: 'Tipo de problema'),
            items: [for (final t in _tipos) DropdownMenuItem(value: t, child: Text(t))],
            onChanged: (v) => setState(() => _tipoMotivo = v ?? _tipoMotivo),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _motivo,
            minLines: 3, maxLines: 8, maxLength: 1500,
            decoration: const InputDecoration(labelText: 'Motivo da correção *', hintText: 'Explique o que está incorreto e qual seria a informação correta.'),
            validator: (v) => (v ?? '').trim().length < 15 ? 'Explique o motivo com pelo menos 15 caracteres.' : null,
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _fonte,
            minLines: 1, maxLines: 4,
            decoration: const InputDecoration(labelText: 'Fonte, link ou explicação', hintText: 'Ex.: link do Planalto, número da lei, dado do IBGE'),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.startsWith('http') && Uri.tryParse(t)?.hasAuthority != true) return 'O link parece inválido.';
              return null;
            },
          ),
          const SizedBox(height: 8),
          Text('Análise: ${s.rotuloIa}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _enviando ? null : _enviar,
            icon: _enviando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
            label: Text(_enviando ? 'Analisando...' : 'Enviar para análise'),
          ),
        ]),
      ),
    );
  }
}
