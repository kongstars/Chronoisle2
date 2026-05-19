#!/usr/bin/env node
/**
 * 删除 pages / components 中已不再使用的 router / promptAction 默认 import。
 *
 * 目的：deprecated API 已经迁移到 this.getUIContext().getRouter() / getPromptAction()，
 *       原来 `import router from '@ohos.router'` / `import promptAction from '@ohos.promptAction'`
 *       变成未使用 import，需要删除以避免 unused import 警告。
 *
 * 安全规则：
 *   - 只删除满足"该标识符在文件中除 import 行外没有任何其它出现"的 import。
 *   - 跳过 services / entryability / Utils 等非 UI 目录（那些文件仍然在用 router/promptAction）。
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

const TARGETS = [
  { name: 'router', importRegex: /^import\s+router\s+from\s+['"]@ohos\.router['"];?\s*$/m },
  { name: 'promptAction', importRegex: /^import\s+promptAction\s+from\s+['"]@ohos\.promptAction['"];?\s*$/m }
];

function isIdentifierUsedElsewhere(text, identifier, importLineMatch) {
  // 把 import 行删掉，再看剩下的代码是否还引用这个标识符。
  const stripped = text.slice(0, importLineMatch.index) + text.slice(importLineMatch.index + importLineMatch[0].length);
  const usePattern = new RegExp(`\\b${identifier}\\b`);
  return usePattern.test(stripped);
}

function transform(text) {
  let mutated = text;
  const removed = [];

  for (const target of TARGETS) {
    const match = mutated.match(target.importRegex);
    if (!match) continue;
    if (isIdentifierUsedElsewhere(mutated, target.name, match)) continue;

    const before = mutated.slice(0, match.index);
    const after = mutated.slice(match.index + match[0].length);
    // 顺便吃掉这一行后紧随的换行，避免留下空行
    mutated = before + after.replace(/^\r?\n/, '');
    removed.push(target.name);
  }

  return { text: mutated, removed };
}

async function main() {
  const files = [];
  for (const dir of TARGET_DIRS) {
    await walk(dir, files);
  }

  let touched = 0;
  let totalRemovals = 0;
  for (const file of files) {
    const text = await fs.readFile(file, 'utf8');
    const { text: next, removed } = transform(text);
    if (removed.length === 0) continue;
    touched += 1;
    totalRemovals += removed.length;
    const rel = path.relative(repoRoot, file);
    process.stdout.write(`${apply ? 'WRITE' : 'PREVIEW'} ${rel}  (removed: ${removed.join(', ')})\n`);
    if (apply) {
      await fs.writeFile(file, next, 'utf8');
    }
  }
  process.stdout.write(`\n${apply ? 'APPLIED' : 'PREVIEWED'}: ${totalRemovals} removals across ${touched} files\n`);
  if (!apply) {
    process.stdout.write('Re-run with --apply to write changes.\n');
  }
}

main().catch((err) => {
  process.stderr.write(`failed: ${err?.message || err}\n`);
  process.exit(1);
});
