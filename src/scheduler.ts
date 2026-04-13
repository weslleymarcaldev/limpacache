import * as vscode from 'vscode';
import { LicenseManager } from './licenseManager';

export class Scheduler {
  constructor(
    private readonly _context: vscode.ExtensionContext,
    private readonly _cacheManager: unknown,
    private readonly _licenseManager: LicenseManager
  ) {}

  async initialize(): Promise<void> {}

  scheduleFromCron(_cronExpression: string): void {}

  cancelSchedule(): void {}

  getState(): undefined { return undefined; }

  getNextRunLabel(): string { return 'Not scheduled'; }

  getLastRunLabel(): string { return 'Never'; }

  dispose(): void {}
}
