import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

export type CacheCategory = 'project' | 'ide' | 'system' | 'custom';

export interface CacheItem {
  id: string;
  label: string;
  description: string;
  fullPath: string;
  sizeBytes: number;
  category: CacheCategory;
  technology: string;
  safe: boolean;
  selected: boolean;
}

export interface CleanResult {
  cleaned: number;
  failed: number;
  freedBytes: number;
  errors: string[];
}

const PROJECT_CACHE_PATTERNS: Array<{
  pattern: string;
  label: string;
  tech: string;
  safe: boolean;
}> = [
  // JavaScript / Node
  { pattern: 'node_modules/.cache',    label: 'Node Modules Cache',    tech: 'Node.js',    safe: true  },
  { pattern: '.npm',                    label: 'npm Cache',              tech: 'npm',        safe: true  },
  { pattern: '.yarn/cache',            label: 'Yarn Cache',             tech: 'Yarn',       safe: true  },
  { pattern: '.pnpm-store',            label: 'pnpm Store',             tech: 'pnpm',       safe: true  },
  // Frameworks
  { pattern: '.next',                   label: 'Next.js Build Cache',    tech: 'Next.js',    safe: true  },
  { pattern: '.nuxt',                   label: 'Nuxt.js Cache',          tech: 'Nuxt.js',    safe: true  },
  { pattern: '.svelte-kit',            label: 'SvelteKit Cache',         tech: 'SvelteKit',  safe: true  },
  { pattern: '.remix',                  label: 'Remix Cache',             tech: 'Remix',      safe: true  },
  { pattern: '.gatsby-cache',          label: 'Gatsby Cache',            tech: 'Gatsby',     safe: true  },
  { pattern: '.cache',                  label: 'Generic Cache',           tech: 'Various',    safe: true  },
  { pattern: '.parcel-cache',          label: 'Parcel Cache',            tech: 'Parcel',     safe: true  },
  { pattern: '.turbo',                  label: 'Turborepo Cache',         tech: 'Turborepo',  safe: true  },
  // Build outputs
  { pattern: 'dist',                    label: 'Distribution Build',      tech: 'Build',      safe: true  },
  { pattern: 'build',                   label: 'Build Output',            tech: 'Build',      safe: true  },
  { pattern: 'out',                     label: 'Output Directory',        tech: 'Build',      safe: true  },
  // Testing
  { pattern: 'coverage',               label: 'Test Coverage',           tech: 'Testing',    safe: true  },
  { pattern: '.jest-cache',            label: 'Jest Cache',              tech: 'Jest',       safe: true  },
  { pattern: 'cypress/videos',         label: 'Cypress Videos',          tech: 'Cypress',    safe: true  },
  { pattern: 'cypress/screenshots',    label: 'Cypress Screenshots',     tech: 'Cypress',    safe: true  },
  // Python
  { pattern: '__pycache__',            label: 'Python Bytecode Cache',   tech: 'Python',     safe: true  },
  { pattern: '.pytest_cache',          label: 'pytest Cache',            tech: 'Python',     safe: true  },
  { pattern: '.mypy_cache',           label: 'MyPy Cache',              tech: 'Python',     safe: true  },
  { pattern: '.ruff_cache',           label: 'Ruff Cache',              tech: 'Python',     safe: true  },
  { pattern: '.eggs',                  label: 'Python Eggs',             tech: 'Python',     safe: true  },
  { pattern: '.venv',                  label: 'Python Virtual Env',      tech: 'Python',     safe: false },
  { pattern: 'venv',                   label: 'Python Virtual Env',      tech: 'Python',     safe: false },
  // PHP
  { pattern: 'vendor',                 label: 'Composer Vendor',         tech: 'PHP',        safe: false },
  // Java / Android
  { pattern: '.gradle',                label: 'Gradle Cache',            tech: 'Gradle',     safe: true  },
  { pattern: 'build/intermediates',    label: 'Android Intermediates',   tech: 'Android',    safe: true  },
  { pattern: '.kotlin',               label: 'Kotlin Build Cache',      tech: 'Kotlin',     safe: true  },
  // Rust
  { pattern: 'target/debug',          label: 'Rust Debug Build',        tech: 'Rust',       safe: true  },
  { pattern: 'target/release',        label: 'Rust Release Build',      tech: 'Rust',       safe: true  },
  // .NET
  { pattern: 'bin/Debug',             label: '.NET Debug Build',        tech: '.NET',       safe: true  },
  { pattern: 'bin/Release',           label: '.NET Release Build',      tech: '.NET',       safe: true  },
  { pattern: 'obj',                    label: '.NET Object Files',       tech: '.NET',       safe: true  },
  // Linters / Tools
  { pattern: '.eslintcache',          label: 'ESLint Cache',            tech: 'ESLint',     safe: true  },
  { pattern: '.stylelintcache',       label: 'Stylelint Cache',         tech: 'Stylelint',  safe: true  },
  { pattern: '.tsbuildinfo',          label: 'TypeScript Build Info',   tech: 'TypeScript', safe: true  },
  { pattern: 'tsconfig.tsbuildinfo', label: 'TS Build Info',           tech: 'TypeScript', safe: true  },
  // Misc
  { pattern: '.DS_Store',             label: 'macOS DS_Store',          tech: 'macOS',      safe: true  },
  { pattern: 'Thumbs.db',            label: 'Windows Thumbnails',      tech: 'Windows',    safe: true  },
  { pattern: '.terraform',           label: 'Terraform Cache',         tech: 'Terraform',  safe: true  },
  { pattern: '.serverless',          label: 'Serverless Cache',        tech: 'Serverless', safe: true  },
];

