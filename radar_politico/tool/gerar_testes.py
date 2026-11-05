"""Gera assets/data/testes.json e eixos.json.

Uso: python3 tool/gerar_testes.py
Depois de gerado, o JSON e a fonte de verdade: pode ser editado direto.
Convencao: cada alternativa pontua de 1 (polo A do eixo) a 4 (polo B do eixo).
"""
import json, os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "data")

EIXOS = [
    dict(id="economia", nome="Economia", poloA="Mais Estado", poloB="Mais mercado",
         descricao="Grau de participação do Estado versus do mercado na economia: tributação, regulação, estatais, crédito e comércio.", esquerdaDireita="A"),
    dict(id="seguranca", nome="Segurança", poloA="Prevenção social", poloB="Endurecimento penal",
         descricao="Ênfase em prevenção, ressocialização e políticas sociais versus penas mais duras, policiamento e restrição de benefícios.", esquerdaDireita="A"),
    dict(id="direitos_civis", nome="Direitos civis e costumes", poloA="Progressista", poloB="Conservador",
         descricao="Posições sobre família, diversidade, políticas afirmativas e temas morais. Progressista = favorável a mudanças nos costumes; conservador = preservação de valores tradicionais.", esquerdaDireita="A"),
    dict(id="papel_estado", nome="Papel do Estado", poloA="Mais intervenção", poloB="Menos intervenção",
         descricao="Tamanho do Estado, programas sociais, servidores, burocracia e intervenção estatal em geral.", esquerdaDireita="A"),
    dict(id="meio_ambiente", nome="Meio ambiente", poloA="Regulação forte", poloB="Menor regulação",
         descricao="Rigor do licenciamento, metas de desmatamento, clima e equilíbrio entre produção e preservação.", esquerdaDireita="A"),
    dict(id="liberdade_autoridade", nome="Liberdade × autoridade", poloA="Liberdade individual", poloB="Autoridade e ordem",
         descricao="Preferência por garantias individuais e limites ao poder do Estado versus maior autoridade, controle e ordem. Este eixo não é tratado como esquerda/direita.", esquerdaDireita=None),
    dict(id="federalismo", nome="Federalismo", poloA="Centralização na União", poloB="Descentralização",
         descricao="Distribuição de poder e recursos entre União, estados e municípios. Este eixo não é tratado como esquerda/direita.", esquerdaDireita=None),
    dict(id="religiao_estado", nome="Religião e Estado", poloA="Laicidade estrita", poloB="Maior presença religiosa",
         descricao="Grau de separação entre instituições religiosas e o Estado: símbolos, ensino religioso, isenções e influência em leis.", esquerdaDireita="A"),
]

AGREE = ["Concordo totalmente", "Concordo em parte", "Discordo em parte", "Discordo totalmente"]

def q(texto, eixos, opts=None, tema=None):
    """eixos: dict eixo->'A'|'B' (ou tupla (polo, peso)).
    Afirmacao a favor do polo A: 'Concordo totalmente' = 1 ponto.
    Afirmacao a favor do polo B: 'Concordo totalmente' = 4 pontos.
    opts: alternativas proprias, ja ordenadas do polo A (1) ao polo B (4)."""
    norm = {}
    for e, v in eixos.items():
        polo, peso = (v if isinstance(v, tuple) else (v, 1.0))
        norm[e] = (polo, peso)
    alternativas = []
    labels = opts or AGREE
    for i, txt in enumerate(labels):
        pts = {}
        for e, (polo, peso) in norm.items():
            base = i + 1
            if opts is None and polo == "B":
                base = 4 - i
            if opts is not None and polo == "B":
                pass  # opcoes proprias ja vem ordenadas A->B
            pts[e] = {"pontos": base, "peso": peso}
        alternativas.append({"letra": "ABCD"[i], "texto": txt, "pontuacao": pts})
    return {"texto": texto, "tema": tema, "alternativas": alternativas}

TESTES = []

