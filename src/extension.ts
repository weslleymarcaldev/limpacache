import * as vscode from 'vscode';
import { CacheManager } from './cacheManager';
import { LicenseManager } from './licenseManager';
import { StatusBarManager } from './statusBar';
import { WebviewPanel } from './webviewPanel';
import { Scheduler } from './scheduler';

let statusBar: StatusBarManager;
let scheduler: Scheduler;

export async function activate(context: vscode.ExtensionContext) {
  const licenseManager = new LicenseManager(context);
  const cacheManager = new CacheManager(context);
  const webviewPanel = new WebviewPanel(context, cacheManager, licenseManager);
  statusBar = new StatusBarManager(context, cacheManager);
  scheduler = new Scheduler(context, cacheManager, licenseManager);
  webviewPanel.setScheduler(scheduler);
  webviewPanel.setOnClean(() => statusBar.refresh());

  // --- Commands ---

  context.subscriptions.push(
    vscode.commands.registerCommand('limpacache.openPanel', () => {
      webviewPanel.show();
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('limpacache.cleanAll', async () => {
      const config = vscode.workspace.getConfiguration('limpacache');
      const confirm = config.get<boolean>('confirmBeforeClean', true);

      if (confirm) {
        const choice = await vscode.window.showWarningMessage(
          'Clean ALL detected caches? This action cannot be undone.',
          { modal: true },
          'Clean All',
          'Cancel'
        );
        if (choice !== 'Clean All') { return; }
      }

      await vscode.window.withProgress(
        {
          location: vscode.ProgressLocation.Notification,
          title: 'LimpaCache',
          cancellable: false,
        },
        async (progress) => {
          progress.report({ message: 'Scanning caches...' });
          const items = await cacheManager.scanAll();
          progress.report({ message: `Cleaning ${items.length} cache(s)...`, increment: 30 });
          const result = await cacheManager.cleanItems(items);
          progress.report({ increment: 70 });
          statusBar.refresh();
          vscode.window.showInformationMessage(
            `LimpaCache: Freed ${formatBytes(result.freedBytes)} across ${result.cleaned} item(s).`
          );
        }
      );
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('limpacache.cleanProject', async () => {
      await vscode.window.withProgress(
        { location: vscode.ProgressLocation.Notification, title: 'LimpaCache: Cleaning project caches...' },
        async () => {
          const items = await cacheManager.scanProject();
          const result = await cacheManager.cleanItems(items);
          statusBar.refresh();
          vscode.window.showInformationMessage(
            `Project caches cleaned. Freed ${formatBytes(result.freedBytes)}.`
          );
        }
      );
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('limpacache.cleanIDE', async () => {
      await vscode.window.withProgress(
        { location: vscode.ProgressLocation.Notification, title: 'LimpaCache: Cleaning IDE caches...' },
        async () => {
          const items = await cacheManager.scanIDE();
          const result = await cacheManager.cleanItems(items);
          statusBar.refresh();
          vscode.window.showInformationMessage(
            `IDE caches cleaned. Freed ${formatBytes(result.freedBytes)}.`
          );
        }
      );
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('limpacache.scanCaches', async () => {
      const items = await cacheManager.scanAll();
      const total = items.reduce((s, i) => s + i.sizeBytes, 0);
      webviewPanel.show();
      webviewPanel.sendScanResults(items, total);
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('limpacache.aiAnalyze', async () => {
      if (!licenseManager.isPro()) {
        await promptUpgrade('AI Analysis is a Pro feature.');
        return;
      }
      webviewPanel.show();
      webviewPanel.openAiChat();
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('limpacache.aiChat', async () => {
      if (!licenseManager.isPro()) {
        await promptUpgrade('AI Assistant is a Pro feature.');
        return;
      }
      webviewPanel.show();
      webviewPanel.openAiChat();
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('limpacache.scheduleClean', async () => {
      if (!licenseManager.isPro()) {
        await promptUpgrade('Scheduled cleaning is a Pro feature.');
        return;
      }
      webviewPanel.show();
      webviewPanel.openScheduler();
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('limpacache.setApiKey', async () => {
      const key = await vscode.window.showInputBox({
        title: 'LimpaCache Pro - Set Anthropic API Key',
        prompt: 'Enter your Anthropic API key to unlock Pro features (starts with sk-ant-)',
        password: true,
        placeHolder: 'sk-ant-...',
        validateInput: (v) => {
          if (!v) { return 'API key cannot be empty'; }
          if (!v.startsWith('sk-ant-')) { return 'Key must start with sk-ant-'; }
          return null;
        }
      });
      if (!key) { return; }

      await licenseManager.setApiKey(key);
      statusBar.refresh();
      vscode.window.showInformationMessage(
        'LimpaCache Pro unlocked! AI features are now available.',
        'Open Dashboard'
      ).then(choice => {
        if (choice === 'Open Dashboard') { webviewPanel.show(); }
      });
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('limpacache.removeApiKey', async () => {
      const choice = await vscode.window.showWarningMessage(
        'Remove API key? Pro features will be disabled.',
        'Remove', 'Cancel'
      );
      if (choice === 'Remove') {
        await licenseManager.removeApiKey();
        statusBar.refresh();
        vscode.window.showInformationMessage('API key removed. Reverted to Free plan.');
      }
    })
  );

  // Auto-scan on startup
  const config = vscode.workspace.getConfiguration('limpacache');
  if (config.get<boolean>('autoScanOnStartup', true)) {
    setTimeout(() => statusBar.refresh(), 3000);
  }

  // Initialize scheduler
  await scheduler.initialize();
}

export function deactivate() {
  statusBar?.dispose();
  scheduler?.dispose();
}

async function promptUpgrade(message: string) {
  const choice = await vscode.window.showInformationMessage(
    `✨ ${message} Set your Anthropic API key to unlock all Pro features.`,
    'Set API Key',
    'Learn More'
  );
  if (choice === 'Set API Key') {
    vscode.commands.executeCommand('limpacache.setApiKey');
  } else if (choice === 'Learn More') {
    vscode.env.openExternal(vscode.Uri.parse('https://console.anthropic.com/'));
  }
}

export function formatBytes(bytes: number): string {
  if (bytes === 0) { return '0 B'; }
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`;
}