export class CacheManager {
  constructor(_context: vscode.ExtensionContext) {}

  async scanAll(): Promise<CacheItem[]> {
    const [project, ide] = await Promise.all([
      this.scanProject(),
      this.scanIDE(),
    ]);
    return [...project, ...ide];
  }

  async scanProject(): Promise<CacheItem[]> {
    const items: CacheItem[] = [];
    const workspaceFolders = vscode.workspace.workspaceFolders;
    if (!workspaceFolders) { return items; }

    const config = vscode.workspace.getConfiguration('limpacache');
    const excludePatterns = config.get<string[]>('excludePatterns', []);
    const customPaths = config.get<string[]>('customCachePaths', []);

    const patterns = [...PROJECT_CACHE_PATTERNS];
    for (const cp of customPaths) {
      patterns.push({ pattern: cp, label: path.basename(cp), tech: 'Custom', safe: true });
    }

    for (const folder of workspaceFolders) {
      for (const p of patterns) {
        const fullPath = path.join(folder.uri.fsPath, p.pattern);
        if (excludePatterns.some(ep => fullPath.includes(ep))) { continue; }
        if (fs.existsSync(fullPath)) {
          const size = await this.getDirSize(fullPath);
          if (size > 0) {
            items.push({
              id: Buffer.from(fullPath).toString('base64'),
              label: p.label,
              description: fullPath.replace(folder.uri.fsPath + path.sep, ''),
              fullPath,
              sizeBytes: size,
              category: 'project',
              technology: p.tech,
              safe: p.safe,
              selected: p.safe,
            });
          }
        }
      }
    }
    return items;
  }

  async scanIDE(): Promise<CacheItem[]> {
    const items: CacheItem[] = [];
    for (const entry of this.getIDECachePaths()) {
      if (fs.existsSync(entry.fullPath)) {
        const size = await this.getDirSize(entry.fullPath);
        if (size > 0) {
          items.push({
            id: Buffer.from(entry.fullPath).toString('base64'),
            label: entry.label,
            description: entry.fullPath.replace(os.homedir(), '~'),
            fullPath: entry.fullPath,
            sizeBytes: size,
            category: 'ide',
            technology: entry.tech,
            safe: true,
            selected: true,
          });
        }
      }
    }
    return items;
  }

