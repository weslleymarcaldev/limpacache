import * as vscode from 'vscode';
import { CacheManager } from './cacheManager';
import { formatBytes } from './extension';

export class StatusBarManager {
  private item: vscode.StatusBarItem;
  private refreshTimer: NodeJS.Timeout | undefined;

  constructor(
    context: vscode.ExtensionContext,
    private readonly cacheManager: CacheManager
  ) {
    this.item = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    this.item.command = 'limpacache.openPanel';
    this.item.tooltip = 'LimpaCache — Click to open dashboard';

    const config = vscode.workspace.getConfiguration('limpacache');
    if (config.get<boolean>('showStatusBar', true)) {
      this.item.show();
      this.setLoading();
    }

    context.subscriptions.push(this.item);

    context.subscriptions.push(
      vscode.workspace.onDidChangeConfiguration(e => {
        if (e.affectsConfiguration('limpacache.showStatusBar')) {
          const show = vscode.workspace.getConfiguration('limpacache').get<boolean>('showStatusBar', true);
          if (show) { this.item.show(); this.refresh(); }
          else { this.item.hide(); }
        }
      })
    );
  }

  setLoading(): void {
    this.item.text = '$(loading~spin) LimpaCache';
    this.item.backgroundColor = undefined;
  }

  async refresh(): Promise<void> {
    if (this.refreshTimer) { clearTimeout(this.refreshTimer); }
    this.refreshTimer = setTimeout(async () => {
      try {
        this.setLoading();
        const total = await this.cacheManager.getTotalCacheSize();
        if (total === 0) {
          this.item.text = '$(check) LimpaCache: Clean';
          this.item.backgroundColor = undefined;
          this.item.tooltip = 'No cache detected — workspace is clean!';
        } else if (total > 1_000_000_000) {
          this.item.text = `$(trash) ${formatBytes(total)} cache`;
          this.item.backgroundColor = new vscode.ThemeColor('statusBarItem.errorBackground');
          this.item.tooltip = `LimpaCache: ${formatBytes(total)} of cache — click to clean`;
        } else if (total > 100_000_000) {
          this.item.text = `$(trash) ${formatBytes(total)} cache`;
          this.item.backgroundColor = new vscode.ThemeColor('statusBarItem.warningBackground');
          this.item.tooltip = `LimpaCache: ${formatBytes(total)} of cache — click to clean`;
        } else {
          this.item.text = `$(trash) ${formatBytes(total)} cache`;
          this.item.backgroundColor = undefined;
          this.item.tooltip = `LimpaCache: ${formatBytes(total)} of cache — click to clean`;
        }
      } catch {
        this.item.text = '$(trash) LimpaCache';
      }
    }, 500);
  }

  dispose(): void {
    if (this.refreshTimer) { clearTimeout(this.refreshTimer); }
    this.item.dispose();
  }
}