TESTES.append(dict(id="economico", titulo="Teste Econômico", icone="payments", tempoMin=6,
  descricao="Estado e mercado, impostos, serviços públicos, privatizações, regulação, trabalho, previdência e distribuição de renda.",
  explicacao="Você verá afirmações e perguntas sobre economia. Não existe resposta certa ou errada: escolha a opção mais próxima da sua opinião. O resultado é uma estimativa.",
  perguntas=[
    q("O Estado deve ter papel central na definição dos rumos da economia, por meio de bancos públicos e planejamento.", {"economia": "A", "papel_estado": ("A", .5)}, tema="Estado e mercado"),
    q("Empresas estatais de setores como energia e saneamento deveriam ser privatizadas quando houver ganho de eficiência comprovado.", {"economia": "B"}, tema="Privatizações"),
    q("Sobre a carga tributária brasileira, qual frase se aproxima mais da sua opinião?", {"economia": "A"}, opts=[
        "Deveria aumentar para as rendas mais altas, ampliando serviços públicos",
        "Deveria ser mantida, mas redistribuída: mais tributo sobre renda e menos sobre consumo",
        "Deveria ser reduzida gradualmente, com corte de despesas",
        "Deveria ser reduzida de forma significativa, com um Estado menor"], tema="Impostos"),
    q("A cobrança de imposto sobre lucros e dividendos distribuídos é uma forma adequada de tornar a tributação mais progressiva.", {"economia": "A"}, tema="Impostos"),
    q("Saúde e educação devem ser prestadas prioritariamente pelo poder público, de forma gratuita e universal.", {"economia": "A", "papel_estado": ("A", .5)}, tema="Serviços públicos"),
    q("Concessões, parcerias público-privadas e vouchers são boas alternativas para melhorar serviços públicos.", {"economia": "B"}, tema="Serviços públicos"),
    q("O governo deve influenciar preços de itens essenciais, como combustíveis e energia, quando houver alta forte.", {"economia": "A"}, tema="Regulação"),
    q("Flexibilizar regras trabalhistas tende a gerar mais empregos formais.", {"economia": "B"}, tema="Trabalho"),
    q("A legislação deveria garantir mais direitos aos trabalhadores de aplicativos, mesmo que isso aumente os custos das plataformas.", {"economia": "A"}, tema="Trabalho"),
    q("Sobre a Previdência Social, qual caminho você prefere?", {"economia": "A"}, opts=[
        "Ampliar benefícios e financiá-los com mais tributos sobre altas rendas",
        "Manter o modelo atual, com ajustes pontuais",
        "Endurecer regras de acesso para equilibrar as contas",
        "Migrar gradualmente para um modelo de capitalização individual"], tema="Previdência"),
    q("Programas de transferência de renda são instrumentos importantes para reduzir a desigualdade.", {"economia": "A"}, tema="Distribuição de renda"),
    q("O salário mínimo deve ter aumentos reais regulares, acima da inflação.", {"economia": "A"}, tema="Distribuição de renda"),
    q("O equilíbrio das contas públicas deve ter prioridade, mesmo que exija cortes em programas.", {"economia": "B"}, tema="Contas públicas"),
    q("O Brasil deveria reduzir tarifas de importação e abrir mais a economia ao comércio internacional.", {"economia": "B"}, tema="Comércio"),
    q("O Banco Central deve definir os juros com autonomia, sem interferência do governo.", {"economia": "B"}, tema="Regulação"),
    q("Bancos públicos devem oferecer crédito com juros subsidiados a setores considerados estratégicos.", {"economia": "A"}, tema="Estado e mercado"),
  ]))

