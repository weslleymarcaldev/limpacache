import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../data/database.dart';
import '../data/seed_service.dart';
import '../models/conteudo.dart';
import '../models/eixo.dart';
import '../models/resultado.dart';
import '../repositories/conteudo_repository.dart';
import '../repositories/correcao_repository.dart';
import '../repositories/perfil_repository.dart';
import '../repositories/teste_repository.dart';
import '../repositories/usuario_repository.dart';
import '../services/ai_correction_service.dart';
import '../services/auth_service.dart';
import '../services/scoring_service.dart';
import '../services/settings_service.dart';
import '../services/share_service.dart';

/// Estado global e acesso aos repositórios/serviços (injeção simples via Provider).
class AppState extends ChangeNotifier {
  final AppDatabase database = AppDatabase();
  final SettingsService settings = SettingsService();
  final AuthService auth = AuthService();
  final ShareService share = ShareService();
  final AiCorrectionService ia = AiCorrectionService();
  final ScoringService scoring = const ScoringService();

  late final TesteRepository testes = TesteRepository(database);
  late final PerfilRepository perfis = PerfilRepository(database);
  late final ConteudoRepository conteudo = ConteudoRepository(database);
  late final CorrecaoRepository correcoes = CorrecaoRepository(database);
  late final UsuarioRepository usuarios = UsuarioRepository(database);

  bool pronto = false;
  String? erroInicializacao;
  Usuario usuario = Usuario.convidado;
  ThemeMode themeMode = ThemeMode.system;
  PerfilSalvo? perfil;
  Map<String, String> sinalizacoes = {};

  /// Incrementado quando resultados mudam, para telas recarregarem.
  int versaoDados = 0;

  Future<void> inicializar() async {
    try {
      await settings.init();
      themeMode = settings.themeMode;
      await SeedService(database).carregarSeNecessario();
      final uid = settings.usuarioAtual;
      if (uid != null) {
        usuario = await usuarios.buscar(uid) ?? Usuario.convidado;
      }
      await usuarios.salvar(usuario);
      perfil = await perfis.carregar(usuario.id);
      sinalizacoes = await correcoes.sinalizacoes();
      pronto = true;
      erroInicializacao = null;
    } catch (e) {
      erroInicializacao = 'Não foi possível preparar os dados do aplicativo. ($e)';
    }
    notifyListeners();
  }

  bool get precisaOnboarding => !settings.onboardingConcluido || settings.termosAceitosEm == null;
  bool get logadoOuVisitanteEscolhido => settings.usuarioAtual != null;

  void concluirOnboarding() {
    settings.onboardingConcluido = true;
    settings.termosAceitosEm = DateTime.now().toIso8601String();
    notifyListeners();
  }

  void definirTema(ThemeMode m) {
    themeMode = m;
    settings.themeMode = m;
    notifyListeners();
  }

  Future<void> entrarComoVisitante() async {
    usuario = Usuario.convidado;
    settings.usuarioAtual = usuario.id;
    await usuarios.salvar(usuario);
    await usuarios.iniciarSessao(usuario.id, 'local');
    perfil = await perfis.carregar(usuario.id);
    _mudou();
  }

  /// Retorna quantos registros de visitante foram vinculados à conta.
  Future<int> entrarComGoogle() async {
    final u = await auth.entrarComGoogle();
    usuario = u;
    settings.usuarioAtual = u.id;
    await usuarios.salvar(u);
    await usuarios.iniciarSessao(u.id, 'google');
    final n = await usuarios.migrarDadosVisitante(u.id);
    await recalcularPerfil();
    return n;
  }

  Future<void> sair() async {
    await usuarios.encerrarSessoes(usuario.id);
    if (!usuario.visitante) await auth.sair();
    usuario = Usuario.convidado;
    settings.usuarioAtual = null;
    perfil = await perfis.carregar(usuario.id);
    _mudou();
  }

  Future<Map<String, Eixo>> eixos() => testes.eixos();

  /// Consolida os resultados mais recentes de cada teste no Perfil Político Pessoal.
  Future<void> recalcularPerfil() async {
    final ultimos = await testes.ultimosPorTeste(usuario.id);
    if (ultimos.isEmpty) {
      await perfis.excluir(usuario.id);
      perfil = null;
    } else {
      final defs = await eixos();
      final cons = scoring.consolidar(ultimos.values);
      final indice = scoring.indiceGeral(cons, defs);
      await perfis.salvar(usuario.id, cons, indice, scoring.classeGeral(indice), scoring.rotuloDescritivo(cons, defs));
      perfil = await perfis.carregar(usuario.id);
    }
    _mudou();
  }

  Future<int> salvarResultado(ResultadoTeste r) async {
    final id = await testes.salvarResultado(usuario.id, r);
    await testes.descartarRascunho(usuario.id, r.testeId);
    await recalcularPerfil();
    return id;
  }

  Future<void> recarregarSinalizacoes() async {
    sinalizacoes = await correcoes.sinalizacoes();
    _mudou();
  }

  String? notaRevisao(String tipo, String id) => sinalizacoes['$tipo:$id'];

  Future<void> apagarMeusDados() async {
    await usuarios.apagarDados(usuario.id);
    perfil = null;
    _mudou();
  }

  Future<void> recarregarConteudo() async {
    await SeedService(database).carregar();
    testes.limparCache();
    conteudo.limparCache();
    _mudou();
  }

  void _mudou() {
    versaoDados++;
    notifyListeners();
  }

  String get rotuloIa => settings.apiKeyIa.isEmpty
      ? 'Triagem local (sem IA configurada)'
      : 'Claude (${settings.modeloIa})';

  static const avisoGeral = AppInfo.avisoPermanente;
}
