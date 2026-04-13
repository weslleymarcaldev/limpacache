import * as vscode from 'vscode';
import { CacheManager, CacheItem } from './cacheManager';
import { LicenseManager } from './licenseManager';
import { AiAssistant } from './aiAssistant';
import { Scheduler } from './scheduler';
import { formatBytes } from './extension';

type WebviewMessage =
  | { type: 'scan' }
  | { type: 'cleanSelected'; ids: string[] }
  | { type: 'cleanAll' }
  | { type: 'aiChat'; message: string }
  | { type: 'aiAnalyze' }
  | { type: 'generateScript' }
  | { type: 'setSchedule'; cron: string }
  | { type: 'clearSchedule' }
  | { type: 'suggestSchedule' }
  | { type: 'setApiKey' }
  | { type: 'removeApiKey' }
  | { type: 'openSettings' };

export class WebviewPanel {
  private panel: vscode.WebviewPanel | undefined;
  private aiAssistant: AiAssistant;
  private scheduler: Scheduler | undefined;
  private currentItems: CacheItem[] = [];

  constructor(
    private readonly context: vscode.ExtensionContext,
    private readonly cacheManager: CacheManager,
    private readonly licenseManager: LicenseManager
  ) {
    this.aiAssistant = new AiAssistant(licenseManager, cacheManager);
  }

  setScheduler(scheduler: Scheduler): void {
    this.scheduler = scheduler;
  }

  show(): void {
    if (this.panel) { this.panel.reveal(vscode.ViewColumn.One); return; }
    this.panel = vscode.window.createWebviewPanel(
      'limpacache.dashboard', 'LimpaCache Dashboard', vscode.ViewColumn.One,
      { enableScripts: true, retainContextWhenHidden: true,
        localResourceRoots: [vscode.Uri.joinPath(this.context.extensionUri, 'media')] }
    );
    this.panel.webview.html = this.buildHtml();
    this.panel.webview.onDidReceiveMessage((msg: WebviewMessage) => this.handleMessage(msg), undefined, this.context.subscriptions);
    this.panel.onDidDispose(() => { this.panel = undefined; });
    setTimeout(() => this.performScan(), 300);
  }

  openAiChat(): void { this.show(); this.panel?.webview.postMessage({ type: 'switchTab', tab: 'ai' }); }
  openScheduler(): void { this.show(); this.panel?.webview.postMessage({ type: 'switchTab', tab: 'schedule' }); }

  sendScanResults(items: CacheItem[], total: number): void {
    this.currentItems = items;
    this.panel?.webview.postMessage({ type: 'scanResults', items, totalBytes: total, totalFormatted: formatBytes(total) });
  }

  private async performScan(): Promise<void> {
    this.panel?.webview.postMessage({ type: 'scanning' });
    const items = await this.cacheManager.scanAll();
    this.sendScanResults(items, items.reduce((s, i) => s + i.sizeBytes, 0));
  }

  private async handleMessage(msg: WebviewMessage): Promise<void> {
    switch (msg.type) {
      case 'scan':
        await this.performScan();
        break;

      case 'cleanSelected': {
        const toClean = this.currentItems.filter(i => msg.ids.includes(i.id));
        if (!toClean.length) { this.panel?.webview.postMessage({ type: 'error', message: 'No items selected.' }); return; }
        this.panel?.webview.postMessage({ type: 'cleaning' });
        const r = await this.cacheManager.cleanItems(toClean);
        this.panel?.webview.postMessage({ type: 'cleanResult', cleaned: r.cleaned, failed: r.failed, freedBytes: r.freedBytes, freedFormatted: formatBytes(r.freedBytes), errors: r.errors });
        await this.performScan();
        break;
      }

      case 'cleanAll': {
        this.panel?.webview.postMessage({ type: 'cleaning' });
        const r = await this.cacheManager.cleanItems(this.currentItems);
        this.panel?.webview.postMessage({ type: 'cleanResult', cleaned: r.cleaned, failed: r.failed, freedBytes: r.freedBytes, freedFormatted: formatBytes(r.freedBytes), errors: r.errors });
        await this.performScan();
        break;
      }

      case 'aiChat': {
        if (!this.licenseManager.isPro()) { this.panel?.webview.postMessage({ type: 'proRequired', feature: 'AI Chat' }); return; }
        try {
          this.panel?.webview.postMessage({ type: 'aiThinking' });
          const response = await this.aiAssistant.chat(msg.message, this.currentItems);
          this.panel?.webview.postMessage({ type: 'aiResponse', message: response });
        } catch (err) {
          this.panel?.webview.postMessage({ type: 'aiError', message: err instanceof Error ? err.message : String(err) });
        }
        break;
      }

      case 'aiAnalyze': {
        if (!this.licenseManager.isPro()) { this.panel?.webview.postMessage({ type: 'proRequired', feature: 'AI Analysis' }); return; }
        try {
          this.panel?.webview.postMessage({ type: 'aiAnalyzing' });
          const analysis = await this.aiAssistant.analyzeAndRecommend(this.currentItems);
          this.panel?.webview.postMessage({ type: 'aiAnalysis', analysis });
        } catch (err) {
          this.panel?.webview.postMessage({ type: 'aiError', message: err instanceof Error ? err.message : String(err) });
        }
        break;
      }

      case 'generateScript': {
        if (!this.licenseManager.isPro()) { this.panel?.webview.postMessage({ type: 'proRequired', feature: 'Script Generation' }); return; }
        try {
          const script = await this.aiAssistant.generateCleaningScript(this.currentItems);
          this.panel?.webview.postMessage({ type: 'script', content: script });
        } catch (err) {
          this.panel?.webview.postMessage({ type: 'aiError', message: err instanceof Error ? err.message : String(err) });
        }
        break;
      }

      case 'suggestSchedule': {
        if (!this.licenseManager.isPro()) { this.panel?.webview.postMessage({ type: 'proRequired', feature: 'Schedule Suggestions' }); return; }
        try {
          const suggestion = await this.aiAssistant.suggestSchedule(this.currentItems);
          this.panel?.webview.postMessage({ type: 'scheduleSuggestion', suggestion });
        } catch (err) {
          this.panel?.webview.postMessage({ type: 'aiError', message: err instanceof Error ? err.message : String(err) });
        }
        break;
      }

      case 'setSchedule': {
        if (!this.licenseManager.isPro()) { this.panel?.webview.postMessage({ type: 'proRequired', feature: 'Auto-Schedule' }); return; }
        await vscode.workspace.getConfiguration('limpacache').update('autoCleanSchedule', msg.cron, vscode.ConfigurationTarget.Global);
        this.scheduler?.scheduleFromCron(msg.cron);
        this.panel?.webview.postMessage({ type: 'scheduleSet', cron: msg.cron });
        break;
      }

      case 'clearSchedule': {
        await vscode.workspace.getConfiguration('limpacache').update('autoCleanSchedule', '', vscode.ConfigurationTarget.Global);
        this.scheduler?.cancelSchedule();
        this.panel?.webview.postMessage({ type: 'scheduleCleared' });
        break;
      }

      case 'setApiKey':    vscode.commands.executeCommand('limpacache.setApiKey'); break;
      case 'removeApiKey': vscode.commands.executeCommand('limpacache.removeApiKey'); break;
      case 'openSettings':
        vscode.commands.executeCommand('workbench.action.openSettings', '@ext:YOUR_PUBLISHER_ID.limpacache');
        break;
    }
  }

