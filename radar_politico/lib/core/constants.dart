/// Textos fixos, avisos e configurações do Radar Político.
class AppInfo {
  static const nome = 'Radar Político';
  static const versao = '1.0.0';

  static const avisoCurto =
      'Este aplicativo é informativo, imparcial e não recomenda votos.';

  static const avisoPermanente =
      'Este aplicativo é uma ferramenta educativa e informativa. Não faz recomendação de voto.';

  static const avisoComoAvaliamos =
      'Este aplicativo é uma ferramenta educativa e informativa. Ele não recomenda votos, '
      'não defende partidos, candidatos ou ideologias. Os resultados são estimativas baseadas '
      'nas respostas do usuário e em informações públicas verificáveis.';

  static const avisoEstimativa =
      'Este resultado é uma estimativa baseada nas suas respostas. Não é um rótulo definitivo '
      'e não representa apoio a partidos ou candidatos.';

  static const avisoCompatibilidade =
      'A compatibilidade é uma estimativa e não é uma recomendação de voto. Candidatos podem mudar '
      'de posição, e informações públicas podem estar incompletas ou desatualizadas. Pesquise, '
      'compare e decida por conta própria.';

  /// Versão do conteúdo empacotado em assets/data. Aumente ao editar os JSON
  /// para que o app recarregue o conteúdo no banco local (dados do usuário são mantidos).
  static const versaoConteudo = 3;

  /// ID do cliente OAuth "Web" do Google (necessário no Android para o login).
  /// Defina com: flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
  static const googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// Chave opcional da API do Claude embutida no build (apenas para testes).
  /// Em produção, use um backend intermediário. Ver README.
  static const anthropicApiKeyBuild =
      String.fromEnvironment('ANTHROPIC_API_KEY');

  static const modeloIaPadrao = 'claude-opus-5-5';
}

/// Status de promessas e itens do governo.
class StatusGov {
  static const cumprida = 'cumprida';
  static const parcial = 'parcialmente_cumprida';
  static const andamento = 'em_andamento';
  static const naoCumprida = 'nao_cumprida';
  static const informativo = 'informativo';

  static const rotulos = {
    cumprida: 'Cumprida',
    parcial: 'Parcialmente cumprida',
    andamento: 'Em andamento',
    naoCumprida: 'Não cumprida',
    informativo: 'Indicador / contexto',
  };
}

class CategoriaGov {
  static const rotulos = {
    'promessa': 'Promessa',
    'medida_implementada': 'Medida implementada',
    'medida_nao_implementada': 'Medida anunciada, não implementada integralmente',
    'resultado': 'Resultado / indicador',
    'contexto': 'Contexto e fatores externos',
  };
}

class TemasGov {
  static const rotulos = {
    'economia': 'Economia',
    'saude': 'Saúde',
    'educacao': 'Educação',
    'seguranca': 'Segurança',
    'meio_ambiente': 'Meio ambiente',
    'emprego': 'Emprego',
    'infraestrutura': 'Infraestrutura',
    'direitos_sociais': 'Direitos sociais',
    'corrupcao': 'Corrupção e integridade',
    'instituicoes': 'Instituições',
  };
}

/// Classificações possíveis de uma correção reportada.
class ClassificacaoCorrecao {
  static const valida = 'correcao_valida';
  static const maisInfo = 'precisa_mais_informacoes';
  static const duvida = 'duvida';
  static const opiniao = 'opiniao';
  static const impropria = 'conteudo_improprio';
  static const pendente = 'aguardando_revisao';

  static const rotulos = {
    valida: 'Correção válida',
    maisInfo: 'Precisa de mais informações',
    duvida: 'Dúvida',
    opiniao: 'Opinião',
    impropria: 'Conteúdo impróprio',
    pendente: 'Aguardando revisão',
  };

  static const todas = [valida, maisInfo, duvida, opiniao, impropria];
}