TESTES.append(dict(id="social", titulo="Teste Social e de Direitos", icone="diversity_3", tempoMin=6,
  descricao="Direitos civis, minorias, igualdade, família, religião e Estado, liberdade de expressão, diversidade e políticas afirmativas.",
  explicacao="Temas sociais costumam envolver valores pessoais. Responda com tranquilidade: o objetivo é apenas mapear sua opinião, sem julgamento.",
  perguntas=[
    q("O casamento civil entre pessoas do mesmo sexo deve continuar reconhecido pela lei.", {"direitos_civis": "A"}, tema="Direitos civis"),
    q("A família formada por pai, mãe e filhos deve ter prioridade nas políticas públicas voltadas à família.", {"direitos_civis": "B"}, tema="Família"),
    q("Cotas em universidades e concursos públicos são instrumentos válidos para reduzir desigualdades.", {"direitos_civis": "A"}, tema="Políticas afirmativas"),
    q("Valores religiosos podem orientar legitimamente as decisões de parlamentares e governantes.", {"religiao_estado": "B"}, tema="Religião e Estado"),
    q("Escolas públicas não deveriam oferecer ensino religioso, nem mesmo de forma opcional.", {"religiao_estado": "A"}, tema="Religião e Estado"),
    q("Sobre a interrupção voluntária da gravidez, qual opção se aproxima mais da sua opinião?", {"direitos_civis": "A"}, opts=[
        "Deveria ser permitida por decisão da gestante nas primeiras semanas",
        "Deveria ser permitida em mais situações do que as atuais",
        "Deveria permanecer como hoje (estupro, risco de vida e anencefalia)",
        "Deveria ser mais restrita do que hoje"], tema="Direitos civis"),
    q("Abordar gênero e diversidade nas escolas contribui para reduzir discriminação.", {"direitos_civis": "A"}, tema="Diversidade"),
    q("Cabe principalmente à família, e não à escola, tratar de temas como sexualidade com crianças.", {"direitos_civis": "B"}, tema="Família"),
    q("Discursos ofensivos contra grupos sociais devem poder ser punidos por lei, mesmo que isso limite a liberdade de expressão.", {"direitos_civis": "A", "liberdade_autoridade": ("B", .5)}, tema="Liberdade de expressão"),
    q("Plataformas digitais devem ser responsabilizadas por conteúdos ilegais publicados por usuários.", {"liberdade_autoridade": "B"}, tema="Liberdade de expressão"),
    q("A imunidade tributária de templos religiosos deve ser mantida.", {"religiao_estado": "B"}, tema="Religião e Estado"),
    q("O Estado deve adotar políticas específicas de proteção a pessoas LGBTQIA+.", {"direitos_civis": "A"}, tema="Minorias"),
    q("Símbolos religiosos em prédios públicos são compatíveis com um Estado laico.", {"religiao_estado": "B"}, tema="Religião e Estado"),
    q("Cada adulto deve poder decidir sobre a própria vida, desde que não prejudique terceiros, mesmo em temas polêmicos.", {"liberdade_autoridade": "A", "direitos_civis": ("A", .5)}, tema="Igualdade e liberdade"),
  ]))