  private getIDECachePaths(): Array<{ label: string; fullPath: string; tech: string }> {
    const home = os.homedir();
    const appData = process.env['APPDATA'] || path.join(home, 'AppData', 'Roaming');
    const localAppData = process.env['LOCALAPPDATA'] || path.join(home, 'AppData', 'Local');
    const platform = process.platform;
    const result: Array<{ label: string; fullPath: string; tech: string }> = [];

    if (platform === 'win32') {
      result.push({ label: 'VS Code Cache',             fullPath: path.join(appData, 'Code', 'Cache'),                    tech: 'VS Code'   });
      result.push({ label: 'VS Code CachedData',        fullPath: path.join(appData, 'Code', 'CachedData'),               tech: 'VS Code'   });
      result.push({ label: 'VS Code CachedExtensions',  fullPath: path.join(appData, 'Code', 'CachedExtensionVSIXs'),     tech: 'VS Code'   });
      result.push({ label: 'VS Code Logs',              fullPath: path.join(appData, 'Code', 'logs'),                     tech: 'VS Code'   });
      result.push({ label: 'JetBrains Cache',           fullPath: path.join(localAppData, 'JetBrains'),                   tech: 'JetBrains' });
      result.push({ label: 'npm Global Cache',          fullPath: path.join(localAppData, 'npm-cache'),                   tech: 'npm'       });
      result.push({ label: 'pip Cache',                 fullPath: path.join(localAppData, 'pip', 'cache'),                tech: 'pip'       });
    } else if (platform === 'darwin') {
      const lib = path.join(home, 'Library');
      result.push({ label: 'VS Code Cache',      fullPath: path.join(lib, 'Application Support', 'Code', 'Cache'),       tech: 'VS Code' });
      result.push({ label: 'VS Code CachedData', fullPath: path.join(lib, 'Application Support', 'Code', 'CachedData'), tech: 'VS Code' });
      result.push({ label: 'VS Code Logs',       fullPath: path.join(lib, 'Application Support', 'Code', 'logs'),       tech: 'VS Code' });
      result.push({ label: 'npm Cache',          fullPath: path.join(home, '.npm'),                                      tech: 'npm'     });
      result.push({ label: 'pip Cache',          fullPath: path.join(lib, 'Caches', 'pip'),                              tech: 'pip'     });
      result.push({ label: 'Yarn Cache',         fullPath: path.join(lib, 'Caches', 'Yarn'),                             tech: 'Yarn'    });
    } else {
      const cfg   = process.env['XDG_CONFIG_HOME'] || path.join(home, '.config');
      const cache = process.env['XDG_CACHE_HOME']  || path.join(home, '.cache');
      result.push({ label: 'VS Code Cache',      fullPath: path.join(cfg, 'Code', 'Cache'),      tech: 'VS Code' });
      result.push({ label: 'VS Code CachedData', fullPath: path.join(cfg, 'Code', 'CachedData'), tech: 'VS Code' });
      result.push({ label: 'VS Code Logs',       fullPath: path.join(cfg, 'Code', 'logs'),       tech: 'VS Code' });
      result.push({ label: 'npm Cache',          fullPath: path.join(cache, 'npm'),              tech: 'npm'     });
      result.push({ label: 'pip Cache',          fullPath: path.join(cache, 'pip'),              tech: 'pip'     });
      result.push({ label: 'Yarn Cache',         fullPath: path.join(cache, 'yarn'),             tech: 'Yarn'    });
    }
    return result;
  }

  async cleanItems(items: CacheItem[]): Promise<CleanResult> {
    const result: CleanResult = { cleaned: 0, failed: 0, freedBytes: 0, errors: [] };
    for (const item of items) {
      try {
        if (!fs.existsSync(item.fullPath)) { continue; }
        const size = item.sizeBytes;
        const stat = fs.statSync(item.fullPath);
        if (stat.isDirectory()) {
          const lockedFiles = await this.removeDirectorySafe(item.fullPath);
          if (lockedFiles.length === 0) {
            result.cleaned++;
            result.freedBytes += size;
          } else {
            result.failed++;
            lockedFiles.forEach(e => result.errors.push(`${item.label} — ${e}`));
          }
        } else {
          await this.removeFileSafe(item.fullPath);
          result.cleaned++;
          result.freedBytes += size;
        }
      } catch (err) {
        result.failed++;
        result.errors.push(`${item.label}: ${this.describeError(err)}`);
      }
    }
    return result;
  }

  /**
   * Tenta deletar um diretório inteiro. No Windows, se falhar por arquivo em uso,
   * faz uma nova tentativa após 200ms e, se ainda falhar, deleta arquivo por arquivo
   * pulando os que estão bloqueados. Retorna lista de arquivos que não puderam ser removidos.
   */
  private async removeDirectorySafe(dirPath: string): Promise<string[]> {
    try {
      fs.rmSync(dirPath, { recursive: true, force: true });
      return [];
    } catch (err: any) {
      if (process.platform !== 'win32') { throw err; }
      if (!['EBUSY', 'EPERM', 'EACCES'].includes(err.code)) { throw err; }
      // Aguarda e tenta novamente — alguns locks são momentâneos
      await new Promise(r => setTimeout(r, 200));
      try {
        fs.rmSync(dirPath, { recursive: true, force: true });
        return [];
      } catch {
        // Ainda bloqueado: deleta arquivo por arquivo, pulando os travados
        return this.removeContentsFileByFile(dirPath);
      }
    }
  }

