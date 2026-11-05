# Radar Político

Aplicativo Android (Flutter) **educativo e apartidário** para:

- descobrir a própria posição política em 7 testes por eixos;
- consolidar um **Perfil Político Pessoal** com gráficos de radar, barras e linha;
- comparar suas posições com as **posições públicas declaradas** de 16 políticos (compatibilidade por eixo, nunca recomendação de voto);
- consultar uma **análise factual do governo federal 2023–2026** (42 itens com fonte, data e status);
- jogar um **quiz** de conhecimento político (122 perguntas, 3 níveis, ranking local);
- **reportar correções**, analisadas por IA (Claude) ou por triagem local.

> Este aplicativo é uma ferramenta educativa e informativa. Não faz recomendação de voto.

---

## 1. Instalar o APK

1. Copie `release/radar-politico-arm64-v8a.apk` para o celular (Android 7.0+; praticamente todos os aparelhos desde 2017 são arm64).
   Para aparelhos antigos de 32 bits, gere o APK universal (seção 3).
2. No Android, permita "Instalar apps desconhecidos" para o gerenciador de arquivos/navegador usado.
3. Toque no APK e instale.

O APK incluído é assinado com uma chave de **depuração**. Para publicar ou distribuir, gere com sua própria chave (seção 3.2). Se trocar a chave, desinstale a versão anterior antes de instalar.

## 2. Rodar o projeto

Pré-requisitos: Flutter 3.47+ (Dart 3.13+), Android SDK (platform 36, build-tools 36), JDK 17+.

```bash
cd radar_politico
flutter pub get
flutter run              # com um aparelho/emulador conectado
flutter test             # 34 testes: pontuação, compatibilidade, IA, banco, conteúdo e fluxo de telas
flutter analyze
```

O teste `test/fluxo_app_test.dart` percorre o app inteiro (onboarding → teste → resultado → perfil → candidatos → comparação → governo → quiz → correção → modo escuro) com SQLite real e salva capturas em `build/screenshots/`.

## 3. Gerar o APK

```bash
flutter build apk --release                    # universal (~59 MB)
flutter build apk --release --split-per-abi    # um APK por arquitetura (~20 MB cada)
```
Saída: `build/app/outputs/flutter-apk/`.

### 3.1 Variáveis opcionais de build

```bash
flutter build apk --release \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=SEU_ID_WEB.apps.googleusercontent.com \
  --dart-define=ANTHROPIC_API_KEY=sk-ant-...      # só para testes; ver seção 6
```

### 3.2 Assinatura própria

```bash
keytool -genkey -v -keystore ~/radar-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias radar
```
Crie `android/key.properties` (já está no `.gitignore`):
```
storePassword=...
keyPassword=...
keyAlias=radar
storeFile=/caminho/para/radar-upload.jks
```
O `android/app/build.gradle.kts` usa essa chave automaticamente quando o arquivo existe.

## 4. Estrutura de pastas

```
radar_politico/
├── assets/data/            # CONTEÚDO (fonte de verdade, JSON editável)
│   ├── eixos.json          # 8 eixos políticos e seus polos
│   ├── testes.json         # 7 testes, 92 perguntas, pontuação por eixo
│   ├── quiz.json           # 122 perguntas factuais com explicação e fonte
│   ├── candidatos.json     # 16 políticos: posições, propostas, votos, promessas, ações, eixos
│   └── governo.json        # 42 itens do governo federal 2023–2026
├── tool/                   # scripts Python que geraram os JSON (opcionais)
├── lib/
│   ├── core/               # constantes, avisos, tema, regras de neutralidade
│   ├── models/             # Eixo, TesteModel, ResultadoTeste, Candidato, GovItem, QuizPergunta, Correcao, Usuario
│   ├── data/               # AppDatabase (SQLite, esquema) e SeedService (JSON → banco)
│   ├── repositories/       # acesso a dados por domínio
│   ├── services/           # pontuação, compatibilidade, IA, login Google, compartilhamento, preferências
│   ├── state/app_state.dart# estado global (Provider)
│   ├── screens/            # telas
│   └── widgets/            # componentes e gráficos (fl_chart)
├── test/                   # testes automatizados
└── android/                # projeto Android
```

## 5. Modelo de dados (SQLite local)

| Tabela | Conteúdo |
|---|---|
| `usuarios`, `sessoes` | conta Google ou visitante; início/fim de sessão |
| `eixos` | 8 eixos (polo A ↔ polo B) |
| `testes`, `perguntas`, `alternativas` | alternativas guardam `pontuacao_json` `{eixo: {pontos 1–4, peso}}` |
| `respostas` | rascunho com **salvamento automático** por pergunta |
| `resultados` | cada tentativa: pontuação total/mín./máx., índice geral, classificação, eixos e respostas |
| `perfil_politico` | consolidação do último resultado de cada teste |
| `candidatos`, `posicionamentos_candidatos`, `candidato_eixos`, `candidato_fontes` | dados públicos por tipo (posição, proposta, voto, projeto, declaração, promessa, ação) |
| `promessas`, `acoes_governamentais`, `fontes` | análise do governo; cada item aponta para uma fonte |
| `quizzes`, `perguntas_quiz`, `respostas_quiz`, `pontuacoes` | quiz, histórico e ranking local |
| `correcoes`, `status_correcoes`, `historico_alteracoes`, `conteudo_revisao` | reportes, classificação, log de alterações e sinalizações "em revisão" |
| `meta` | versão do conteúdo carregado |

**Migração futura (Firebase/Supabase):** cada tabela corresponde a uma coleção; ids de conteúdo são strings estáveis vindas dos JSON e todos os dados pessoais já têm `usuario_id`. Basta trocar a implementação dos repositórios em `lib/repositories/` mantendo as mesmas assinaturas — telas e serviços não acessam o banco diretamente.

