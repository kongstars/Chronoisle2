#!/usr/bin/env node
/**
 * Add .align(Alignment.Top) to Scroll components that don't already have alignment set.
 * This fixes the issue where Scroll vertically centers content when content is shorter than viewport.
 *
 * Pattern to match:
 *   Scroll() { ... }
 *   .scrollBar(...)  // or any other modifier
 *   .width('100%')
 *
 * Insert .align(Alignment.Top) before .scrollBar() if no .align() exists yet.
 */

import { readFileSync, writeFileSync, readdirSync, statSync } from 'fs';
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

let totalChanged = 0;
let totalFiles = 0;

for (const file of findEtsFiles(ROOT)) {
  let content = readFileSync(file, 'utf8');
  const original = content;
  const lines = content.split('\n');
  const result = [];
  let i = 0;
  let fileChanges = 0;

  while (i < lines.length) {
    const line = lines[i];
    result.push(line);

    // Detect Scroll() { line
    if (/^\s*Scroll\(\)\s*\{/.test(line)) {
      // Find the matching closing brace, then look for modifiers after it
      let braceCount = 1;
      let j = i + 1;
      const startIndent = line.match(/^(\s*)/)[1];

      while (j < lines.length && braceCount > 0) {
        const next = lines[j];
        for (const c of next) {
          if (c === '{') braceCount++;
          else if (c === '}') braceCount--;
        }
        if (braceCount === 0) break;
        j++;
      }

      // j now points to the closing }
      // Look at modifier lines after the closing brace
      let k = j + 1;
      const modifierLines = [];
      let hasAlign = false;
      let firstModifierIdx = -1;

      // Capture all subsequent .xxx() chained methods (more indented than start)
      while (k < lines.length) {
        const candidate = lines[k];
        const trimmed = candidate.trim();
        // Stop if line is empty, has same/lower indentation closing block, or starts with non-modifier
        if (trimmed === '') break;
        if (!trimmed.startsWith('.')) break;

        if (/^\.align\(/.test(trimmed)) {
          hasAlign = true;
        }
        if (firstModifierIdx === -1) {
          firstModifierIdx = k;
        }
        modifierLines.push(k);
        k++;
      }

      // Only process if Scroll has at least one modifier AND no .align()
      if (!hasAlign && firstModifierIdx !== -1) {
        // We will copy lines up to (but not including) the first modifier,
        // then insert .align(Alignment.Top), then continue.
        // First, we already added "line" (Scroll() {). Now add lines i+1 .. firstModifierIdx-1
        for (let m = i + 1; m < firstModifierIdx; m++) {
          result.push(lines[m]);
        }
        // Determine indentation of modifier lines
        const modIndent = lines[firstModifierIdx].match(/^(\s*)/)[1];
        result.push(`${modIndent}.align(Alignment.Top)`);
        // Skip ahead, don't double-add
        i = firstModifierIdx;
        fileChanges++;
        continue;
      }
    }

    i++;
  }

  if (fileChanges > 0) {
    content = result.join('\n');
    if (content !== original) {
      writeFileSync(file, content, 'utf8');
      console.log(`  ${file}: ${fileChanges} Scroll(s) patched`);
      totalChanged += fileChanges;
      totalFiles++;
    }
  }
}

console.log(`\nTotal: ${totalChanged} Scroll components patched across ${totalFiles} files`);
