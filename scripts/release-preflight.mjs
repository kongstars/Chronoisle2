#!/usr/bin/env node
/**
 * Release 发布前自检脚本
 *
 * 在打 Release 包之前运行：
 *   node scripts/release-preflight.mjs
 *
 * 检查项：
 *  1. build-profile.json5 release 签名是否仍含 TODO 占位符。
 *  2. AppConfig 中 mock 开关是否全部为 false。
 *  3. 备案信息（ComplianceInfo）是否已填写完成。
 *  4. 全代码扫描是否有遗留 TODO/FIXME/MOCK 标记。
 *  5. 全代码扫描是否有 console.log/info（业务调试日志，应改为 Logger）。
 *
 * 任意一项失败时整体退出码非 0，方便 CI 拦截发布。
 */

import { promises as fs } from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..');

const ANSI = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  bold: '\x1b[1m'
};

const issues = [];
const passes = [];

function pass(label) {
  passes.push(label);
}

function fail(label, detail) {
  issues.push({ label, detail });
}

async function readText(relativePath) {
  return fs.readFile(path.join(repoRoot, relativePath), 'utf8');
}

async function fileExists(relativePath) {
  try {
    await fs.stat(path.join(repoRoot, relativePath));
    return true;
  } catch {
    return false;
  }
}

async function checkReleaseSigning() {
  const file = 'build-profile.json5';
  if (!await fileExists(file)) {
    fail('Release 签名', `${file} 不存在`);
    return;
  }
  const text = await readText(file);
  const releaseBlockMatch = text.match(/"name":\s*"release"[\s\S]*?\}\s*\}/);
  if (!releaseBlockMatch) {
    fail('Release 签名', '未在 build-profile.json5 中找到 release signingConfig 块');
    return;
  }
  const releaseBlock = releaseBlockMatch[0];
  if (releaseBlock.includes('TODO')) {
    fail('Release 签名', 'build-profile.json5 release signingConfig 仍含 TODO 占位');
    return;
  }
  pass('Release 签名占位已替换');
}

async function checkMockSwitches() {
  const file = 'entry/src/main/ets/Utils/AppConfig.ets';
  const text = await readText(file);
  const matches = [...text.matchAll(/(MOCK_[A-Z0-9_]+)\s*:\s*boolean\s*=\s*(true|false)/g)];
  if (matches.length === 0) {
    pass('未发现 mock 开关');
    return;
  }
  const enabled = matches.filter(([, , value]) => value === 'true');
  if (enabled.length > 0) {
    fail('Mock 开关', `以下 mock 开关仍开启: ${enabled.map(m => m[1]).join(', ')}`);
    return;
  }
  pass(`Mock 开关全部关闭 (${matches.length} 项)`);
}

async function checkComplianceInfo() {
  const file = 'entry/src/main/ets/common/ComplianceInfo.ets';
  if (!await fileExists(file)) {
    fail('备案信息', `${file} 不存在`);
    return;
  }
  const text = await readText(file);
  const placeholderMatches = [...text.matchAll(/(\w+):\s*string\s*=\s*'(【待填写[^']*)'/g)];
  if (placeholderMatches.length > 0) {
    const fields = placeholderMatches.map(m => m[1]).join(', ');
    fail('备案信息', `ComplianceInfo 中以下字段仍为占位: ${fields}`);
    return;
  }
  pass('备案信息已全部填写');
}

const SOURCE_GLOBS = [
  'entry/src/main/ets',
  'entry/src/main/resources/base/profile'
];

async function walk(dir, accumulator) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      await walk(full, accumulator);
    } else if (/\.(ets|ts|json|json5)$/.test(entry.name)) {
      accumulator.push(full);
    }
  }
}

async function listSourceFiles() {
  const files = [];
  for (const dir of SOURCE_GLOBS) {
    const abs = path.join(repoRoot, dir);
    if (await fileExists(dir)) {
      await walk(abs, files);
    }
  }
  return files;
}

async function checkResidualTodos(files) {
  const hits = [];
  for (const file of files) {
    const text = await fs.readFile(file, 'utf8');
    const lines = text.split(/\r?\n/);
    lines.forEach((line, index) => {
      // 只匹配注释或独立短语形式的 TODO/FIXME，避免误伤枚举值（如 TODO = 'widget_todo'）
      if (/(^|\s)\/\/\s*(TODO|FIXME|XXX|HACK)\b/.test(line) || /\/\*+[^*]*\b(TODO|FIXME|XXX|HACK)\b/.test(line)) {
        hits.push(`${path.relative(repoRoot, file)}:${index + 1} ${line.trim().slice(0, 120)}`);
      }
    });
  }
  if (hits.length > 0) {
    fail('遗留 TODO/FIXME', `共 ${hits.length} 处:\n${hits.slice(0, 20).map(h => '  - ' + h).join('\n')}${hits.length > 20 ? `\n  ...` : ''}`);
    return;
  }
  pass('代码中无 TODO/FIXME 注释残留');
}

async function checkConsoleDebug(files) {
  const hits = [];
  for (const file of files) {
    if (file.includes('Logger.ets')) {
      continue;
    }
    const text = await fs.readFile(file, 'utf8');
    const lines = text.split(/\r?\n/);
    lines.forEach((line, index) => {
      if (/console\.(log|info|debug)\s*\(/.test(line)) {
        hits.push(`${path.relative(repoRoot, file)}:${index + 1}`);
      }
    });
  }
  if (hits.length > 0) {
    fail('console.log/info 残留', `共 ${hits.length} 处。Release 包应使用 Logger 工具统一收敛业务调试日志:\n${hits.slice(0, 20).map(h => '  - ' + h).join('\n')}${hits.length > 20 ? `\n  ...` : ''}`);
    return;
  }
  pass('代码中无 console.log/info 残留');
}

async function main() {
  const startedAt = Date.now();
  process.stdout.write(`${ANSI.bold}${ANSI.cyan}▶ Release 发布前自检${ANSI.reset}\n`);

  await checkReleaseSigning();
  await checkMockSwitches();
  await checkComplianceInfo();

  const files = await listSourceFiles();
  await checkResidualTodos(files);
  await checkConsoleDebug(files);

  const duration = Date.now() - startedAt;
  process.stdout.write('\n');

  for (const ok of passes) {
    process.stdout.write(`${ANSI.green}  ✓${ANSI.reset} ${ok}\n`);
  }

  if (issues.length === 0) {
    process.stdout.write(`\n${ANSI.green}${ANSI.bold}全部检查通过${ANSI.reset}（耗时 ${duration} ms）\n`);
    process.exit(0);
  }

  process.stdout.write('\n');
  for (const issue of issues) {
    process.stdout.write(`${ANSI.red}  ✗${ANSI.reset} ${ANSI.bold}${issue.label}${ANSI.reset}\n`);
    if (issue.detail) {
      const lines = issue.detail.split(/\r?\n/);
      for (const line of lines) {
        process.stdout.write(`     ${line}\n`);
      }
    }
  }
  process.stdout.write(`\n${ANSI.red}${ANSI.bold}存在 ${issues.length} 项问题，请处理后再发布。${ANSI.reset}\n`);
  process.exit(1);
}

main().catch((error) => {
  process.stdout.write(`${ANSI.red}preflight 脚本运行失败: ${error?.message || error}${ANSI.reset}\n`);
  process.exit(2);
});