  private getNonce(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return Array.from({ length: 32 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
  }

  private buildHtml(): string {
    const isPro = this.licenseManager.isPro();
    const nonce = this.getNonce();

    return /* html */`<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';">
<title>LimpaCache</title>
<style nonce="${nonce}">
:root {
  --bg: var(--vscode-editor-background);
  --fg: var(--vscode-editor-foreground);
  --bg2: var(--vscode-sideBar-background);
  --border: var(--vscode-widget-border, #444);
  --accent: var(--vscode-button-background);
  --accent-fg: var(--vscode-button-foreground);
  --accent-hover: var(--vscode-button-hoverBackground);
  --warn: var(--vscode-statusBarItem-warningBackground, #e5a000);
  --error: var(--vscode-statusBarItem-errorBackground, #c72e2e);
  --success: var(--vscode-terminal-ansiGreen, #4ec94e);
  --input-bg: var(--vscode-input-background);
  --input-border: var(--vscode-input-border, #555);
  --card: var(--vscode-editorWidget-background, #252526);
  --pro: #a78bfa;
  --r: 6px;
  --font: var(--vscode-font-family);
}
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: var(--font); font-size: 13px; background: var(--bg); color: var(--fg); }
.header { display:flex; align-items:center; gap:10px; padding:12px 16px; background:var(--bg2); border-bottom:1px solid var(--border); position:sticky; top:0; z-index:10; }
.header-title { font-size:15px; font-weight:600; flex:1; }
.badge { padding:2px 8px; border-radius:12px; font-size:11px; font-weight:600; }
.badge.free { background:var(--border); color:var(--fg); }
.badge.pro  { background:var(--pro); color:#1a1a2e; }
.tabs { display:flex; gap:2px; padding:8px 16px 0; background:var(--bg2); border-bottom:1px solid var(--border); }
.tab-btn { padding:6px 14px; background:none; border:none; border-bottom:2px solid transparent; color:var(--vscode-tab-inactiveForeground,#888); cursor:pointer; font-family:var(--font); font-size:12px; font-weight:500; }
.tab-btn:hover { color:var(--fg); }
.tab-btn.active { color:var(--fg); border-bottom-color:var(--accent); }
.tab-btn .pb { font-size:9px; color:var(--pro); margin-left:3px; }
.tab-content { display:none; padding:16px; }
.tab-content.active { display:block; }
.stats { display:grid; grid-template-columns:repeat(auto-fit,minmax(130px,1fr)); gap:8px; margin-bottom:16px; }
.stat { background:var(--card); border:1px solid var(--border); border-radius:var(--r); padding:10px 12px; text-align:center; }
.stat-val { font-size:22px; font-weight:700; color:var(--accent); }
.stat-lbl { font-size:11px; color:var(--vscode-descriptionForeground,#888); margin-top:2px; }
.btn { display:inline-flex; align-items:center; gap:5px; padding:6px 12px; border:none; border-radius:var(--r); cursor:pointer; font-family:var(--font); font-size:12px; font-weight:500; white-space:nowrap; transition:opacity .15s; }
.btn:hover { opacity:.85; }
.btn:disabled { opacity:.4; cursor:not-allowed; }
.btn-primary { background:var(--accent); color:var(--accent-fg); }
.btn-danger  { background:var(--error); color:#fff; }
.btn-ghost   { background:transparent; border:1px solid var(--border); color:var(--fg); }
.btn-ghost:hover { background:var(--card); opacity:1; }
.btn-pro     { background:linear-gradient(135deg,#6d28d9,#a78bfa); color:#fff; }
.btn-row { display:flex; flex-wrap:wrap; gap:8px; margin-bottom:12px; }
.filter-row { display:flex; align-items:center; gap:8px; margin-bottom:10px; flex-wrap:wrap; }
.filter-row input, .filter-row select {
  background:var(--input-bg); border:1px solid var(--input-border); border-radius:var(--r);
  color:var(--fg); font-family:var(--font); font-size:12px; padding:5px 8px; outline:none;
}
.filter-row input { flex:1; min-width:140px; }
.filter-row input:focus, .filter-row select:focus { border-color:var(--accent); }
.sel-row { display:flex; align-items:center; gap:6px; font-size:11px; color:var(--vscode-descriptionForeground); margin-bottom:10px; }
.sel-link { cursor:pointer; color:var(--accent); text-decoration:underline; }
.cache-list { display:flex; flex-direction:column; gap:5px; }
.cache-item { display:flex; align-items:center; gap:8px; background:var(--card); border:1px solid var(--border); border-radius:var(--r); padding:8px 10px; }
.cache-item:hover { border-color:var(--accent); }
.cache-item.unsafe { border-left:3px solid var(--warn); }
.cache-item input { flex-shrink:0; cursor:pointer; }
.cache-info { flex:1; min-width:0; }
.cache-label { font-weight:500; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.cache-meta { font-size:11px; color:var(--vscode-descriptionForeground); }
.cache-size { font-size:12px; font-weight:600; color:var(--accent); flex-shrink:0; }
.cache-size.large { color:var(--warn); }
.cache-size.huge  { color:var(--error); }
.tag { font-size:10px; padding:1px 6px; border-radius:10px; background:var(--border); flex-shrink:0; }
.tag.cat { background:var(--accent); color:var(--accent-fg); opacity:.7; }
.warn-lbl { font-size:10px; color:var(--warn); flex-shrink:0; }
.chat-wrap { display:flex; flex-direction:column; height:calc(100vh - 220px); min-height:400px; }
.chat-msgs { flex:1; overflow-y:auto; padding:10px; background:var(--card); border:1px solid var(--border); border-radius:var(--r); margin-bottom:8px; display:flex; flex-direction:column; gap:10px; }
.chat-msg { max-width:90%; }
.chat-msg.user { align-self:flex-end; }
.chat-msg.asst { align-self:flex-start; }
.chat-bubble { padding:8px 12px; border-radius:var(--r); line-height:1.5; white-space:pre-wrap; word-break:break-word; }
.chat-msg.user .chat-bubble { background:var(--accent); color:var(--accent-fg); border-bottom-right-radius:2px; }
.chat-msg.asst .chat-bubble { background:var(--bg2); border:1px solid var(--border); border-bottom-left-radius:2px; }
.chat-sender { font-size:10px; color:var(--vscode-descriptionForeground); margin-bottom:2px; }
.chat-in-row { display:flex; gap:8px; }
.chat-in { flex:1; background:var(--input-bg); border:1px solid var(--input-border); border-radius:var(--r); color:var(--fg); font-family:var(--font); font-size:12px; padding:7px 10px; outline:none; resize:none; height:36px; min-height:36px; max-height:120px; }
.chat-in:focus { border-color:var(--accent); }
.quick-ps { display:flex; flex-wrap:wrap; gap:5px; margin-bottom:10px; }
.quick-p { padding:3px 10px; background:var(--card); border:1px solid var(--border); border-radius:20px; cursor:pointer; font-size:11px; color:var(--fg); }
.quick-p:hover { border-color:var(--accent); color:var(--accent); }
.upgrade-card { background:linear-gradient(135deg,rgba(109,40,217,.15),rgba(167,139,250,.1)); border:1px solid var(--pro); border-radius:var(--r); padding:16px; margin-bottom:16px; }
.upgrade-title { font-size:14px; font-weight:600; color:var(--pro); margin-bottom:8px; }
.sched-card { background:var(--card); border:1px solid var(--border); border-radius:var(--r); padding:14px; margin-bottom:12px; }
.sched-title { font-size:13px; font-weight:600; margin-bottom:10px; }
.preset-grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(148px,1fr)); gap:7px; margin-bottom:12px; }
.preset-btn { padding:8px 10px; background:var(--bg2); border:1px solid var(--border); border-radius:var(--r); cursor:pointer; color:var(--fg); font-family:var(--font); font-size:12px; text-align:left; }
.preset-btn:hover { border-color:var(--accent); }
.preset-lbl { font-weight:500; }
.preset-cron { font-size:10px; color:var(--vscode-descriptionForeground); font-family:monospace; }
.cron-row { display:flex; gap:8px; align-items:center; flex-wrap:wrap; }
.cron-in { font-family:monospace; background:var(--input-bg); border:1px solid var(--input-border); border-radius:var(--r); color:var(--fg); font-size:13px; padding:6px 10px; flex:1; min-width:140px; outline:none; }
.cron-in:focus { border-color:var(--accent); }
.cron-help { font-size:11px; color:var(--vscode-descriptionForeground); margin-top:8px; }
.cron-help code { font-family:monospace; background:var(--bg2); padding:1px 4px; border-radius:3px; }
.status-dot { width:8px; height:8px; border-radius:50%; background:var(--vscode-descriptionForeground); flex-shrink:0; }
.status-dot.on { background:var(--success); }
.status-row { display:flex; gap:8px; align-items:center; margin-bottom:10px; }
.rec-item { display:flex; gap:8px; align-items:flex-start; padding:7px 10px; background:var(--card); border:1px solid var(--border); border-radius:var(--r); margin-bottom:5px; }
.rec-act { font-size:10px; font-weight:700; padding:2px 6px; border-radius:4px; flex-shrink:0; text-transform:uppercase; margin-top:2px; }
.rec-act.clean   { background:var(--success); color:#000; }
.rec-act.keep    { background:var(--vscode-descriptionForeground); color:var(--bg); }
.rec-act.inspect { background:var(--warn); color:#000; }
.rec-pri { font-size:10px; }
.rec-pri.high   { color:var(--error); }
.rec-pri.medium { color:var(--warn); }
.script-box { background:#1e1e1e; color:#d4d4d4; font-family:monospace; font-size:12px; padding:12px; border-radius:var(--r); overflow:auto; white-space:pre; border:1px solid var(--border); max-height:380px; }
#toast { position:fixed; bottom:18px; right:18px; padding:9px 14px; border-radius:var(--r); font-size:12px; font-weight:500; z-index:100; display:none; transition:opacity .3s; }
#toast.success { background:var(--success); color:#000; }
#toast.error   { background:var(--error);   color:#fff; }
#toast.info    { background:var(--accent);  color:var(--accent-fg); }
.empty { text-align:center; padding:36px 20px; color:var(--vscode-descriptionForeground); }
.empty-icon { font-size:38px; margin-bottom:8px; }
.empty-title { font-size:14px; font-weight:500; margin-bottom:4px; color:var(--fg); }
.spinner { display:inline-block; width:13px; height:13px; border:2px solid var(--border); border-top-color:var(--accent); border-radius:50%; animation:spin .7s linear infinite; flex-shrink:0; }
@keyframes spin { to { transform:rotate(360deg); } }
.hidden { display:none !important; }
.mt8 { margin-top:8px; }
.mb8 { margin-bottom:8px; }
.muted { color:var(--vscode-descriptionForeground); font-size:11px; }
a { color:var(--accent); }
code { font-family:monospace; background:var(--bg2); padding:1px 4px; border-radius:3px; font-size:11px; }
</style>
</head>
<body>

<div class="header">
  <span style="font-size:18px">🧹</span>
  <span class="header-title">LimpaCache</span>
  <span class="badge ${isPro ? 'pro' : 'free'}">${isPro ? '✨ Pro' : 'Free'}</span>
  <button class="btn btn-ghost" onclick="openSettings()" style="padding:3px 8px;" title="Settings">⚙</button>
</div>

<div class="tabs">
  <button class="tab-btn active" data-tab="dashboard" onclick="switchTab('dashboard')">Dashboard</button>
  <button class="tab-btn" data-tab="ai" onclick="switchTab('ai')">AI Assistant<span class="pb">✨</span></button>
  <button class="tab-btn" data-tab="schedule" onclick="switchTab('schedule')">Schedule<span class="pb">✨</span></button>
  <button class="tab-btn" data-tab="upgrade" onclick="switchTab('upgrade')">${isPro ? 'About' : 'Upgrade'}</button>
</div>

<!-- DASHBOARD -->
<div class="tab-content active" id="tab-dashboard">
  <div class="stats">
    <div class="stat"><div class="stat-val" id="s-size">–</div><div class="stat-lbl">Total Cache</div></div>
    <div class="stat"><div class="stat-val" id="s-count">–</div><div class="stat-lbl">Items</div></div>
    <div class="stat"><div class="stat-val" id="s-safe">–</div><div class="stat-lbl">Safe to Delete</div></div>
  </div>
  <div class="btn-row">
    <button class="btn btn-primary" onclick="scan()" id="btn-scan"><span id="scan-spin" class="spinner hidden"></span>🔍 Scan</button>
    <button class="btn btn-danger"  onclick="cleanSelected()">🗑 Clean Selected</button>
    <button class="btn btn-ghost"   onclick="cleanAll()">⚡ Clean All Safe</button>
    <button class="btn btn-ghost"   onclick="generateScript()" title="Generate shell script (Pro)">📜 Script <span style="color:var(--pro);font-size:10px">✨</span></button>
  </div>
  <div class="filter-row">
    <input type="text" id="filter-q" placeholder="Filter..." oninput="applyFilter()">
    <select id="filter-cat" onchange="applyFilter()">
      <option value="all">All categories</option>
      <option value="project">Project</option>
      <option value="ide">IDE</option>
    </select>
    <select id="sort-by" onchange="applyFilter()">
      <option value="size">Sort by size</option>
      <option value="name">Sort by name</option>
      <option value="category">Sort by category</option>
    </select>
  </div>
  <div class="sel-row">
    <span class="sel-link" onclick="selAll(true)">Select all</span> ·
    <span class="sel-link" onclick="selAll(false)">Deselect all</span> ·
    <span class="sel-link" onclick="selSafe()">Safe only</span>
    <span id="sel-count" class="muted" style="margin-left:8px;"></span>
  </div>
  <div id="scan-status" class="muted mb8 hidden"><span class="spinner"></span> Scanning...</div>
  <div id="clean-status" class="hidden muted mb8"><span class="spinner"></span> Cleaning...</div>
  <div id="clean-result" class="hidden" style="padding:8px 12px;background:var(--card);border:1px solid var(--border);border-radius:var(--r);margin-bottom:10px;font-size:12px;"></div>
  <div id="cache-list" class="cache-list">
    <div class="empty"><div class="empty-icon">🔍</div><div class="empty-title">No scan yet</div><div>Click Scan to detect caches.</div></div>
  </div>
  <div id="script-panel" class="hidden" style="margin-top:14px;">
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;">
      <strong style="font-size:12px">Generated Script</strong>
      <button class="btn btn-ghost" onclick="copyScript()" style="font-size:11px;padding:3px 8px;">📋 Copy</button>
    </div>
    <div class="script-box" id="script-content"></div>
  </div>
</div>

<!-- AI -->
<div class="tab-content" id="tab-ai">
${isPro ? `
  <div class="btn-row">
    <button class="btn btn-pro" onclick="aiAnalyze()">🔬 Analyze All Caches</button>
    <button class="btn btn-ghost" onclick="clearChat()">🗑 Clear Chat</button>
  </div>
  <div id="ai-analysis" class="hidden" style="margin-bottom:14px;"></div>
  <div class="quick-ps">
    <button class="quick-p" onclick="qp(this.textContent)">O que posso deletar com segurança?</button>
    <button class="quick-p" onclick="qp(this.textContent)">O que está ocupando mais espaço?</button>
    <button class="quick-p" onclick="qp(this.textContent)">Recomende uma estratégia de limpeza</button>
    <button class="quick-p" onclick="qp(this.textContent)">É seguro deletar node_modules/.cache?</button>
    <button class="quick-p" onclick="qp(this.textContent)">Quais caches se regeneram automaticamente?</button>
  </div>
  <div class="chat-wrap">
    <div class="chat-msgs" id="chat-msgs">
      <div class="chat-msg asst">
        <div class="chat-sender">LimpaCache AI</div>
        <div class="chat-bubble">Olá! Sou seu assistente de cache com IA. Escaneie o workspace primeiro e me pergunte qualquer coisa sobre seus caches!</div>
      </div>
    </div>
    <div class="chat-in-row">
      <textarea class="chat-in" id="chat-in" placeholder="Pergunte sobre seus caches..." onkeydown="chatKey(event)" oninput="autoH(this)"></textarea>
      <button class="btn btn-pro" onclick="sendChat()" id="btn-send">Enviar</button>
    </div>
  </div>
` : `
  <div class="upgrade-card">
    <div class="upgrade-title">✨ AI Assistant — Recurso Pro</div>
    <p class="muted" style="margin-bottom:12px;">Desbloqueie análise de cache com IA usando Claude. Recomendações inteligentes, comandos em linguagem natural e estratégias de limpeza.</p>
    <button class="btn btn-pro" onclick="setApiKey()">Configurar API Key Anthropic — Desbloquear Pro</button>
    <p class="muted mt8">Obtenha sua chave em <a href="#" onclick="setApiKey()">console.anthropic.com</a></p>
  </div>
  <p class="muted">Os recursos Pro usam sua própria API key Anthropic — você controla o uso e os custos. O modelo Haiku é muito econômico.</p>
`}
</div>

<!-- SCHEDULE -->
<div class="tab-content" id="tab-schedule">
${isPro ? `
  <div class="sched-card">
    <div class="sched-title">⏰ Limpeza Automática</div>
    <div class="status-row mb8">
      <div class="status-dot" id="sched-dot"></div>
      <span id="sched-txt" class="muted">Não agendado</span>
    </div>
    <p class="muted mb8">Escolha um preset ou insira uma expressão cron para limpar caches automaticamente.</p>
    <div class="preset-grid">
      <button class="preset-btn" onclick="setPreset('0 9 * * 1')"><div class="preset-lbl">Toda Segunda</div><div class="preset-cron">0 9 * * 1</div></button>
      <button class="preset-btn" onclick="setPreset('0 9 * * 6')"><div class="preset-lbl">Todo Sábado</div><div class="preset-cron">0 9 * * 6</div></button>
      <button class="preset-btn" onclick="setPreset('0 9 1 * *')"><div class="preset-lbl">Dia 1 do Mês</div><div class="preset-cron">0 9 1 * *</div></button>
      <button class="preset-btn" onclick="setPreset('0 */6 * * *')"><div class="preset-lbl">A cada 6h</div><div class="preset-cron">0 */6 * * *</div></button>
      <button class="preset-btn" onclick="setPreset('0 8 * * *')"><div class="preset-lbl">Diário às 8h</div><div class="preset-cron">0 8 * * *</div></button>
      <button class="preset-btn" onclick="setPreset('0 18 * * 5')"><div class="preset-lbl">Sextas às 18h</div><div class="preset-cron">0 18 * * 5</div></button>
    </div>
    <div class="cron-row">
      <input type="text" class="cron-in" id="cron-in" placeholder="0 9 * * 1">
      <button class="btn btn-primary" onclick="saveSched()">Salvar</button>
      <button class="btn btn-ghost"   onclick="clearSched()">Limpar</button>
    </div>
    <div class="cron-help">
      Formato: <code>minuto hora dia mês diaSemana</code> | Ex: <code>0 9 * * 1</code> = toda segunda às 9h |
      <a href="#" onclick="suggestSched()">✨ Pedir sugestão à IA</a>
    </div>
  </div>
  <div id="sched-suggestion" class="hidden sched-card" style="border-color:var(--pro)">
    <div class="sched-title" style="color:var(--pro)">✨ Sugestão da IA</div>
    <div id="sugg-content"></div>
  </div>
` : `
  <div class="upgrade-card">
    <div class="upgrade-title">✨ Agendamento Automático — Recurso Pro</div>
    <p class="muted" style="margin-bottom:12px;">Configure limpeza automática em horários específicos. Mantenha o workspace limpo sem pensar nisso.</p>
    <button class="btn btn-pro" onclick="setApiKey()">Desbloquear Pro — Configurar API Key</button>
  </div>
`}
</div>

<!-- UPGRADE -->
<div class="tab-content" id="tab-upgrade">
  <div style="max-width:500px;">
    ${isPro ? `
    <div style="padding:14px;background:var(--card);border:1px solid var(--pro);border-radius:var(--r);margin-bottom:14px;">
      <div style="font-size:14px;font-weight:600;color:var(--pro);margin-bottom:6px;">✨ Pro Ativo</div>
      <div class="muted">Sua API key Anthropic está configurada. Todos os recursos Pro estão disponíveis.</div>
      <button class="btn btn-ghost mt8" onclick="removeApiKey()" style="font-size:11px;padding:3px 8px;">Remover API Key</button>
    </div>
    ` : `
    <div class="upgrade-card">
      <div class="upgrade-title">✨ Upgrade para Pro</div>
      <p class="muted" style="margin-bottom:12px;">Configure sua API key Anthropic para desbloquear análise de cache com IA Claude.</p>
      <button class="btn btn-pro" onclick="setApiKey()" style="margin-bottom:6px;">Configurar API Key Anthropic</button>
      <div class="muted">Obtenha uma chave em <a href="#" onclick="setApiKey()">console.anthropic.com</a></div>
    </div>
    `}
    <h3 style="font-size:13px;margin-bottom:10px;">Comparação de Planos</h3>
    <table style="width:100%;border-collapse:collapse;font-size:12px;">
      <thead><tr style="background:var(--bg2);">
        <th style="text-align:left;padding:7px 10px;">Recurso</th>
        <th style="text-align:center;padding:7px;width:55px;">Free</th>
        <th style="text-align:center;padding:7px;width:60px;color:var(--pro);">Pro ✨</th>
      </tr></thead>
      <tbody>
        ${[
          ['40+ tipos de cache','✓','✓'],
          ['Limpar caches do projeto','✓','✓'],
          ['Limpar caches do IDE','✓','✓'],
          ['Indicador na status bar','✓','✓'],
          ['Atalhos de teclado','✓','✓'],
          ['Análise com IA','–','✓'],
          ['Chat com IA','–','✓'],
          ['Agendamento automático','–','✓'],
          ['Geração de scripts','–','✓'],
          ['Regras customizadas','–','✓'],
        ].map(([f,fr,pr]) => `<tr style="border-bottom:1px solid var(--border);">
          <td style="padding:5px 10px;">${f}</td>
          <td style="text-align:center;padding:5px;">${fr}</td>
          <td style="text-align:center;padding:5px;color:var(--pro);">${pr}</td>
        </tr>`).join('')}
      </tbody>
    </table>
    <p class="muted mt8" style="line-height:1.6;">Recursos Pro são alimentados pelo <strong>Claude AI</strong> via sua própria API key Anthropic. O modelo Haiku é recomendado (~$0.001 por análise).</p>
  </div>
</div>

<div id="toast"></div>

<script nonce="${nonce}">
const vscode = acquireVsCodeApi();
let allItems = [];

window.addEventListener('message', e => {
  const m = e.data;
  switch(m.type) {
    case 'scanning':        showScanSpin(true); break;
    case 'scanResults':     allItems = m.items; showScanSpin(false); renderList(allItems); updateStats(allItems, m.totalBytes, m.totalFormatted); break;
    case 'cleaning':        id('clean-status').classList.remove('hidden'); id('cache-list').classList.add('hidden'); break;
    case 'cleanResult':     id('clean-status').classList.add('hidden'); id('cache-list').classList.remove('hidden'); showCleanResult(m); break;
    case 'aiThinking':      addMsg('asst','<em style="color:var(--vscode-descriptionForeground)">Pensando...</em>','thinking'); id('btn-send').disabled=true; break;
    case 'aiAnalyzing':     id('ai-analysis').innerHTML='<span class="spinner"></span> Analisando...'; id('ai-analysis').classList.remove('hidden'); break;
    case 'aiResponse':      rmPlaceholder('thinking'); addMsg('asst',m.message); id('btn-send').disabled=false; break;
    case 'aiAnalysis':      renderAnalysis(m.analysis); break;
    case 'aiError':         rmPlaceholder('thinking'); addMsg('asst','⚠️ '+m.message); id('btn-send').disabled=false; toast('Erro: '+m.message,'error'); break;
    case 'proRequired':     toast(m.feature+' requer Pro.','info'); switchTab('upgrade'); break;
    case 'switchTab':       switchTab(m.tab); break;
    case 'script':          showScript(m.content); break;
    case 'scheduleSet':     toast('Agendamento salvo: '+m.cron,'success'); updSched(true,m.cron); break;
    case 'scheduleCleared': toast('Agendamento removido.','info'); updSched(false,''); break;
    case 'scheduleSuggestion': renderSugg(m.suggestion); break;
    case 'error':           toast(m.message,'error'); break;
  }
});

function id(x) { return document.getElementById(x); }
function switchTab(t) {
  document.querySelectorAll('.tab-btn').forEach(b => b.classList.toggle('active', b.dataset.tab===t));
  document.querySelectorAll('.tab-content').forEach(c => c.classList.toggle('active', c.id==='tab-'+t));
}
function scan() { vscode.postMessage({type:'scan'}); }
function cleanSelected() {
  const sel = allItems.filter(i => { const el=id('c-'+i.id); return el&&el.checked; });
  if (!sel.length) { toast('Nenhum item selecionado.','info'); return; }
  vscode.postMessage({type:'cleanSelected', ids: sel.map(i=>i.id)});
}
function cleanAll() { vscode.postMessage({type:'cleanAll'}); }
function generateScript() { vscode.postMessage({type:'generateScript'}); }
function showScanSpin(on) { id('scan-status').classList.toggle('hidden',!on); id('scan-spin').classList.toggle('hidden',!on); id('btn-scan').disabled=on; }
function showCleanResult(m) {
  const el=id('clean-result');
  const c=m.failed===0?'var(--success)':'var(--warn)';
  el.innerHTML=\`<span style="color:\${c};font-weight:600;">✓ \${m.cleaned} limpo(s), liberou <strong>\${m.freedFormatted}</strong>\${m.failed?' — '+m.failed+' falhou':''}</span>\${m.errors.length?'<br><span style="color:var(--error);font-size:11px;">'+m.errors.join('<br>')+'</span>':''}\`;
  el.classList.remove('hidden');
  setTimeout(()=>el.classList.add('hidden'),8000);
}
function renderList(items) {
  const c=id('cache-list');
  if (!items.length) { c.innerHTML='<div class="empty"><div class="empty-icon">✅</div><div class="empty-title">Nenhum cache detectado</div><div>Workspace limpo!</div></div>'; return; }
  c.innerHTML=items.map(i=>{
    const sc=i.sizeBytes>1e9?'huge':i.sizeBytes>1e8?'large':'';
    return \`<div class="cache-item\${!i.safe?' unsafe':''}">
      <input type="checkbox" id="c-\${i.id}" \${i.selected?'checked':''} onchange="updSel()">
      <div class="cache-info">
        <div class="cache-label" title="\${i.fullPath}">\${i.label}</div>
        <div class="cache-meta">\${i.description}</div>
      </div>
      <span class="tag">\${i.technology}</span>
      <span class="tag cat">\${i.category}</span>
      \${!i.safe?'<span class="warn-lbl">⚠ cuidado</span>':''}
      <span class="cache-size \${sc}">\${fmtB(i.sizeBytes)}</span>
    </div>\`;
  }).join('');
  updSel();
}
function applyFilter() {
  const q=id('filter-q').value.toLowerCase(), cat=id('filter-cat').value, sort=id('sort-by').value;
  let f=allItems.filter(i=>{
    const mt=!q||i.label.toLowerCase().includes(q)||i.technology.toLowerCase().includes(q)||i.description.toLowerCase().includes(q);
    return mt&&(cat==='all'||i.category===cat);
  });
  if (sort==='size') f.sort((a,b)=>b.sizeBytes-a.sizeBytes);
  else if (sort==='name') f.sort((a,b)=>a.label.localeCompare(b.label));
  else f.sort((a,b)=>a.category.localeCompare(b.category));
  renderList(f);
}
function updateStats(items, totalBytes, totalFormatted) {
  id('s-size').textContent=totalFormatted||fmtB(totalBytes);
  id('s-count').textContent=items.length;
  id('s-safe').textContent=items.filter(i=>i.safe).length;
}
function updSel() {
  const cbs=document.querySelectorAll('[id^="c-"]');
  id('sel-count').textContent=[...cbs].filter(c=>c.checked).length+' selecionado(s)';
}
function selAll(v) { document.querySelectorAll('[id^="c-"]').forEach(c=>c.checked=v); updSel(); }
function selSafe() { allItems.forEach(i=>{ const el=id('c-'+i.id); if(el) el.checked=i.safe; }); updSel(); }

// AI
function aiAnalyze() { vscode.postMessage({type:'aiAnalyze'}); }
function sendChat() {
  const inp=id('chat-in'), msg=inp.value.trim();
  if (!msg) return;
  inp.value=''; inp.style.height='36px';
  addMsg('user',msg);
  vscode.postMessage({type:'aiChat',message:msg});
}
function qp(text) { addMsg('user',text); vscode.postMessage({type:'aiChat',message:text}); }
function chatKey(e) { if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();sendChat();} }
function autoH(el) { el.style.height='36px'; el.style.height=Math.min(el.scrollHeight,120)+'px'; }
function addMsg(role, content, mid) {
  const c=id('chat-msgs'); if(!c) return;
  const d=document.createElement('div');
  d.className='chat-msg '+role;
  if(mid) d.dataset.mid=mid;
  d.innerHTML=\`<div class="chat-sender">\${role==='user'?'Você':'LimpaCache AI'}</div><div class="chat-bubble">\${content}</div>\`;
  c.appendChild(d); c.scrollTop=c.scrollHeight;
}
function rmPlaceholder(mid) { const el=document.querySelector('[data-mid="'+mid+'"]'); if(el) el.remove(); }
function clearChat() {
  const c=id('chat-msgs');
  if(c) c.innerHTML='<div class="chat-msg asst"><div class="chat-sender">LimpaCache AI</div><div class="chat-bubble">Chat limpo. Como posso ajudar?</div></div>';
}
function renderAnalysis(a) {
  const el=id('ai-analysis'); if(!el) return;
  let html=\`<div style="margin-bottom:12px;"><strong>📊 Resumo</strong><p style="font-size:12px;margin-top:4px;">\${a.summary}</p></div>\`;
  if(a.recommendations?.length) {
    html+=\`<div style="margin-bottom:12px;"><strong style="font-size:12px;">💡 Recomendações</strong><div style="margin-top:6px;">\`;
    html+=a.recommendations.map(r=>\`<div class="rec-item">
      <span class="rec-act \${r.action}">\${r.action}</span>
      <div style="flex:1;"><div style="font-size:12px;font-weight:500;">\${r.label}</div><div class="muted">\${r.reason}</div></div>
      <span class="rec-pri \${r.priority}" style="font-size:11px;">\${r.priority}</span>
    </div>\`).join('');
    html+='</div></div>';
  }
  if(a.cleaningPlan) html+=\`<div><strong style="font-size:12px;">🗺 Plano</strong><div style="font-size:12px;white-space:pre-wrap;margin-top:4px;">\${a.cleaningPlan}</div></div>\`;
  el.innerHTML=html; el.classList.remove('hidden');
}

// Script
function showScript(content) {
  id('script-content').textContent=content;
  id('script-panel').classList.remove('hidden');
  id('script-panel').scrollIntoView({behavior:'smooth'});
}
function copyScript() {
  navigator.clipboard.writeText(id('script-content').textContent||'').then(()=>toast('Script copiado!','success'));
}

// Schedule
function setPreset(c) { id('cron-in').value=c; }
function saveSched() {
  const c=id('cron-in').value.trim();
  if(!c) { toast('Insira uma expressão cron.','error'); return; }
  vscode.postMessage({type:'setSchedule',cron:c});
}
function clearSched() { vscode.postMessage({type:'clearSchedule'}); id('cron-in').value=''; }
function suggestSched() { vscode.postMessage({type:'suggestSchedule'}); }
function updSched(active, cron) {
  const dot=id('sched-dot'), txt=id('sched-txt');
  if(!dot||!txt) return;
  dot.className='status-dot '+(active?'on':'');
  txt.textContent=active?'Agendado: '+cron:'Não agendado';
}
function renderSugg(raw) {
  const el=id('sched-suggestion'), c=id('sugg-content');
  if(!el||!c) return;
  try {
    const d=JSON.parse(raw);
    c.innerHTML=\`<p style="font-size:12px;margin-bottom:8px;">\${d.reasoning}</p>
      <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap;">
        <code style="font-size:13px;">\${d.cronExpression}</code>
        <span class="muted">(\${d.description})</span>
        <button class="btn btn-ghost" onclick="setPreset('\${d.cronExpression}')" style="font-size:11px;padding:3px 8px;">Usar</button>
      </div>\`;
  } catch { c.innerHTML='<pre style="font-size:11px;white-space:pre-wrap;">'+raw+'</pre>'; }
  el.classList.remove('hidden');
}

function setApiKey()    { vscode.postMessage({type:'setApiKey'}); }
function removeApiKey() { vscode.postMessage({type:'removeApiKey'}); }
function openSettings() { vscode.postMessage({type:'openSettings'}); }

function fmtB(bytes) {
  if(!bytes) return '0 B';
  const k=1024, s=['B','KB','MB','GB'], i=Math.floor(Math.log(bytes)/Math.log(k));
  return parseFloat((bytes/Math.pow(k,i)).toFixed(1))+' '+s[i];
}
function toast(msg,type='info') {
  const t=id('toast'); t.textContent=msg; t.className=type; t.style.display='block'; t.style.opacity='1';
  setTimeout(()=>{t.style.opacity='0';setTimeout(()=>t.style.display='none',300);},3500);
}
</script>
</body>
</html>`;
  }
}
