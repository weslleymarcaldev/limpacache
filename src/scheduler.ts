import * as vscode from 'vscode';
import { LicenseManager } from './licenseManager';

export class Scheduler {
  constructor(
    _context: vscode.ExtensionContext,
    _cacheManager: unknown,
    _licenseManager: LicenseManager
  ) {}

  async initialize(): Promise<void> {}

  scheduleFromCron(_cronExpression: string): void {}

  cancelSchedule(): void {}

  getState(): undefined { return undefined; }

  getNextRunLabel(): string { return 'Not scheduled'; }

  getLastRunLabel(): string { return 'Never'; }

  dispose(): void {}
}
