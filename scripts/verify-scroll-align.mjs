#!/usr/bin/env node
/**
 * Verify all Scroll components in the codebase have an alignment set.
 * Reports any Scroll missing .align()
 */

import { readFileSync, readdirSync, statSync } from 'fs';
import { join, extname } from 'path';

const ROOT = 'entry/src/main/ets';
const EXCLUDED_DIRS = new Set(['node_modules', 'oh_modules', 'build']);

function findEtsFiles(dir, list = []) {
  for (const entry of readdirSync(dir)) {
    if (EXCLUDED_DIRS.has(entry)) continue;
    const full = join(dir, entry);
    const stats = statSync(full);
    if (stats.isDirectory()) {
      findEtsFiles(full, list);
    } else if (extname(full) === '.ets') {
      list.push(full);
    }
  }
  return list;
}

let totalScrolls = 0;
let missingAlign = 0;

for (const file of findEtsFiles(ROOT)) {
  const content = readFileSync(file, 'utf8');
  const lines = content.split('\n');

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!/^\s*Scroll\s*\(/.test(line)) continue;
    if (!line.includes('{')) continue;

    totalScrolls++;

    // Find matching closing brace
    let braceCount = 0;
    let started = false;
    let j = i;

    while (j < lines.length) {
      for (const c of lines[j]) {
        if (c === '{') {
          braceCount++;
          started = true;
        } else if (c === '}') {
          braceCount--;
          if (started && braceCount === 0) break;
        }
      }
      if (started && braceCount === 0) break;
      j++;
    }

    // Look at modifier chain after closing
    let k = j + 1;
    let hasAlign = false;
    let modifierLines = [];

    while (k < lines.length) {
      const candidate = lines[k];
      const trimmed = candidate.trim();
      if (trimmed === '') break;
      if (!trimmed.startsWith('.')) break;
      modifierLines.push(trimmed);
      if (/^\.align\(/.test(trimmed)) {
        hasAlign = true;
      }
      k++;
    }

    if (!hasAlign) {
      missingAlign++;
      console.log(`${file}:${i + 1} Scroll missing .align()`);
      console.log(`  modifiers: ${modifierLines.join(' ')}`);
    }
  }
}

console.log(`\n${totalScrolls} total Scroll(s), ${missingAlign} missing .align()`);
