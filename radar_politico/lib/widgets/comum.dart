import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../screens/como_avaliamos_screen.dart';
import '../screens/correcoes_screen.dart';
import '../state/app_state.dart';

class AvisoBanner extends StatelessWidget {
  final String texto;
  final IconData icone;
  const AvisoBanner({super.key, this.texto = AppInfo.avisoPermanente, this.icone = Icons.info_outline});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Aviso: $texto',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ExcludeSemantics(child: Icon(icone, size: 20, color: cs.onSecondaryContainer)),
          const SizedBox(width: 10),
          Expanded(child: ExcludeSemantics(child: Text(texto, style: TextStyle(color: cs.onSecondaryContainer, height: 1.35)))),
        ]),
      ),
    );
  }
}

class Secao extends StatelessWidget {
  final String titulo;
  final Widget? acao;
  const Secao(this.titulo, {super.key, this.acao});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Row(children: [
          Expanded(child: Semantics(header: true, child: Text(titulo, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)))),
          ?acao,
        ]),
      );
}

class ChipRevisao extends StatelessWidget {
  final String? nota;
  const ChipRevisao({super.key, this.nota});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: nota ?? 'Informação ainda não verificada com segurança em fonte primária.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(border: Border.all(color: cs.tertiary), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.manage_search, size: 14, color: cs.tertiary),
          const SizedBox(width: 4),
          Text('Informação em revisão', style: TextStyle(fontSize: 12, color: cs.tertiary, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class Carregando extends StatelessWidget {
  final String? texto;
  const Carregando({super.key, this.texto});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          if (texto != null) ...[const SizedBox(height: 16), Text(texto!)],
        ]),
      );
}

class ErroView extends StatelessWidget {
  final String mensagem;
  final VoidCallback? tentarNovamente;
  const ErroView(this.mensagem, {super.key, this.tentarNovamente});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(mensagem, textAlign: TextAlign.center),
            if (tentarNovamente != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: tentarNovamente, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
            ],
          ]),
        ),
      );
}

/// Executa uma tarefa assíncrona da tela mostrando carregamento e erro amigável.
class FutureView<T> extends StatefulWidget {
  final Future<T> Function() carregar;
  final Widget Function(BuildContext, T) builder;
  final Object? chaveRecarga;
  const FutureView({super.key, required this.carregar, required this.builder, this.chaveRecarga});
  @override
  State<FutureView<T>> createState() => _FutureViewState<T>();
}

class _FutureViewState<T> extends State<FutureView<T>> {
  late Future<T> _f;
  @override
  void initState() {
    super.initState();
    _f = widget.carregar();
  }

  @override
  void didUpdateWidget(covariant FutureView<T> old) {
    super.didUpdateWidget(old);
    if (old.chaveRecarga != widget.chaveRecarga) _f = widget.carregar();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _f,
        builder: (ctx, s) {
          if (s.hasError) {
            return ErroView('Algo deu errado ao carregar estas informações. Tente novamente.',
                tentarNovamente: () => setState(() => _f = widget.carregar()));
          }
          if (!s.hasData) return const Carregando();
          return widget.builder(ctx, s.data as T);
        },
      );
}

Future<void> abrirLink(BuildContext context, String? url) async {
  if (url == null || url.isEmpty) return;
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o link.')));
  }
}

class FonteLink extends StatelessWidget {
  final String fonte;
  final String? url;
  final String? data;
  const FonteLink({super.key, required this.fonte, this.url, this.data});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = 'Fonte: $fonte${data != null && data!.isNotEmpty ? ' · $data' : ''}';
    return InkWell(
      onTap: url == null ? null : () => abrirLink(context, url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(url == null ? Icons.description_outlined : Icons.open_in_new, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(txt, style: TextStyle(fontSize: 13, color: cs.primary, decoration: url == null ? null : TextDecoration.underline))),
        ]),
      ),
    );
  }
}

class BotaoComoAvaliamos extends StatelessWidget {
  final bool compacto;
  const BotaoComoAvaliamos({super.key, this.compacto = false});
  @override
  Widget build(BuildContext context) {
    void abrir() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ComoAvaliamosScreen()));
    if (compacto) {
      return IconButton(tooltip: 'Como avaliamos', icon: const Icon(Icons.help_outline), onPressed: abrir);
    }
    return TextButton.icon(onPressed: abrir, icon: const Icon(Icons.help_outline), label: const Text('Como avaliamos'));
  }
}

class BotaoReportar extends StatelessWidget {
  final String tipo;
  final String id;
  final String trecho;
  final bool icone;
  const BotaoReportar({super.key, required this.tipo, required this.id, required this.trecho, this.icone = false});

  void _abrir(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReportarCorrecaoScreen(conteudoTipo: tipo, conteudoId: id, trechoInicial: trecho)));

  @override
  Widget build(BuildContext context) {
    if (icone) {
      return IconButton(tooltip: 'Reportar correção', icon: const Icon(Icons.flag_outlined), onPressed: () => _abrir(context));
    }
    return TextButton.icon(
        onPressed: () => _abrir(context), icon: const Icon(Icons.flag_outlined, size: 18), label: const Text('Reportar correção'));
  }
}

/// Mostra a nota de revisão local (quando uma correção foi validada ou encaminhada).
class NotaRevisao extends StatelessWidget {
  final String tipo;
  final String id;
  const NotaRevisao({super.key, required this.tipo, required this.id});
  @override
  Widget build(BuildContext context) {
    final nota = context.select<AppState, String?>((s) => s.notaRevisao(tipo, id));
    if (nota == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: cs.tertiaryContainer.withValues(alpha: .5), borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.manage_search, size: 18, color: cs.onTertiaryContainer),
        const SizedBox(width: 8),
        Expanded(child: Text(nota, style: TextStyle(fontSize: 13, color: cs.onTertiaryContainer))),
      ]),
    );
  }
}

String dataBr(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
