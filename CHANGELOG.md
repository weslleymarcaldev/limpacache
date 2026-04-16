# Changelog

## [1.0.2] - 2026-04-15

### Corrigido

- Política de Segurança de Conteúdo (CSP) atualizada para permitir estilos inline no webview
- Handlers `onclick` inline no dashboard não eram executados devido a restrição do CSP
- Botões do dashboard não respondiam corretamente aos cliques
- Aviso de regeneração adicionado na lista quando itens de cache do IDE são detectados (IDE pode recriar caches automaticamente)
- Notificação exibida após limpeza informando o espaço liberado em bytes
- Status bar atualizada imediatamente após limpeza pelo dashboard
- Recomendações de extensões adicionadas ao workspace (`.vscode/extensions.json`)

## [1.0.0] - 2026-04-12

### Adicionado
- Lançamento inicial
- Detecção automática de 40+ tipos de cache (Node.js, Python, Java, Rust, .NET e mais)
- Limpeza de caches do projeto (build, dist, frameworks, linters)
- Limpeza de caches do IDE (VS Code, JetBrains, npm, pip, Yarn)
- Indicador na status bar com tamanho total do cache e cores de urgência
- Dashboard webview com scan, filtro, ordenação e limpeza seletiva
- Atalhos: `Ctrl+Shift+Alt+C` (limpar) e `Ctrl+Shift+Alt+L` (dashboard)
- Integração com menu de contexto do Explorer
- Tier Pro: análise de cache com IA usando Claude AI
- Tier Pro: chat com IA em linguagem natural
- Tier Pro: agendamento automático via expressões cron
- Tier Pro: geração de scripts PowerShell/Bash
- Tier Pro: sugestão de agendamento por IA
- Tier Pro: regras de cache customizadas
- Gerenciamento de licença via Anthropic API key (armazenada no secret storage do VS Code)
