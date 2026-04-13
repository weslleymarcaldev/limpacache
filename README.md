# LimpaCache — Smart Cache Cleaner

> Limpador inteligente de cache para VS Code com análise por IA. Mantenha seu workspace rápido e seu disco limpo.

---

## Recursos

### Free
- **Detecta 40+ tipos de cache** — Node.js, Next.js, Nuxt, Python, Java, Rust, .NET, PHP e mais
- **Limpeza de caches do projeto** — `node_modules/.cache`, `.next`, `dist`, `build`, `__pycache__`, `.gradle`, etc.
- **Limpeza de caches do IDE** — VS Code, JetBrains, npm, pip, Yarn (caches globais)
- **Indicador na status bar** — Mostra o tamanho total do cache com cores de urgência
- **Atalho de teclado** — `Ctrl+Shift+Alt+C` para limpar todos os caches seguros
- **Menu de contexto** — Clique direito em qualquer pasta no Explorer
- **Limpeza seletiva** — Marque exatamente o que deseja limpar

### ✨ Pro (requer Anthropic API Key)
- **Análise com IA** — Claude AI analisa seus caches e dá recomendações personalizadas
- **Chat com IA** — Pergunte "O que posso deletar com segurança?" ou "O que está ocupando mais espaço?"
- **Agendamento inteligente** — Configure expressões cron para limpeza automática
- **Geração de scripts** — IA gera scripts PowerShell/Bash prontos para usar
- **Sugestão de agendamento** — IA recomenda o melhor horário de limpeza para o seu projeto
- **Regras customizadas** — Adicione seus próprios caminhos de cache

---

## Como usar

1. Instale a extensão
2. Abra o painel: `Ctrl+Shift+Alt+L` ou clique no ícone 🧹 na barra de atividades
3. Clique em **Scan** para detectar caches
4. Selecione o que limpar e clique em **Clean Selected**

### Desbloquear o Pro

1. Obtenha uma API key gratuita em [console.anthropic.com](https://console.anthropic.com/)
2. Execute: `LimpaCache: Set Anthropic API Key (Unlock Pro)` no Command Palette
3. Insira sua chave (começa com `sk-ant-`)
4. Todos os recursos Pro estão desbloqueados!

---

## Comandos

| Comando | Descrição | Atalho |
|---------|-----------|--------|
| `LimpaCache: Open Dashboard` | Abre o painel principal | `Ctrl+Shift+Alt+L` |
| `LimpaCache: Clean All Caches` | Limpa todos os caches seguros | `Ctrl+Shift+Alt+C` |
| `LimpaCache: Clean Project Caches` | Limpa apenas caches do projeto | — |
| `LimpaCache: Clean IDE Caches` | Limpa apenas caches do IDE | — |
| `LimpaCache: AI Analyze Caches ✨ Pro` | Análise com IA | — |
| `LimpaCache: AI Assistant ✨ Pro` | Abre o chat com IA | — |
| `LimpaCache: Schedule Auto-Clean ✨ Pro` | Configura agendamento | — |
| `LimpaCache: Set Anthropic API Key` | Configura a chave Pro | — |

---

## Configurações

| Setting | Padrão | Descrição |
|---------|--------|-----------|
| `limpacache.autoScanOnStartup` | `true` | Escanear ao iniciar o VS Code |
| `limpacache.showStatusBar` | `true` | Mostrar indicador na status bar |
| `limpacache.confirmBeforeClean` | `true` | Pedir confirmação antes de limpar |
| `limpacache.excludePatterns` | `[]` | Padrões glob para excluir |
| `limpacache.customCachePaths` | `[]` | ✨ Pro: Caminhos extras para escanear |
| `limpacache.autoCleanSchedule` | `""` | ✨ Pro: Expressão cron para limpeza automática |
| `limpacache.aiModel` | `claude-haiku-4-5-20251001` | ✨ Pro: Modelo de IA |

---

## Privacidade

- Nenhuma telemetria coletada
- O plano Free funciona 100% offline
- Recursos Pro usam sua própria API key Anthropic — requisições vão direto para a API da Anthropic
- Sua API key é armazenada no armazenamento seguro e criptografado do VS Code

---

## Licença

MIT
