import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../widgets/comum.dart';

class ComoAvaliamosScreen extends StatelessWidget {
  const ComoAvaliamosScreen({super.key});

  static const _secoes = [
    ('1. Fontes utilizadas',
        'Priorizamos fontes oficiais e públicas: Planalto (legislação), Câmara dos Deputados, Senado Federal, Congresso Nacional, TSE, STF, '
            'IBGE, Banco Central, Tesouro Nacional, Ministério da Fazenda, Ministério da Saúde (DataSUS), Ministério da Educação, Portal da Transparência, '
            'INPE e relatórios de organismos internacionais. Imprensa de referência é usada como complemento. Cada item exibe fonte e data. '
            'O que não pôde ser verificado com segurança aparece como "Informação em revisão".'),
    ('2. Como as promessas são classificadas',
        '• Cumprida: há ato oficial (lei, decreto, programa) ou indicador que comprova a entrega.\n'
            '• Parcialmente cumprida: entrega existe, mas abaixo do prometido, com ressalvas ou revertida em parte.\n'
            '• Em andamento: medida iniciada, com meta ainda em curso ou tramitação no Congresso.\n'
            '• Não cumprida: prazo vencido ou medida não implementada.\n'
            'Indicadores e fatores externos (juros, crises, decisões de outros Poderes) são apresentados como contexto, sem status de promessa.'),
    ('3. Como calculamos a compatibilidade',
        'Cada resposta dos testes vale de 1 a 4 pontos em um ou mais eixos (por exemplo, Economia: 1 = mais Estado, 4 = mais mercado). '
            'Convertemos a soma em uma escala de 0 a 100 por eixo. A posição de cada político em cada eixo é uma estimativa editorial, também de 0 a 100, '
            'construída a partir de propostas, votos, atos e declarações públicas documentadas (a base aparece no perfil do político). '
            'A compatibilidade por eixo é 100 menos a distância entre as duas posições, e a geral é a média dos eixos selecionados. '
            'Metade das afirmações dos testes é formulada em cada direção para reduzir o viés de concordância.'),
    ('4. Fato, opinião e estimativa',
        '• Fato: informação verificável em fonte (ex.: "a Lei 14.601/2023 foi sancionada").\n'
            '• Estimativa: cálculo ou classificação feita pelo app (ex.: seu índice geral, a posição estimada de um político).\n'
            '• Opinião: juízo de valor. O app não emite opiniões sobre governos ou políticos. Declarações de políticos são apresentadas como paráfrases, com fonte.'),
    ('5. Como reportar erros',
        'Em qualquer conteúdo, toque em "Reportar correção". Informe o trecho, o motivo e, se possível, uma fonte (link oficial, número da lei, dado do IBGE).'),
    ('6. Como as correções são analisadas',
        'Quando a IA está configurada, o reporte é enviado ao modelo Claude com instruções editoriais de neutralidade, e classificado como: correção válida, '
            'precisa de mais informações, dúvida, opinião ou conteúdo impróprio. Sem IA, uma triagem local conservadora encaminha o reporte para revisão humana. '
            'Correções válidas sinalizam o conteúdo e são registradas no histórico de alterações com data. Salvaguardas automáticas rejeitam sugestões com '
            'linguagem partidária, rótulos pejorativos ou recomendação de voto, e correções de baixa confiança ficam "em revisão".'),
    ('7. Como evitamos viés político',
        '• Mesma estrutura de informação para todos os políticos.\n'
            '• Linguagem factual, sem adjetivos valorativos e sem rótulos pejorativos (verificado por testes automáticos no código).\n'
            '• Nenhuma recomendação de voto; compatibilidade nunca é apresentada como ranking de "melhores".\n'
            '• Promessas cumpridas e não cumpridas são exibidas lado a lado.\n'
            '• Classificações como "esquerda" e "direita" seguem convenções usuais da ciência política e são explicadas como simplificações.\n'
            '• Cores neutras, sem referência a partidos.'),
    ('8. Limitações',
        '• Testes com poucas perguntas simplificam opiniões complexas.\n'
            '• As posições dos políticos são estimativas e podem mudar.\n'
            '• Os dados foram reunidos até meados de 2026; eventos posteriores, incluindo os resultados das eleições de outubro de 2026, podem não estar refletidos.\n'
            '• A seleção de políticos privilegia ocupantes de cargos de destaque e nomes com projeção nacional; não é exaustiva.\n'
            '• A ausência de um item não significa que ele não exista.'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Como avaliamos')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const AvisoBanner(texto: AppInfo.avisoComoAvaliamos, icone: Icons.verified_user_outlined),
          for (final s in _secoes) ...[
            Secao(s.$1),
            Text(s.$2, style: const TextStyle(height: 1.45)),
          ],
          const SizedBox(height: 24),
        ]),
      );
}
