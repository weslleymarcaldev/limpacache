import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Banco local SQLite. As tabelas seguem nomes em português e chaves de texto
/// estáveis (ids dos JSON) para facilitar a migração futura a Firebase/Supabase:
/// cada tabela corresponde a uma coleção, e `usuario_id` já separa os dados por conta.
class AppDatabase {
  static const _nome = 'radar_politico.db';
  static const _versao = 1;
  Database? _db;

  Future<Database> get db async => _db ??= await _abrir();

  Future<Database> _abrir() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _nome),
      version: _versao,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        final b = db.batch();
        for (final s in schema) {
          b.execute(s);
        }
        await b.commit(noResult: true);
      },
    );
  }

  /// Usado em testes (sqflite_common_ffi) para abrir um banco em memória.
  Future<void> usar(Database db) async {
    for (final s in schema) {
      await db.execute(s);
    }
    _db = db;
  }

  static const schema = [
    'CREATE TABLE meta (chave TEXT PRIMARY KEY, valor TEXT)',
    // --- usuários e sessões
    '''CREATE TABLE usuarios (id TEXT PRIMARY KEY, nome TEXT NOT NULL, email TEXT, tipo TEXT NOT NULL,
       foto_url TEXT, criado_em TEXT NOT NULL)''',
    '''CREATE TABLE sessoes (id INTEGER PRIMARY KEY AUTOINCREMENT, usuario_id TEXT NOT NULL, provedor TEXT NOT NULL,
       inicio TEXT NOT NULL, fim TEXT)''',
    // --- testes políticos
    '''CREATE TABLE eixos (id TEXT PRIMARY KEY, nome TEXT NOT NULL, polo_a TEXT NOT NULL, polo_b TEXT NOT NULL,
       descricao TEXT NOT NULL, esquerda_direita TEXT)''',
    '''CREATE TABLE testes (id TEXT PRIMARY KEY, titulo TEXT NOT NULL, descricao TEXT NOT NULL, explicacao TEXT NOT NULL,
       icone TEXT, tempo_min INTEGER, rapido INTEGER NOT NULL DEFAULT 0, ordem INTEGER NOT NULL)''',
    '''CREATE TABLE perguntas (id TEXT PRIMARY KEY, teste_id TEXT NOT NULL REFERENCES testes(id) ON DELETE CASCADE,
       ordem INTEGER NOT NULL, texto TEXT NOT NULL, tema TEXT)''',
    '''CREATE TABLE alternativas (id INTEGER PRIMARY KEY AUTOINCREMENT,
       pergunta_id TEXT NOT NULL REFERENCES perguntas(id) ON DELETE CASCADE,
       letra TEXT NOT NULL, texto TEXT NOT NULL, ordem INTEGER NOT NULL, pontuacao_json TEXT NOT NULL)''',
    // respostas em andamento (salvamento automático)
    '''CREATE TABLE respostas (usuario_id TEXT NOT NULL, teste_id TEXT NOT NULL, pergunta_id TEXT NOT NULL,
       letra TEXT NOT NULL, atualizado_em TEXT NOT NULL, PRIMARY KEY (usuario_id, teste_id, pergunta_id))''',
    '''CREATE TABLE resultados (id INTEGER PRIMARY KEY AUTOINCREMENT, usuario_id TEXT NOT NULL, teste_id TEXT NOT NULL,
       criado_em TEXT NOT NULL, pontuacao_total REAL, pontuacao_min REAL, pontuacao_max REAL, indice_geral REAL,
       classificacao TEXT, rotulo TEXT, eixos_json TEXT NOT NULL, respostas_json TEXT NOT NULL)''',
    '''CREATE TABLE perfil_politico (usuario_id TEXT PRIMARY KEY, atualizado_em TEXT NOT NULL, eixos_json TEXT NOT NULL,
       indice_geral REAL, classificacao TEXT, rotulo TEXT)''',
    // --- conteúdo político
    'CREATE TABLE fontes (id INTEGER PRIMARY KEY AUTOINCREMENT, titulo TEXT NOT NULL, url TEXT, UNIQUE(titulo, url))',
    '''CREATE TABLE candidatos (id TEXT PRIMARY KEY, nome TEXT NOT NULL, cargo TEXT, partido TEXT, uf TEXT, resumo TEXT,
       base_eixos TEXT, aviso TEXT, atualizado_em TEXT, ordem INTEGER)''',
    '''CREATE TABLE posicionamentos_candidatos (id INTEGER PRIMARY KEY AUTOINCREMENT,
       candidato_id TEXT NOT NULL REFERENCES candidatos(id) ON DELETE CASCADE, tipo TEXT NOT NULL, texto TEXT NOT NULL,
       fonte TEXT, data TEXT, em_revisao INTEGER NOT NULL DEFAULT 0, ordem INTEGER)''',
    '''CREATE TABLE candidato_eixos (candidato_id TEXT NOT NULL REFERENCES candidatos(id) ON DELETE CASCADE,
       eixo_id TEXT NOT NULL, valor REAL NOT NULL, PRIMARY KEY (candidato_id, eixo_id))''',
    '''CREATE TABLE candidato_fontes (candidato_id TEXT NOT NULL REFERENCES candidatos(id) ON DELETE CASCADE,
       fonte_id INTEGER NOT NULL REFERENCES fontes(id), PRIMARY KEY (candidato_id, fonte_id))''',
    '''CREATE TABLE promessas (id TEXT PRIMARY KEY, tema TEXT NOT NULL, status TEXT NOT NULL, titulo TEXT NOT NULL,
       descricao TEXT NOT NULL, fonte_id INTEGER REFERENCES fontes(id), data TEXT, impacto TEXT,
       em_revisao INTEGER NOT NULL DEFAULT 0, ordem INTEGER)''',
    '''CREATE TABLE acoes_governamentais (id TEXT PRIMARY KEY, categoria TEXT NOT NULL, tema TEXT NOT NULL,
       status TEXT NOT NULL, titulo TEXT NOT NULL, descricao TEXT NOT NULL, fonte_id INTEGER REFERENCES fontes(id),
       data TEXT, impacto TEXT, em_revisao INTEGER NOT NULL DEFAULT 0, ordem INTEGER)''',
    // --- quiz
    'CREATE TABLE quizzes (id TEXT PRIMARY KEY, titulo TEXT NOT NULL)',
    '''CREATE TABLE perguntas_quiz (id TEXT PRIMARY KEY, quiz_id TEXT NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
       nivel TEXT NOT NULL, pergunta TEXT NOT NULL, alternativas_json TEXT NOT NULL, correta INTEGER NOT NULL,
       explicacao TEXT NOT NULL, fonte TEXT NOT NULL)''',
    '''CREATE TABLE respostas_quiz (id INTEGER PRIMARY KEY AUTOINCREMENT, usuario_id TEXT NOT NULL, partida_id TEXT NOT NULL,
       pergunta_id TEXT NOT NULL, escolhida INTEGER NOT NULL, correta INTEGER NOT NULL, criado_em TEXT NOT NULL)''',
    '''CREATE TABLE pontuacoes (id INTEGER PRIMARY KEY AUTOINCREMENT, usuario_id TEXT NOT NULL, partida_id TEXT NOT NULL,
       nome_jogador TEXT NOT NULL, nivel TEXT NOT NULL, tema TEXT, pontos INTEGER NOT NULL, acertos INTEGER NOT NULL,
       total INTEGER NOT NULL, melhor_sequencia INTEGER NOT NULL, criado_em TEXT NOT NULL)''',
    // --- correções
    'CREATE TABLE status_correcoes (id TEXT PRIMARY KEY, nome TEXT NOT NULL, descricao TEXT)',
    '''CREATE TABLE correcoes (id INTEGER PRIMARY KEY AUTOINCREMENT, usuario_id TEXT NOT NULL, conteudo_tipo TEXT NOT NULL,
       conteudo_id TEXT NOT NULL, conteudo_trecho TEXT NOT NULL, motivo TEXT NOT NULL, fonte_usuario TEXT,
       status_id TEXT NOT NULL REFERENCES status_correcoes(id), classificacao TEXT, resposta_ia TEXT, justificativa TEXT,
       analise_json TEXT, via_ia INTEGER NOT NULL DEFAULT 0, criado_em TEXT NOT NULL, atualizado_em TEXT NOT NULL)''',
    '''CREATE TABLE historico_alteracoes (id INTEGER PRIMARY KEY AUTOINCREMENT, conteudo_tipo TEXT NOT NULL,
       conteudo_id TEXT NOT NULL, descricao TEXT NOT NULL, correcao_id INTEGER, criado_em TEXT NOT NULL)''',
    // conteúdos sinalizados para revisão (sobrevivem a recargas de conteúdo)
    '''CREATE TABLE conteudo_revisao (conteudo_tipo TEXT NOT NULL, conteudo_id TEXT NOT NULL, nota TEXT NOT NULL,
       criado_em TEXT NOT NULL, PRIMARY KEY (conteudo_tipo, conteudo_id))''',
    'CREATE INDEX idx_resultados_usuario ON resultados(usuario_id, teste_id)',
    'CREATE INDEX idx_pos_cand ON posicionamentos_candidatos(candidato_id)',
  ];
}