  /**
   * Remove o conteúdo de um diretório arquivo por arquivo, pulando arquivos em uso.
   * Retorna a lista de arquivos que não puderam ser removidos.
   */
  private removeContentsFileByFile(dirPath: string): string[] {
    const locked: string[] = [];
    try {
      const entries = fs.readdirSync(dirPath, { withFileTypes: true });
      for (const entry of entries) {
        const full = path.join(dirPath, entry.name);
        try {
          if (entry.isDirectory()) {
            const sub = this.removeContentsFileByFile(full);
            locked.push(...sub);
            try { fs.rmdirSync(full); } catch { /* ainda tem arquivos travados dentro */ }
          } else {
            fs.unlinkSync(full);
          }
        } catch (err: any) {
          if (['EBUSY', 'EPERM', 'EACCES'].includes(err.code)) {
            locked.push(`${entry.name} (em uso pelo sistema)`);
          }
          // outros erros: pula silenciosamente
        }
      }
    } catch { /* não conseguiu listar o diretório */ }
    try { fs.rmdirSync(dirPath); } catch { /* ignora se ainda não está vazio */ }
    return locked;
  }

  /** Tenta remover um arquivo; no Windows faz uma tentativa extra após 200ms se travar. */
  private async removeFileSafe(filePath: string): Promise<void> {
    try {
      fs.unlinkSync(filePath);
    } catch (err: any) {
      if (process.platform === 'win32' && ['EBUSY', 'EPERM'].includes(err.code)) {
        await new Promise(r => setTimeout(r, 200));
        fs.unlinkSync(filePath);
      } else {
        throw err;
      }
    }
  }

  /** Traduz códigos de erro do SO para mensagens em português. */
  private describeError(err: unknown): string {
    if (!(err instanceof Error)) { return String(err); }
    const e = err as NodeJS.ErrnoException;
    switch (e.code) {
      case 'EACCES':    return 'sem permissão de acesso';
      case 'EPERM':     return 'operação não permitida (arquivo protegido pelo sistema)';
      case 'EBUSY':     return 'em uso pelo sistema';
      case 'ENOTEMPTY': return 'diretório não está vazio';
      case 'ENOENT':    return 'arquivo não encontrado';
      default:          return e.message;
    }
  }

  async getTotalCacheSize(): Promise<number> {
    try {
      const items = await this.scanAll();
      return items.reduce((s, i) => s + i.sizeBytes, 0);
    } catch {
      return 0;
    }
  }

  async getDirSize(dirPath: string): Promise<number> {
    try {
      const stat = fs.statSync(dirPath);
      if (stat.isFile()) { return stat.size; }
      return this.calcSize(dirPath, 0);
    } catch {
      return 0;
    }
  }

  private calcSize(dirPath: string, depth: number): number {
    if (depth > 8) { return 0; }
    let total = 0;
    try {
      for (const entry of fs.readdirSync(dirPath, { withFileTypes: true })) {
        if (entry.isSymbolicLink()) { continue; }
        const full = path.join(dirPath, entry.name);
        if (entry.isFile()) {
          try { total += fs.statSync(full).size; } catch { /* skip */ }
        } else if (entry.isDirectory()) {
          total += this.calcSize(full, depth + 1);
        }
      }
    } catch { /* not accessible */ }
    return total;
  }

  getProjectStructureSummary(): string {
    const folders = vscode.workspace.workspaceFolders;
    if (!folders) { return 'No workspace open'; }
    const lines: string[] = [];
    for (const folder of folders) {
      lines.push(`Workspace: ${folder.name} (${folder.uri.fsPath})`);
      try {
        const entries = fs.readdirSync(folder.uri.fsPath, { withFileTypes: true });
        lines.push(...entries.slice(0, 30).map(e => `  ${e.isDirectory() ? '[dir]' : '[file]'} ${e.name}`));
        if (entries.length > 30) { lines.push(`  ... and ${entries.length - 30} more`); }
      } catch {
        lines.push('  (cannot read directory)');
      }
    }
    return lines.join('\n');
  }
}
