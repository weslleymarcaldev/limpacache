import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../state/app_state.dart';
import '../widgets/comum.dart';
import 'como_avaliamos_screen.dart';
import 'governo_screen.dart';
import 'login_screen.dart';
import 'termos_screen.dart';

class ConfiguracoesScreen extends StatelessWidget {
  const ConfiguracoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    void abrir(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 0), child: Secao('Conta')),
        ListTile(
          leading: CircleAvatar(child: Icon(s.usuario.visitante ? Icons.person_outline : Icons.account_circle)),
          title: Text(s.usuario.nome),
          subtitle: Text(s.usuario.visitante ? 'Modo visitante · dados salvos neste aparelho' : (s.usuario.email ?? 'Conta Google')),
        ),
        if (s.usuario.visitante)
          ListTile(leading: const Icon(Icons.login), title: const Text('Entrar com Google'),
              onTap: () => abrir(const LoginScreen(voltarAoFinal: true)))
        else
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair da conta'),
            onTap: () async {
              await s.sair();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
              }
            },
          ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Secao('Aparência')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Sistema'), icon: Icon(Icons.brightness_auto)),
              ButtonSegment(value: ThemeMode.light, label: Text('Claro'), icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Escuro'), icon: Icon(Icons.dark_mode_outlined)),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => s.definirTema(v.first),
          ),
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Secao('Análise de correções por IA')),
        ListTile(
          leading: const Icon(Icons.smart_toy_outlined),
          title: const Text('Configurar API do Claude'),
          subtitle: Text(s.rotuloIa),
          onTap: () => _dialogIa(context, s),
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Secao('Informações')),
        ListTile(leading: const Icon(Icons.help_outline), title: const Text('Como avaliamos'), onTap: () => abrir(const ComoAvaliamosScreen())),
        ListTile(leading: const Icon(Icons.account_balance_outlined), title: const Text('Análise do governo atual'), onTap: () => abrir(const GovernoScreen())),
        ListTile(leading: const Icon(Icons.description_outlined), title: const Text('Termos de uso e privacidade'), onTap: () => abrir(const TermosScreen())),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Recarregar conteúdo do app'),
          subtitle: const Text('Restaura testes, quiz, candidatos e governo a partir dos dados empacotados'),
          onTap: () async {
            await s.recarregarConteudo();
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conteúdo recarregado.')));
          },
        ),
        ListTile(
          leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
          title: const Text('Apagar meus dados'),
          subtitle: const Text('Remove respostas, resultados, perfil, pontuações e reportes deste usuário'),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Apagar todos os seus dados?'),
                content: const Text('Esta ação não pode ser desfeita.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar')),
                ],
              ),
            );
            if (ok == true) {
              await s.apagarMeusDados();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados apagados.')));
            }
          },
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: AvisoBanner(),
        ),
        Center(child: Text('${AppInfo.nome} ${AppInfo.versao}', style: Theme.of(context).textTheme.bodySmall)),
        const SizedBox(height: 24),
      ]),
    );
  }

  Future<void> _dialogIa(BuildContext context, AppState s) async {
    final chave = TextEditingController(text: s.settings.apiKeyIa == AppInfo.anthropicApiKeyBuild ? '' : s.settings.apiKeyIa);
    final modelo = TextEditingController(text: s.settings.modeloIa);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API do Claude (Anthropic)'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('A chave é guardada apenas neste aparelho. Para distribuição pública, use um servidor intermediário (veja o README) em vez de chaves no app. '
                'Sem chave, o app usa a triagem local e encaminha os reportes para revisão humana.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(controller: chave, obscureText: true, decoration: const InputDecoration(labelText: 'Chave da API (sk-ant-...)')),
            const SizedBox(height: 12),
            TextField(controller: modelo, decoration: const InputDecoration(labelText: 'Modelo')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              s.settings.apiKeyIa = chave.text;
              s.settings.modeloIa = modelo.text;
              s.recarregarSinalizacoes();
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