TESTES.append(dict(id="seguranca", titulo="Teste de Segurança e Justiça", icone="local_police", tempoMin=6,
  descricao="Prevenção, policiamento, penas, sistema prisional, drogas, armas, direitos humanos e eficiência policial.",
  explicacao="Segurança pública envolve escolhas difíceis. Escolha a opção mais próxima do que você pensa hoje.",
  perguntas=[
    q("Investir em educação, emprego e urbanização é a forma mais eficaz de reduzir a criminalidade no longo prazo.", {"seguranca": "A"}, tema="Prevenção"),
    q("Penas de prisão mais longas reduzem a criminalidade.", {"seguranca": "B"}, tema="Penas"),
    q("A maioridade penal deveria ser reduzida para 16 anos.", {"seguranca": "B"}, tema="Penas"),
    q("Sobre o sistema prisional, qual prioridade você considera mais importante?", {"seguranca": "A"}, opts=[
        "Reduzir o encarceramento com penas alternativas para crimes sem violência",
        "Melhorar condições e programas de ressocialização",
        "Ampliar o número de vagas, com construção de presídios",
        "Endurecer regimes e restringir benefícios como a progressão de pena"], tema="Sistema prisional"),
    q("Sobre a política de drogas, qual opção se aproxima mais da sua opinião?", {"seguranca": "A", "liberdade_autoridade": ("A", .5)}, opts=[
        "Legalizar e regular, como álcool e tabaco",
        "Descriminalizar o porte para uso pessoal",
        "Manter as regras atuais",
        "Endurecer a punição para porte e consumo"], tema="Drogas"),
    q("Sobre a posse e o porte de armas por civis:", {"seguranca": "A"}, opts=[
        "Deveriam ser proibidos, salvo exceções muito restritas",
        "Deveriam seguir regras rígidas de controle",
        "Deveriam ser facilitados para quem cumprir requisitos",
        "Deveriam ser amplamente facilitados"], tema="Armas"),
    q("Câmeras corporais em policiais aumentam a transparência e deveriam ser obrigatórias.", {"seguranca": "A"}, tema="Eficiência policial"),
    q("Os direitos de pessoas presas devem ser garantidos mesmo em casos de crimes graves.", {"seguranca": "A", "liberdade_autoridade": ("A", .5)}, tema="Direitos humanos"),
    q("A polícia deveria ter mais autonomia para agir em operações em áreas dominadas pelo crime organizado.", {"seguranca": "B", "liberdade_autoridade": ("B", .5)}, tema="Policiamento"),
    q("Audiências de custódia são um instrumento importante para evitar prisões ilegais.", {"seguranca": "A"}, tema="Direitos humanos"),
    q("A saída temporária de presos em datas comemorativas deveria ser extinta.", {"seguranca": "B"}, tema="Sistema prisional"),
    q("A eficiência policial deve ser medida principalmente pela redução de homicídios, e não pelo número de prisões.", {"seguranca": "A"}, tema="Eficiência policial"),
    q("O uso das Forças Armadas em ações de segurança pública deveria ser ampliado.", {"seguranca": "B", "liberdade_autoridade": ("B", .5)}, tema="Policiamento"),
    q("Programas de prevenção para jovens em áreas vulneráveis deveriam receber mais recursos do que a expansão do policiamento ostensivo.", {"seguranca": "A"}, tema="Prevenção"),
  ]))

TESTES.append(dict(id="ambiental", titulo="Teste Ambiental", icone="forest", tempoMin=5,
  descricao="Regulação ambiental, desmatamento, energias renováveis, mineração, agronegócio, clima e desenvolvimento versus preservação.",
  explicacao="Este teste mede como você equilibra produção econômica e proteção ambiental.",
  perguntas=[
    q("O licenciamento ambiental deve ser rigoroso, mesmo que atrase obras de infraestrutura.", {"meio_ambiente": "A"}, tema="Regulação ambiental"),
    q("O desenvolvimento econômico deve ter prioridade quando entra em conflito com a preservação ambiental.", {"meio_ambiente": "B"}, tema="Desenvolvimento x preservação"),
    q("O Brasil deveria perseguir a meta de zerar o desmatamento ilegal, mesmo com custos para alguns setores.", {"meio_ambiente": "A"}, tema="Desmatamento"),
    q("A exploração de petróleo em novas fronteiras, como a Margem Equatorial, deve ser autorizada.", {"meio_ambiente": "B"}, tema="Energia"),
    q("O Estado deve oferecer incentivos financeiros a energias renováveis, como solar e eólica.", {"meio_ambiente": "A", "economia": ("A", .5)}, tema="Energias renováveis"),
    q("A mineração em terras indígenas deveria ser permitida, com regras e consulta às comunidades.", {"meio_ambiente": "B"}, tema="Mineração"),
    q("O agronegócio deveria ter regras ambientais menos restritivas para ampliar a produção.", {"meio_ambiente": "B"}, tema="Agronegócio"),
    q("A mudança do clima causada por atividades humanas exige ações urgentes do governo.", {"meio_ambiente": "A"}, tema="Mudanças climáticas"),
    q("Multas ambientais deveriam ser mais altas e cobradas com mais rigor.", {"meio_ambiente": "A"}, tema="Regulação ambiental"),
    q("A demarcação de terras indígenas contribui para a preservação ambiental.", {"meio_ambiente": "A"}, tema="Desmatamento"),
    q("O registro de novos agrotóxicos deveria ser mais ágil.", {"meio_ambiente": "B"}, tema="Agronegócio"),
    q("Qual frase descreve melhor sua visão sobre crescimento e meio ambiente?", {"meio_ambiente": "A"}, opts=[
        "Preservar deve vir primeiro, mesmo com menor crescimento",
        "É possível conciliar, com regras ambientais fortes",
        "É possível conciliar, com regras mais simples e rápidas",
        "O crescimento deve vir primeiro; a preservação pode ser ajustada depois"], tema="Desenvolvimento x preservação"),
  ]))

