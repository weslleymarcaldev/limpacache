import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:radar_politico/app.dart';
import 'package:radar_politico/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Teste de fluxo completo do app com banco SQLite real (ffi) e conteúdo real.
/// Também salva capturas em build/screenshots/ (útil para revisão visual).
void main() {
  final raiz = GlobalKey();
  final dirShots = Directory('build/screenshots')..createSync(recursive: true);

  Future<void> carregarFontes() async {
    final base = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/sdk/flutter'}/bin/cache/artifacts/material_fonts';
    Future<void> f(String familia, List<String> arquivos) async {
      final l = FontLoader(familia);
      for (final a in arquivos) {
        final arq = File('$base/$a');
        if (arq.existsSync()) l.addFont(Future.value(ByteData.sublistView(arq.readAsBytesSync())));
      }
      await l.load();
    }
    await f('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
    await f('MaterialIcons', ['MaterialIcons-Regular.otf']);
  }

  Future<void> esperar(WidgetTester t, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await t.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> foto(WidgetTester t, String nome) async {
    await t.runAsync(() async {
      final b = raiz.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1.5);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('${dirShots.path}/$nome.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  Future<void> tocar(WidgetTester t, Finder f) async {
    // Rola a tela visível até o alvo aparecer (listas são construídas sob demanda).
    for (var i = 0; i < 30 && f.evaluate().isEmpty; i++) {
      await t.dragFrom(const Offset(200, 500), const Offset(0, -300));
      await t.pump(const Duration(milliseconds: 300));
    }
    await t.ensureVisible(f.first);
    await t.pump();
    await t.tap(f.first);
    await esperar(t);
  }

  Future<void> voltar(WidgetTester t) async {
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await t.pump();
  }

  testWidgets('fluxo principal do app', (t) async {
    await t.runAsync(carregarFontes);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    final dbDir = Directory.systemTemp.createTempSync('radar');
    await t.runAsync(() => databaseFactory.setDatabasesPath(dbDir.path));
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2280);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);

    final estado = AppState();
    await t.pumpWidget(RepaintBoundary(
      key: raiz,
      child: ChangeNotifierProvider.value(value: estado, child: const RadarPoliticoApp()),
    ));
    await esperar(t, 4);
    await foto(t, '01_splash');
    await t.pump(const Duration(seconds: 2));
    await esperar(t, 10);

    // Onboarding
    expect(find.text('Entenda sua posição política'), findsOneWidget);
    await foto(t, '02_onboarding');
    for (var i = 0; i < 4; i++) {
      await tocar(t, find.text('Próximo'));
      await t.pump(const Duration(milliseconds: 400));
    }
    await tocar(t, find.byType(CheckboxListTile));
    await foto(t, '03_termos');
    await tocar(t, find.text('Aceitar e continuar'));
    await t.pump(const Duration(milliseconds: 500));

    // Login
    expect(find.text('Entrar com Google'), findsOneWidget);
    await foto(t, '04_login');
    await tocar(t, find.text('Continuar sem login'));
    await t.pump(const Duration(milliseconds: 500));
    await esperar(t, 8);

    // Home
    expect(find.text('Seu Perfil Político Pessoal'), findsOneWidget);
    await foto(t, '05_home');

    // Testes -> teste rápido
    await tocar(t, find.text('Testes').last);
    await esperar(t, 6);
    await foto(t, '06_testes');
    await tocar(t, find.text('Teste Rápido de Posicionamento Geral'));
    await t.pump(const Duration(milliseconds: 400));
    await esperar(t, 6);
    await foto(t, '07_intro_teste');
    await tocar(t, find.text('Começar teste'));
    await t.pump(const Duration(milliseconds: 400));
    await foto(t, '08_pergunta');
    for (var i = 0; i < 12; i++) {
      final alts = find.byType(InkWell).evaluate().length;
      expect(alts, greaterThan(3));
      final letra = i.isEven ? 'Concordo em parte' : 'Concordo totalmente';
      await tocar(t, find.text(letra));
      await t.pump(const Duration(milliseconds: 400));
      await esperar(t, 2);
      if (Platform.environment['DEBUG_SHOTS'] != null) await foto(t, 'dbg_q$i');
    }
    expect(find.text('Revisar respostas'), findsOneWidget);
    await foto(t, '09_revisao');
    await tocar(t, find.text('Finalizar e ver resultado'));
    await t.pump(const Duration(milliseconds: 500));
    await esperar(t, 8);
    await foto(t, '10_resultado');
    expect(find.textContaining('Resultado salvo no seu perfil'), findsOneWidget);
    await t.drag(find.byType(ListView).last, const Offset(0, -1400));
    await esperar(t, 3);
    await foto(t, '11_resultado_2');
    await voltar(t);
    await t.pump(const Duration(milliseconds: 500));
    await esperar(t, 4);

    // Perfil
    await tocar(t, find.text('Perfil').last);
    await esperar(t, 6);
    expect(find.text('Pontuação por eixo'), findsOneWidget);
    await foto(t, '12_perfil');

    // Candidatos
    await tocar(t, find.text('Candidatos').last);
    await esperar(t, 6);
    await foto(t, '13_candidatos');
    await tocar(t, find.text('Ordenar por compatibilidade com as suas respostas'));
    await esperar(t, 3);
    await foto(t, '14_candidatos_compat');
    await t.drag(find.byType(ListView).last, const Offset(0, 2000));
    await esperar(t, 2);
    await t.enterText(find.byType(TextField).first, 'Marina');
    await esperar(t, 3);
    await tocar(t, find.text('Marina Silva'));
    await t.pump(const Duration(milliseconds: 400));
    await esperar(t, 4);
    await foto(t, '15_candidato');
    await tocar(t, find.text('Comparar com meu perfil'));
    await t.pump(const Duration(milliseconds: 400));
    await esperar(t, 6);
    expect(find.text('Compatibilidade por eixo'), findsOneWidget);
    await foto(t, '16_comparacao');
    await voltar(t);
    await t.pump(const Duration(milliseconds: 400));
    await voltar(t);
    await t.pump(const Duration(milliseconds: 400));
    await esperar(t, 3);

    // Governo (via Home)
    await tocar(t, find.text('Início').last);
    await esperar(t, 4);
    await tocar(t, find.text('Análise do governo atual'));
    await t.pump(const Duration(milliseconds: 400));
    await esperar(t, 6);
    expect(find.text('Promessas por status'), findsOneWidget);
    await foto(t, '17_governo');
    await tocar(t, find.text('Não cumprida').first);
    await esperar(t, 3);
    await foto(t, '18_governo_filtro');
    await voltar(t);
    await t.pump(const Duration(milliseconds: 400));
    await esperar(t, 3);

    // Quiz
    await tocar(t, find.text('Quiz').last);
    await esperar(t, 6);
    await foto(t, '19_quiz');
    await tocar(t, find.text('Começar rodada (10 perguntas)'));
    await t.pump(const Duration(milliseconds: 400));
    await esperar(t, 4);
    await tocar(t, find.textContaining('A)'));
    await esperar(t, 3);
    expect(find.textContaining('Resposta'), findsWidgets);
    await foto(t, '20_quiz_resposta');
    await voltar(t);
    await t.pump(const Duration(milliseconds: 400));
    await esperar(t, 3);

    // Correções
    await tocar(t, find.text('Correções').last);
    await esperar(t, 4);
    await tocar(t, find.text('Nova correção'));
    await t.pump(const Duration(milliseconds: 400));
    await esperar(t, 3);
    await tocar(t, find.text('Enviar para análise'));
    expect(find.textContaining('mínimo 5 caracteres'), findsOneWidget, reason: 'validação do formulário');
    await t.enterText(find.byType(TextFormField).at(0), 'Número de ministérios em 2023');
    await t.enterText(find.byType(TextFormField).at(1), 'O texto informa 37 ministérios, mas houve alteração posterior.');
    await t.enterText(find.byType(TextFormField).at(2), 'https://www.gov.br/planalto');
    await esperar(t, 2);
    await foto(t, '21_reportar');
    await tocar(t, find.text('Enviar para análise'));
    await esperar(t, 10);
    expect(find.text('Aguardando revisão'), findsOneWidget);
    await foto(t, '22_correcao_resposta');
    await tocar(t, find.text('Entendi'));
    await t.pump(const Duration(milliseconds: 500));
    await esperar(t, 6);
    await foto(t, '23_correcoes');

    // Como avaliamos + modo escuro
    estado.definirTema(ThemeMode.dark);
    await tocar(t, find.text('Início').last);
    await esperar(t, 4);
    await foto(t, '24_home_escuro');
    await tocar(t, find.byTooltip('Como avaliamos').first);
    await t.pump(const Duration(milliseconds: 400));
    await esperar(t, 3);
    expect(find.textContaining('não recomenda votos'), findsWidgets);
    await foto(t, '25_como_avaliamos');

    expect(t.takeException(), isNull);
    await t.runAsync(() async => (await estado.database.db).close());
  });
}