## 6. Como funciona a pontuação

- Cada alternativa vale 1 (polo A) a 4 (polo B) em um ou mais eixos, com peso.
- Por eixo: `percentual = (bruto − mínimo) / (máximo − mínimo) × 100`.
- Faixas por eixo: <20 forte tendência A · 20–40 tendência A · 40–60 intermediária · 60–80 tendência B · >80 forte tendência B.
- Índice geral (0 esquerda – 100 direita): média ponderada de Economia, Papel do Estado, Segurança, Costumes, Meio ambiente e Religião/Estado. *Liberdade × autoridade* e *Federalismo* ficam fora da escala esquerda–direita.
- Classificação geral: Esquerda · Centro-esquerda · Centro · Centro-direita · Direita, combinada a um rótulo descritivo (ex.: "Centro-direita — Conservador liberal").
- Divergências internas: respostas em polos opostos no mesmo eixo, ou economia e costumes em lados diferentes.
- Compatibilidade com político: `100 − |você − político|` por eixo; média dos eixos selecionados.

## 7. Alterar perguntas, candidatos e conteúdo

1. Edite o JSON em `assets/data/` (ou edite o script em `tool/` e rode `python3 tool/gerar_testes.py`, etc.).
2. Aumente `AppInfo.versaoConteudo` em `lib/core/constants.dart`.
3. Rode `flutter test` — os testes de conteúdo verificam quantidade mínima, estrutura, 4 alternativas, fonte e **linguagem proibida**.
4. Gere o APK. No primeiro uso, o app recarrega o conteúdo; resultados e perfis dos usuários são preservados.

**Novo teste:** adicione um objeto em `testes.json` com `id`, `titulo`, `descricao`, `explicacao`, `icone`, `tempoMin` e 10 a 20 `perguntas`, cada uma com 4 `alternativas` contendo `pontuacao: {"eixo": {"pontos": 1..4, "peso": 1}}`. Use afirmações nas duas direções (metade favorece cada polo) para reduzir viés de concordância — há teste que exige isso.

**Governo e candidatos:** itens não confirmados em fonte primária devem ter `"emRevisao": true` — o app exibe "Informação em revisão". Os dados atuais vão até meados de 2026; **os resultados das eleições de outubro de 2026 não estão incluídos** e precisam ser atualizados.

## 8. Login com Google

1. No Google Cloud Console, crie um projeto e configure a tela de consentimento OAuth.
2. Crie um **ID do cliente OAuth do tipo Android** com o pacote `br.radarpolitico.radar_politico` e o SHA-1 da chave que assina o APK (`keytool -list -v -keystore SUA_CHAVE.jks`).
3. Crie também um **ID do cliente do tipo Aplicativo da Web** e passe-o no build: `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`.

Sem essa configuração, o botão mostra uma mensagem clara e o usuário segue como visitante. Ao entrar com Google, os dados de visitante são vinculados à conta. Nesta versão os dados continuam **somente no aparelho**; sincronização em nuvem exige o backend da seção 5.

## 9. IA para correções (Claude)

- No app: **Configurações → Configurar API do Claude** (chave guardada só no aparelho). Modelo padrão: `claude-opus-5-5`.
- A chamada usa a Messages API (`lib/services/ai_correction_service.dart`) com saída em JSON estruturado, esforço baixo e fallback do servidor; se o modelo rejeitar recursos opcionais, repete a chamada na forma básica.
- A IA classifica em: correção válida, precisa de mais informações, dúvida, opinião ou conteúdo impróprio, e escreve a resposta ao usuário.
- **Salvaguardas no código, independentes da IA:** sugestões com rótulos pejorativos, termos valorativos ou recomendação de voto nunca são aplicadas; confiança < 0,6 vira "em revisão"; ofensas são barradas antes do envio.
- Correção válida sinaliza o conteúdo com nota datada e registra em `historico_alteracoes`. O texto original **não** é reescrito automaticamente: a alteração definitiva passa por revisão humana e atualização do JSON.
- Sem chave/sem rede: triagem local conservadora, que nunca valida sozinha.
- **Produção:** não distribua chaves dentro do APK. Use um backend intermediário (ex.: função serverless) que guarda a chave e expõe um endpoint; troque `_endpoint` e os cabeçalhos em `AiCorrectionService`.

## 10. Garantir imparcialidade em atualizações futuras

- Use apenas linguagem factual ("a lei foi sancionada", "o indicador caiu"); nada de "bom", "ruim", "desastre", "herói".
- Toda afirmação sobre político ou governo precisa de fonte e data; sem confirmação, `emRevisao: true`.
- Mantenha a mesma estrutura para todos os políticos e apresente itens cumpridos e não cumpridos lado a lado.
- Declarações devem ser paráfrases identificadas, com fonte.
- Nunca use "melhor candidato", "candidato ideal", "vote em" ou "ranking dos melhores". O teste `test/conteudo_test.dart` falha se essas expressões ou rótulos pejorativos aparecerem no conteúdo ou nas telas.
- Revise as estimativas de eixo dos políticos com pelo menos duas pessoas de visões diferentes e registre a base em `baseEixos`.
- Cores neutras (ardósia), sem paleta de partidos.

## 11. Limitações conhecidas

- Dados de política e governo coletados até meados de 2026; alguns cargos e filiações podem ter mudado (itens marcados).
- Posições dos políticos por eixo são estimativas editoriais.
- O login com Google exige configuração no Google Cloud antes de funcionar.
- O ranking do quiz é local (por aparelho).

## 12. Capturas de tela

Geradas automaticamente pelo teste de fluxo em `docs/screenshots/` (01_splash … 25_como_avaliamos).
