import 'dart:convert';

class ItemInfo {
  final String texto;
  final String? fonte;
  final String? data;
  final bool emRevisao;
  const ItemInfo(this.texto, {this.fonte, this.data, this.emRevisao = false});

  factory ItemInfo.fromJson(Map<String, dynamic> j) => ItemInfo(j['texto'],
      fonte: j['fonte'], data: j['data'], emRevisao: j['emRevisao'] == true);
}

class FonteRef {
  final String titulo;
  final String? url;
  const FonteRef(this.titulo, this.url);
}

class Candidato {
  final String id;
  final String nome;
  final String cargo;
  final String partido;
  final String uf;
  final String resumo;
  final String baseEixos;
  final String? aviso;
  final String atualizadoEm;
  /// tipo -> itens. Tipos: posicao, proposta, voto, projeto, declaracao, promessa, acao.
  final Map<String, List<ItemInfo>> itens;
  final Map<String, double> eixos;
  final List<FonteRef> fontes;

  const Candidato({
    required this.id,
    required this.nome,
    required this.cargo,
    required this.partido,
    required this.uf,
    required this.resumo,
    required this.baseEixos,
    required this.aviso,
    required this.atualizadoEm,
    required this.itens,
    required this.eixos,
    required this.fontes,
  });

  String get iniciais {
    final p = nome.split(' ').where((s) => s.length > 2).toList();
    if (p.isEmpty) return nome.substring(0, 1);
    return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
  }

  static const tiposRotulo = {
    'posicao': 'Principais posições públicas',
    'proposta': 'Propostas declaradas',
    'voto': 'Histórico de votos relevantes',
    'projeto': 'Projetos apresentados ou apoiados',
    'declaracao': 'Declarações públicas verificáveis',
    'promessa': 'Promessas de campanha',
    'acao': 'Ações efetivamente realizadas',
  };
}

class GovItem {
  final String id;
  final String categoria;
  final String tema;
  final String status;
  final String titulo;
  final String descricao;
  final String fonte;
  final String? url;
  final String data;
  final String impacto;
  final bool emRevisao;

  const GovItem({
    required this.id,
    required this.categoria,
    required this.tema,
    required this.status,
    required this.titulo,
    required this.descricao,
    required this.fonte,
    required this.url,
    required this.data,
    required this.impacto,
    required this.emRevisao,
  });

  factory GovItem.fromDb(Map<String, Object?> r) => GovItem(
        id: r['id'] as String,
        categoria: r['categoria'] as String,
        tema: r['tema'] as String,
        status: r['status'] as String,
        titulo: r['titulo'] as String,
        descricao: r['descricao'] as String,
        fonte: (r['fonte_titulo'] as String?) ?? '',
        url: r['fonte_url'] as String?,
        data: r['data'] as String,
        impacto: r['impacto'] as String,
        emRevisao: (r['em_revisao'] as int? ?? 0) == 1,
      );
}

class QuizPergunta {
  final String id;
  final String nivel;
  final String tema;
  final String pergunta;
  final List<String> alternativas;
  final int correta;
  final String explicacao;
  final String fonte;

  const QuizPergunta({
    required this.id,
    required this.nivel,
    required this.tema,
    required this.pergunta,
    required this.alternativas,
    required this.correta,
    required this.explicacao,
    required this.fonte,
  });

  factory QuizPergunta.fromDb(Map<String, Object?> r) => QuizPergunta(
        id: r['id'] as String,
        nivel: r['nivel'] as String,
        tema: r['quiz_id'] as String,
        pergunta: r['pergunta'] as String,
        alternativas: List<String>.from(jsonDecode(r['alternativas_json'] as String)),
        correta: r['correta'] as int,
        explicacao: r['explicacao'] as String,
        fonte: r['fonte'] as String,
      );

  static const niveis = {'facil': 'Fácil', 'medio': 'Médio', 'dificil': 'Difícil'};
  static const pontosPorNivel = {'facil': 10, 'medio': 20, 'dificil': 30};
}

class Correcao {
  final int? id;
  final String conteudoTipo;
  final String conteudoId;
  final String trecho;
  final String motivo;
  final String fonteUsuario;
  final String status;
  final String? classificacao;
  final String? respostaUsuario;
  final String? justificativa;
  final bool viaIa;
  final DateTime criadoEm;

  const Correcao({
    this.id,
    required this.conteudoTipo,
    required this.conteudoId,
    required this.trecho,
    required this.motivo,
    required this.fonteUsuario,
    required this.status,
    this.classificacao,
    this.respostaUsuario,
    this.justificativa,
    this.viaIa = false,
    required this.criadoEm,
  });

  factory Correcao.fromDb(Map<String, Object?> r) => Correcao(
        id: r['id'] as int,
        conteudoTipo: r['conteudo_tipo'] as String,
        conteudoId: r['conteudo_id'] as String,
        trecho: r['conteudo_trecho'] as String,
        motivo: r['motivo'] as String,
        fonteUsuario: (r['fonte_usuario'] as String?) ?? '',
        status: r['status_id'] as String,
        classificacao: r['classificacao'] as String?,
        respostaUsuario: r['resposta_ia'] as String?,
        justificativa: r['justificativa'] as String?,
        viaIa: (r['via_ia'] as int? ?? 0) == 1,
        criadoEm: DateTime.parse(r['criado_em'] as String),
      );
}

class Usuario {
  final String id;
  final String nome;
  final String? email;
  final String tipo; // 'google' | 'visitante'
  final String? fotoUrl;
  const Usuario({required this.id, required this.nome, this.email, required this.tipo, this.fotoUrl});

  bool get visitante => tipo == 'visitante';
  static const convidado = Usuario(id: 'visitante', nome: 'Visitante', tipo: 'visitante');
}
