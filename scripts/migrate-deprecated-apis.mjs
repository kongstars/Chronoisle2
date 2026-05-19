#!/usr/bin/env node
/**
 * 批量迁移 ArkTS 中已废弃 API 到 UIContext 写法。
 *
 * 处理对象：仅 entry/src/main/ets/pages 和 entry/src/main/ets/components 下含 struct 的 .ets 文件。
 * services / entryability / Utils 等非 UI 文件不动（它们没有 this.getUIContext() 入口）。
 *
 * 替换规则：
 *   router.pushUrl(...)         → this.getUIContext().getRouter().pushUrl(...)
 *   router.replaceUrl(...)      → this.getUIContext().getRouter().replaceUrl(...)
 *   router.back(...)            → this.getUIContext().getRouter().back(...)
 *   router.getParams(...)       → this.getUIContext().getRouter().getParams(...)
 *   promptAction.showToast(...) → this.getUIContext().getPromptAction().showToast(...)
 *   promptAction.showDialog(...)→ this.getUIContext().getPromptAction().showDialog(...)
 *   promptAction.showActionMenu → this.getUIContext().getPromptAction().showActionMenu(...)
 *   getContext(this)            → (this.getUIContext().getHostContext() as Context)
 *
 * 用法：
 *   node scripts/migrate-deprecated-apis.mjs           # 预览
 *   node scripts/migrate-deprecated-apis.mjs --apply   # 实际写入
 */

import { promises as fs } from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..');
const apply = process.argv.includes('--apply');

const TARGET_DIRS = [
  path.join(repoRoot, 'entry/src/main/ets/pages'),
  path.join(repoRoot, 'entry/src/main/ets/components')
];

const ANSI = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  bold: '\x1b[1m'
};

async function walk(dir, accumulator) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      await walk(full, accumulator);
    } else if (entry.name.endsWith('.ets')) {
      accumulator.push(full);
    }
  }
}

const REPLACEMENTS = [
  {
    label: 'router.pushUrl',
    pattern: /\brouter\.pushUrl\(/g,
    replacement: 'this.getUIContext().getRouter().pushUrl('
  },
  {
    label: 'router.replaceUrl',
    pattern: /\brouter\.replaceUrl\(/g,
    replacement: 'this.getUIContext().getRouter().replaceUrl('
  },
  {
    label: 'router.back',
    pattern: /\brouter\.back\(/g,
    replacement: 'this.getUIContext().getRouter().back('
  },
  {
    label: 'router.getParams',
    pattern: /\brouter\.getParams\(/g,
    replacement: 'this.getUIContext().getRouter().getParams('
  },
  {
    label: 'promptAction.showToast',
    pattern: /\bpromptAction\.showToast\(/g,
    replacement: 'this.getUIContext().getPromptAction().showToast('
  },
  {
    label: 'promptAction.showDialog',
    pattern: /\bpromptAction\.showDialog\(/g,
    replacement: 'this.getUIContext().getPromptAction().showDialog('
  },
  {
    label: 'promptAction.showActionMenu',
    pattern: /\bpromptAction\.showActionMenu\(/g,
    replacement: 'this.getUIContext().getPromptAction().showActionMenu('
  },
  {
    label: 'getContext(this)',
    pattern: /\bgetContext\(this\)/g,
    replacement: '(this.getUIContext().getHostContext() as Context)'
  }
];

function transform(text, fileLabel) {
  // 仅对包含 struct 关键字的 ArkUI 组件文件生效。
  if (!/\bstruct\s+\w+\s*\{/.test(text)) {
    return { text, count: 0, perRule: {} };
  }

  let mutated = text;
  let total = 0;
  const perRule = {};

  for (const rule of REPLACEMENTS) {
    const before = mutated;
    let count = 0;
    mutated = mutated.replace(rule.pattern, (match) => {
      count += 1;
      return rule.replacement;
    });
    if (count > 0) {
      perRule[rule.label] = count;
      total += count;
    }
    if (before !== mutated) {
      // continue
    }
  }

  return { text: mutated, count: total, perRule };
}

async function main() {
  const files = [];
  for (const dir of TARGET_DIRS) {
    await walk(dir, files);
  }

  let touchedFiles = 0;
  let totalReplacements = 0;
  const ruleTotals = {};

  for (const file of files) {
    const text = await fs.readFile(file, 'utf8');
    const rel = path.relative(repoRoot, file);
    const { text: next, count, perRule } = transform(text, rel);
    if (count === 0) continue;

    touchedFiles += 1;
    totalReplacements += count;
    for (const k of Object.keys(perRule)) {
      ruleTotals[k] = (ruleTotals[k] || 0) + perRule[k];
    }

    const summary = Object.keys(perRule).map(k => `${k}×${perRule[k]}`).join(', ');
    process.stdout.write(`${apply ? 'WRITE' : 'PREVIEW'} ${rel}  (${summary})\n`);

    if (apply) {
      await fs.writeFile(file, next, 'utf8');
    }
  }

  process.stdout.write('\n');
  for (const rule of Object.keys(ruleTotals)) {
    process.stdout.write(`  ${rule}: ${ruleTotals[rule]}\n`);
  }
  process.stdout.write(`\n${ANSI.bold}${apply ? 'APPLIED' : 'PREVIEWED'}: ${totalReplacements} replacements across ${touchedFiles} files${ANSI.reset}\n`);
  if (!apply) {
    process.stdout.write('Re-run with --apply to write changes.\n');
  }
}

main().catch((err) => {
  process.stderr.write(`migrate-deprecated-apis failed: ${err?.message || err}\n`);
  process.exit(1);
});
