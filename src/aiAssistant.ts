import * as vscode from 'vscode';
import { CacheItem } from './cacheManager';
import { LicenseManager } from './licenseManager';

export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

export interface AiAnalysisResult {
  summary: string;
  recommendations: AiRecommendation[];
  riskItems: string[];
  cleaningPlan: string;
}

export interface AiRecommendation {
  id: string;
  action: 'clean' | 'keep' | 'inspect';
  reason: string;
  priority: 'high' | 'medium' | 'low';
  sizeBytes: number;
  label: string;
}

export class AiAssistant {
  constructor(
    private readonly licenseManager: LicenseManager,
    private readonly _cacheManager: unknown
  ) {}

  async analyzeAndRecommend(_items: CacheItem[]): Promise<AiAnalysisResult> {
    this.requirePro();
    return { summary: '', recommendations: [], riskItems: [], cleaningPlan: '' };
  }

  async chat(_message: string, _items: CacheItem[]): Promise<string> {
    this.requirePro();
    return '';
  }

  async generateCleaningScript(_items: CacheItem[]): Promise<string> {
    this.requirePro();
    return '';
  }

  async suggestSchedule(_items: CacheItem[]): Promise<string> {
    this.requirePro();
    return '{}';
  }

  clearHistory(): void {}

  private requirePro(): never {
    vscode.commands.executeCommand('limpacache.setApiKey');
    throw new Error('This feature requires LimpaCache Pro. Set your Anthropic API key to unlock it.');
  }
}
