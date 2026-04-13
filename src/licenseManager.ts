import * as vscode from 'vscode';

const API_KEY_SECRET = 'limpacache.anthropicApiKey';

export class LicenseManager {
  constructor(private readonly context: vscode.ExtensionContext) {}

  isPro(): boolean {
    const key = this.getApiKey();
    return !!key && key.startsWith('sk-ant-');
  }

  getApiKey(): string | undefined {
    return this.context.globalState.get<string>(API_KEY_SECRET);
  }

  async setApiKey(key: string): Promise<void> {
    await this.context.secrets.store(API_KEY_SECRET, key);
    await this.context.globalState.update(API_KEY_SECRET, key);
  }

  async removeApiKey(): Promise<void> {
    await this.context.secrets.delete(API_KEY_SECRET);
    await this.context.globalState.update(API_KEY_SECRET, undefined);
  }

  getPlanLabel(): string {
    return this.isPro() ? '✨ Pro' : 'Free';
  }

  getFeatures(): { free: string[]; pro: string[] } {
    return {
      free: [
        'Detect 40+ cache types automatically',
        'Clean project caches (build, dist, .cache, etc.)',
        'Clean IDE caches (VS Code, JetBrains)',
        'Status bar cache size indicator',
        'Manual scan and clean',
        'Context menu integration',
        'Keyboard shortcuts',
      ],
      pro: [
        'Everything in Free',
        'AI-powered cache analysis (Claude AI)',
        'Natural language commands',
        'Smart cleaning recommendations',
        'Auto-schedule cleaning (cron)',
        'Custom cache rules',
        'Generate cleaning scripts',
        'AI schedule suggestions',
        'Chat with AI about your caches',
      ],
    };
  }
}
