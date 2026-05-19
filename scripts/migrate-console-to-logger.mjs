#!/usr/bin/env node
/**
 * 批量迁移 console.error / console.warn 到 Logger 工具。
 *
 * 处理规则：
 *  - 只针对 entry/src/main/ets 下的 .ets 文件。
 *  - 自动跳过 Utils/Logger.ets（避免循环引用）。
 *  - 文件首次出现 console.error/warn 时，根据文件名生成 logger 实例。
 *  - 替换以下两类常见模式：
 *      console.error('msg', ...args)  → logger.error('msg', ...)
 *      console.error('msg:', JSON.stringify(e)) → logger.error('msg', e as Object)
 *  - 不改写已经在 Builder/UI 块中的 console（很少见，实际几乎没有）。
 *  - 不接管 console.log/info（已经在前一步迁移完了）。
 *
 * 用法：
 *   node scripts/migrate-console-to-logger.mjs           # 预览
 *   node scripts/migrate-console-to-logger.mjs --apply   # 实际写入
 */

import { promises as fs } from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..');
const apply = process.argv.includes('--apply');

const ROOT = path.join(repoRoot, 'entry/src/main/ets');

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

function deriveLoggerTag(absPath) {
  const base = path.basename(absPath, '.ets');
  return base;
}

function deriveLoggerImport(absPath) {
  const dir = path.dirname(absPath);
  const target = path.join(repoRoot, 'entry/src/main/ets/Utils/Logger.ets');
  let rel = path.relative(dir, target).replace(/\\/g, '/');
  if (!rel.startsWith('.')) rel = './' + rel;
  rel = rel.replace(/\.ets$/, '');
  return rel;
}

function alreadyHasLogger(text) {
  return /import\s+\{\s*Logger\s*\}\s+from\s+['"][^'"]+Logger['"];?/.test(text);
}

function alreadyDeclaresLogger(text) {
  return /\bconst\s+logger\s*[:=]/.test(text) || /private\s+logger\s*:?\s*Logger/.test(text);
}