TESTES.append(dict(id="papel_estado", titulo="Teste de Papel do Estado", icone="account_balance", tempoMin=5,
  descricao="Tamanho do Estado, burocracia, serviços públicos, estatais, liberdade econômica, programas sociais, intervenção e federalismo.",
  explicacao="Aqui o foco é o tamanho e a forma de atuação do Estado, incluindo a divisão de poder entre União, estados e municípios.",
  perguntas=[
    q("Sobre o tamanho do Estado brasileiro:", {"papel_estado": "A"}, opts=[
        "Deveria crescer para oferecer mais serviços",
        "Está adequado, mas precisa ser mais eficiente",
        "Deveria ser reduzido em algumas áreas",
        "Deveria ser bastante reduzido"], tema="Tamanho do Estado"),
    q("A burocracia para abrir e manter empresas deveria ser drasticamente reduzida.", {"papel_estado": "B"}, tema="Burocracia"),
    q("Empresas como Petrobras e Banco do Brasil devem continuar sob controle do Estado.", {"papel_estado": "A", "economia": ("A", .5)}, tema="Empresas estatais"),
    q("Programas sociais devem ser ampliados, mesmo que exijam mais gastos públicos.", {"papel_estado": "A"}, tema="Programas sociais"),
    q("Programas sociais devem ter regras de saída e contrapartidas mais exigentes.", {"papel_estado": "B"}, tema="Programas sociais"),
    q("O Estado deve intervir em setores estratégicos para garantir a soberania nacional.", {"papel_estado": "A"}, tema="Intervenção estatal"),
    q("Liberdade econômica é a principal condição para a prosperidade de um país.", {"papel_estado": "B", "economia": ("B", .5)}, tema="Liberdade econômica"),
    q("Estados e municípios deveriam ter mais autonomia para arrecadar e decidir onde gastar.", {"federalismo": "B"}, tema="Federalismo"),
    q("Políticas de educação e saúde devem seguir padrões nacionais definidos pela União.", {"federalismo": "A"}, tema="Federalismo"),
    q("Os estados deveriam ter mais liberdade para definir suas próprias políticas de segurança pública.", {"federalismo": "B"}, tema="Federalismo"),
    q("A estabilidade dos servidores públicos deveria ser revista para algumas carreiras.", {"papel_estado": "B"}, tema="Serviços públicos"),
    q("Concursos públicos e carreiras estáveis são essenciais para um serviço público de qualidade.", {"papel_estado": "A"}, tema="Serviços públicos"),
  ]))

