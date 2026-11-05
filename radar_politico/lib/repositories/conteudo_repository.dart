import '../data/database.dart';
import '../models/conteudo.dart';

/// Candidatos, governo e quiz.
class ConteudoRepository {
  final AppDatabase database;
  ConteudoRepository(this.database);

  List<Candidato>? _cands;
  void limparCache() => _cands = null;

  Future<String?> meta(String chave) async {
    final db = await database.db;
    final r = await db.query('meta', where: 'chave = ?', whereArgs: [chave]);
    return r.isEmpty ? null : r.first['valor'] as String?;
  }

  Future<List<Candidato>> candidatos() async {
    if (_cands != null) return _cands!;
    final db = await database.db;
    final cs = await db.query('candidatos', orderBy: 'ordem');
    final pos = await db.query('posicionamentos_candidatos', orderBy: 'candidato_id, tipo, ordem');
    final eix = await db.query('candidato_eixos');
    final fon = await db.rawQuery(
        'SELECT cf.candidato_id, f.titulo, f.url FROM candidato_fontes cf JOIN fontes f ON f.id = cf.fonte_id');
    return _cands = cs.map((c) {
      final id = c['id'] as String;
      final itens = <String, List<ItemInfo>>{};
      for (final p in pos.where((p) => p['candidato_id'] == id)) {
        itens.putIfAbsent(p['tipo'] as String, () => []).add(ItemInfo(p['texto'] as String,
            fonte: p['fonte'] as String?, data: p['data'] as String?, emRevisao: p['em_revisao'] == 1));
      }
      return Candidato(
        id: id,
        nome: c['nome'] as String,
        cargo: (c['cargo'] as String?) ?? '',
        partido: (c['partido'] as String?) ?? '',
        uf: (c['uf'] as String?) ?? '',
        resumo: (c['resumo'] as String?) ?? '',
        baseEixos: (c['base_eixos'] as String?) ?? '',
        aviso: c['aviso'] as String?,
        atualizadoEm: (c['atualizado_em'] as String?) ?? '',
        itens: itens,
        eixos: {
          for (final e in eix.where((e) => e['candidato_id'] == id))
            e['eixo_id'] as String: (e['valor'] as num).toDouble()
        },
        fontes: fon.where((f) => f['candidato_id'] == id).map((f) => FonteRef(f['titulo'] as String, f['url'] as String?)).toList(),
      );
    }).toList();
  }

  Future<List<GovItem>> governo() async {
    final db = await database.db;
    final prom = await db.rawQuery('''SELECT p.*, 'promessa' AS categoria, f.titulo AS fonte_titulo, f.url AS fonte_url
        FROM promessas p LEFT JOIN fontes f ON f.id = p.fonte_id ORDER BY p.ordem''');
    final acoes = await db.rawQuery('''SELECT a.*, f.titulo AS fonte_titulo, f.url AS fonte_url
        FROM acoes_governamentais a LEFT JOIN fontes f ON f.id = a.fonte_id ORDER BY a.ordem''');
    return [...prom, ...acoes].map(GovItem.fromDb).toList();
  }

  Future<List<Map<String, Object?>>> quizzes() async {
    final db = await database.db;
    return db.query('quizzes', orderBy: 'titulo');
  }

  Future<List<QuizPergunta>> perguntasQuiz({String? nivel, String? tema}) async {
    final db = await database.db;
    final where = <String>[];
    final args = <Object?>[];
    if (nivel != null) {
      where.add('nivel = ?');
      args.add(nivel);
    }
    if (tema != null) {
      where.add('quiz_id = ?');
      args.add(tema);
    }
    final rows = await db.query('perguntas_quiz', where: where.isEmpty ? null : where.join(' AND '), whereArgs: args);
    return rows.map(QuizPergunta.fromDb).toList();
  }

  Future<int> totalPerguntasQuiz() async {
    final db = await database.db;
    final r = await db.rawQuery('SELECT COUNT(*) c FROM perguntas_quiz');
    return r.first['c'] as int;
  }

  // ---- quiz: respostas e pontuações
  Future<void> registrarRespostaQuiz(String usuarioId, String partidaId, String perguntaId, int escolhida, bool correta) async {
    final db = await database.db;
    await db.insert('respostas_quiz', {
      'usuario_id': usuarioId, 'partida_id': partidaId, 'pergunta_id': perguntaId, 'escolhida': escolhida,
      'correta': correta ? 1 : 0, 'criado_em': DateTime.now().toIso8601String(),
    });
  }

  Future<void> salvarPontuacao({
    required String usuarioId,
    required String partidaId,
    required String nome,
    required String nivel,
    String? tema,
    required int pontos,
    required int acertos,
    required int total,
    required int melhorSequencia,
  }) async {
    final db = await database.db;
    await db.insert('pontuacoes', {
      'usuario_id': usuarioId, 'partida_id': partidaId, 'nome_jogador': nome, 'nivel': nivel, 'tema': tema,
      'pontos': pontos, 'acertos': acertos, 'total': total, 'melhor_sequencia': melhorSequencia,
      'criado_em': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> ranking({int limite = 10}) async {
    final db = await database.db;
    return db.query('pontuacoes', orderBy: 'pontos DESC, criado_em ASC', limit: limite);
  }

  Future<List<Map<String, Object?>>> historicoQuiz(String usuarioId, {int limite = 20}) async {
    final db = await database.db;
    return db.query('pontuacoes', where: 'usuario_id = ?', whereArgs: [usuarioId], orderBy: 'criado_em DESC', limit: limite);
  }

  Future<Map<String, int>> estatisticasQuiz(String usuarioId) async {
    final db = await database.db;
    final r = await db.rawQuery(
        'SELECT COUNT(*) total, COALESCE(SUM(correta),0) acertos FROM respostas_quiz WHERE usuario_id = ?', [usuarioId]);
    final m = await db.rawQuery(
        'SELECT COALESCE(MAX(pontos),0) melhor, COALESCE(MAX(melhor_sequencia),0) seq FROM pontuacoes WHERE usuario_id = ?', [usuarioId]);
    return {
      'respondidas': r.first['total'] as int,
      'acertos': (r.first['acertos'] as num).toInt(),
      'melhor': (m.first['melhor'] as num).toInt(),
      'sequencia': (m.first['seq'] as num).toInt(),
    };
  }
}