function transformCalls(text) {
  let mutated = text;
  let count = 0;

  // 1. console.warn|error('msg:', JSON.stringify(e))  → logger.warn|error('msg', e as Object)
  const stringifyPattern = /console\.(error|warn)\(\s*(['"`])([^'"`]*?)['"`]\s*,\s*JSON\.stringify\(([^)]+)\)\s*\)/g;
  mutated = mutated.replace(stringifyPattern, (full, level, _q, msg, target) => {
    count++;
    const cleanMsg = msg.replace(/[:\s]+$/, '').trim();
    return `logger.${level}('${escapeSingle(cleanMsg)}', ${target.trim()} as Object)`;
  });

  // 2. console.warn|error('msg', e) → logger.warn|error('msg', e as Object)
  const simpleArgPattern = /console\.(error|warn)\(\s*(['"`])([^'"`]+)\2\s*,\s*([^)]+?)\s*\)(\s*[;\)\n])/g;
  mutated = mutated.replace(simpleArgPattern, (full, level, _q, msg, arg, tail) => {
    if (arg.includes('JSON.stringify')) {
      // 已被上一步处理或后续 fallback 处理
      return full;
    }
    count++;
    return `logger.${level}('${escapeSingle(msg)}', ${arg.trim()} as Object)${tail}`;
  });

  // 3. console.warn|error('msg') → logger.warn|error('msg')
  const onlyMsgPattern = /console\.(error|warn)\(\s*(['"`])([^'"`]*?)\2\s*\)/g;
  mutated = mutated.replace(onlyMsgPattern, (full, level, _q, msg) => {
    count++;
    return `logger.${level}('${escapeSingle(msg)}')`;
  });

  // 4. console.warn|error(`tpl`)  → logger.warn|error(`tpl`)
  const templatePattern = /console\.(error|warn)\(\s*(`[^`]*`)\s*\)/g;
  mutated = mutated.replace(templatePattern, (full, level, tpl) => {
    count++;
    return `logger.${level}(${tpl})`;
  });

  // 5. console.warn|error(`tpl`, JSON.stringify(e)) 或 (`tpl`, e)
  const templateWithArgPattern = /console\.(error|warn)\(\s*(`[^`]*`)\s*,\s*([^)]+?)\s*\)/g;
  mutated = mutated.replace(templateWithArgPattern, (full, level, tpl, arg) => {
    count++;
    if (arg.includes('JSON.stringify')) {
      const inner = arg.match(/JSON\.stringify\(([^)]+)\)/);
      if (inner) {
        return `logger.${level}(${tpl}, ${inner[1].trim()} as Object)`;
      }
    }
    return `logger.${level}(${tpl}, ${arg.trim()} as Object)`;
  });

  return { text: mutated, count };
}

function escapeSingle(s) {
  return s.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

function ensureLoggerHeader(text, absPath) {
  if (alreadyHasLogger(text) && alreadyDeclaresLogger(text)) {
    return text;
  }

  const tag = deriveLoggerTag(absPath);
  const importPath = deriveLoggerImport(absPath);

  const importLine = `import { Logger } from '${importPath}';`;
  const declLine = `const logger = Logger.create('${tag}');`;

  // ArkTS 严格规则 `arkts-no-misplaced-imports` 要求所有 import 必须连续。
  // 因此必须把新的 `import { Logger }` + `const logger` 放在所有 import 之后。
  // 用 token 解析找到「最后一条 import 语句」的结束行号：
  //   - 单行：`import xxx from '...';`
  //   - 多行：`import {\n  ... \n} from '...';` —— 必须扫到匹配的 `} from '...'` 行
  const lines = text.split(/\r?\n/);
  let lastImportEndIdx = -1;
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    const trimmed = line.trim();
    if (/^import\b/.test(trimmed)) {
      if (/\{\s*$/.test(trimmed) && !/from\s+['"]/.test(trimmed)) {
        // 多行 import 块
        let j = i + 1;
        let blockEnd = -1;
        while (j < lines.length) {
          if (/^\}\s*from\s+['"][^'"]+['"]\s*;?\s*$/.test(lines[j].trim())) {
            blockEnd = j;
            break;
          }
          j += 1;
        }
        if (blockEnd !== -1) {
          lastImportEndIdx = blockEnd;
          i = blockEnd + 1;
        } else {
          i += 1;
        }
      } else {
        lastImportEndIdx = i;
        i += 1;
      }
    } else {
      // 非 import 行（空行、注释或代码）：继续向后扫，可能后面还有 import。
      i += 1;
    }
  }

  if (lastImportEndIdx === -1) {
    // 文件没有 import，放最前面
    lines.unshift('');
    lines.unshift(declLine);
    lines.unshift('');
    lines.unshift(importLine);
  } else {
    const insertAt = lastImportEndIdx + 1;
    if (alreadyHasLogger(text)) {
      lines.splice(insertAt, 0, '', declLine);
    } else if (alreadyDeclaresLogger(text)) {
      lines.splice(insertAt, 0, importLine);
    } else {
      lines.splice(insertAt, 0, importLine, '', declLine);
    }
  }

  return lines.join('\n');
}

async function main() {
  const files = [];
  await walk(ROOT, files);

  const skip = new Set([
    path.join(ROOT, 'Utils/Logger.ets')
  ]);

  let totalFiles = 0;
  let totalReplacements = 0;
  for (const file of files) {
    if (skip.has(file)) continue;
    const text = await fs.readFile(file, 'utf8');
    if (!/console\.(error|warn)/.test(text)) continue;

    let next = text;
    if (!alreadyDeclaresLogger(next) || !alreadyHasLogger(next)) {
      next = ensureLoggerHeader(next, file);
    }

    const { text: transformed, count } = transformCalls(next);
    if (count === 0 || transformed === text) continue;

    totalFiles += 1;
    totalReplacements += count;

    const rel = path.relative(repoRoot, file);
    process.stdout.write(`${apply ? 'WRITE' : 'PREVIEW'} ${rel} (${count} replacements)\n`);

    if (apply) {
      await fs.writeFile(file, transformed, 'utf8');
    }
  }

  process.stdout.write(`\n${apply ? 'APPLIED' : 'PREVIEWED'}: ${totalReplacements} replacements across ${totalFiles} files\n`);
  if (!apply) {
    process.stdout.write('Re-run with --apply to write changes.\n');
  }
}

main().catch((err) => {
  process.stderr.write(`migrate-console failed: ${err?.message || err}\n`);
  process.exit(1);
});