TESTES.append(dict(id="instituicoes", titulo="Teste de Instituições e Democracia", icone="gavel", tempoMin=5,
  descricao="Separação dos poderes, transparência, combate à corrupção, liberdade de imprensa, controle social e participação política.",
  explicacao="Este teste mede sua preferência entre garantias individuais e maior autoridade do Estado, além da participação cidadã. Não é um teste de esquerda ou direita.",
  perguntas=[
    q("A independência entre Executivo, Legislativo e Judiciário deve ser preservada mesmo quando atrasa decisões importantes.", {"liberdade_autoridade": "A"}, tema="Separação dos poderes"),
    q("Em momentos de crise, o chefe do Executivo deveria ter poderes ampliados para agir com rapidez.", {"liberdade_autoridade": "B"}, tema="Separação dos poderes"),
    q("A liberdade de imprensa deve ser protegida mesmo quando a cobertura é crítica a quem governa.", {"liberdade_autoridade": "A"}, tema="Liberdade de imprensa"),
    q("O governo deveria poder restringir a divulgação de notícias que considere falsas.", {"liberdade_autoridade": "B"}, tema="Liberdade de imprensa"),
    q("Dados sobre gastos públicos devem estar disponíveis em tempo real para qualquer cidadão.", {"liberdade_autoridade": "A"}, tema="Transparência"),
    q("O combate à corrupção justifica flexibilizar algumas garantias processuais dos investigados.", {"liberdade_autoridade": "B"}, tema="Combate à corrupção"),
    q("Conselhos de políticas públicas e consultas populares deveriam ter mais peso nas decisões de governo.", {"liberdade_autoridade": "A", "federalismo": ("B", .5)}, tema="Controle social"),
    q("O voto deveria ser facultativo no Brasil.", {"liberdade_autoridade": "A"}, tema="Participação política"),
    q("Manifestações de rua devem ser garantidas mesmo quando causam transtornos ao trânsito e ao comércio.", {"liberdade_autoridade": "A"}, tema="Participação política"),
    q("Prefeituras deveriam ter mais poder de decisão do que o governo federal sobre políticas locais.", {"federalismo": "B"}, tema="Federalismo"),
    q("Leis que ampliam a vigilância do Estado sobre comunicações digitais são aceitáveis para garantir segurança.", {"liberdade_autoridade": "B"}, tema="Liberdades"),
    q("Emendas parlamentares deveriam ter regras de transparência mais rígidas, com identificação do autor e do beneficiário.", {"liberdade_autoridade": "A"}, tema="Transparência"),
  ]))

TESTES.append(dict(id="rapido", titulo="Teste Rápido de Posicionamento Geral", icone="bolt", tempoMin=3, rapido=True,
  descricao="12 perguntas que resumem seu posicionamento geral em uma escala de esquerda a direita.",
  explicacao="Versão curta para uma visão geral. Para um perfil mais preciso, faça também os testes temáticos.",
  perguntas=[
    q("O Estado deve ter papel ativo na economia para reduzir desigualdades.", {"economia": "A", "papel_estado": ("A", .5)}, tema="Economia"),
    q("Reduzir impostos e gastos públicos é o melhor caminho para o crescimento.", {"economia": "B"}, tema="Economia"),
    q("Privatizar empresas estatais tende a melhorar os serviços.", {"papel_estado": "B"}, tema="Papel do Estado"),
    q("Programas de transferência de renda devem ser ampliados.", {"papel_estado": "A"}, tema="Papel do Estado"),
    q("Penas mais duras são a principal forma de combater o crime.", {"seguranca": "B"}, tema="Segurança"),
    q("Políticas sociais são mais eficazes do que a repressão para reduzir a violência no longo prazo.", {"seguranca": "A"}, tema="Segurança"),
    q("O casamento civil entre pessoas do mesmo sexo deve continuar reconhecido.", {"direitos_civis": "A"}, tema="Costumes"),
    q("Valores religiosos devem orientar as leis do país.", {"religiao_estado": "B"}, tema="Religião e Estado"),
    q("A proteção ambiental deve ter prioridade sobre a expansão da produção.", {"meio_ambiente": "A"}, tema="Meio ambiente"),
    q("A posse de armas por civis deve ser facilitada.", {"seguranca": "B"}, tema="Segurança"),
    q("Cotas são instrumentos válidos para reduzir desigualdades.", {"direitos_civis": "A"}, tema="Costumes"),
    q("O Estado deve garantir liberdades individuais mesmo quando contrariam a opinião da maioria.", {"liberdade_autoridade": "A"}, tema="Liberdades"),
  ]))

for t in TESTES:
    for i, p in enumerate(t["perguntas"]):
        p["id"] = f"{t['id']}_{i+1:02d}"
    n = len(t["perguntas"])
    assert 10 <= n <= 20, (t["id"], n)

with open(os.path.join(OUT, "testes.json"), "w", encoding="utf-8") as f:
    json.dump({"versao": 1, "testes": TESTES}, f, ensure_ascii=False, indent=1)
with open(os.path.join(OUT, "eixos.json"), "w", encoding="utf-8") as f:
    json.dump({"versao": 1, "eixos": EIXOS}, f, ensure_ascii=False, indent=1)
print({t["id"]: len(t["perguntas"]) for t in TESTES})
