# Chronoisle Icon Redesign V1

## 1. Purpose

This document is the first redesign proposal for the Chronoisle icon system. It aligns icon shape language, state behavior, and scene fit before implementation.

## 2. Core Direction

- Unify silhouette logic, stroke rhythm, corner handling, and visual balance.
- Keep most high-frequency icons neutral and restrained.
- Preserve controlled personality for a small set of scene-defining icons.
- Improve recognizability at small sizes first.
- Avoid changing layout to compensate for icon issues.

## 3. Visual Language

### 3.1 Shape

- rounded geometric base
- open, breathable negative space
- low complexity under `24`
- limited fill usage, mainly for selected states and core scene icons

### 3.2 Stroke

- small icons favor clarity over expressiveness
- operation icons keep even stroke rhythm
- business icons can add one memorable internal detail

### 3.3 Color Layering

- operations: neutral foreground
- semantic states: stable semantic colors
- special scenes: restrained accent groups

## 4. Priority

### P0

- `search`
- `close`
- `plus`
- `minus`
- `chevron-left`
- `chevron-right`
- `success`
- `warning`
- `task`
- `today`

### P1

- `goal`
- `reminder`
- `plan`
- `progress`
- `stats`
- `calendar`
- `focus`
- `ai`

### P2

- scene and environment icons
- personal and system icons
- widget-only support icons

## 5. Redraw Notes

| Icon | Direction | Color Strategy | Size Focus |
| --- | --- | --- | --- |
| `search` | balanced lens and shorter handle, cleaner at `16 / 24` | neutral | `16 / 24` |
| `close` | consistent diagonal spacing and rounded ends | neutral | `16 / 24` |
| `plus` | centered, even arm length, less aggressive | neutral | `16 / 24` |
| `minus` | slightly rounded line with exact optical centering | neutral | `16 / 24` |
| `chevron-left` | lighter, cleaner directional cue | neutral | `16 / 24` |
| `chevron-right` | lighter, cleaner directional cue | neutral | `16 / 24` |
| `success` | rounded check inside stable circular support | semantic green | `16 / 24 / 32` |
| `warning` | softer triangular mass or alert capsule | semantic amber | `16 / 24 / 32` |
| `task` | checklist-led, not document-led | neutral / active brand | `24 / 32` |
| `today` | calendar-first with one memorable day indicator | neutral / active brand | `24 / 32` |
| `goal` | target silhouette with stronger center clarity | neutral / active brand | `24 / 32` |
| `reminder` | bell with calmer top arc and crisper clapper | neutral | `24 / 32` |
| `plan` | layered blocks or route metaphor | neutral | `24 / 32` |
| `progress` | circular advance or segmented path | neutral / active brand | `24 / 32` |
| `stats` | bar shape with stronger proportion contrast | neutral | `24 / 32` |
| `calendar` | secondary calendar differing from `today` by detail emphasis | neutral | `24 / 32` |
| `focus` | more centered halo or target pulse | accent indigo | `24 / 32` |
| `ai` | sparkle-core hybrid, avoid generic robot look | accent cyan | `24 / 32` |

## 6. Tab Bar Rule

- Keep current layout unchanged.
- Only redraw icon graphics.
- For `today`, `action`, `goal`, `profile`:
  - unselected = outline-first
  - selected = same skeleton with stronger fill
- For `voice`:
  - do not make it as bright as a permanent primary CTA in default state
  - use weak-emphasis default and stronger active state

## 7. Deliverables

- `icon-redesign-v1-board.html`: focused sketch board for `P0 + P1`
- `icon-redesign-v2-board.html`: full icon preview board
- `icon-tabbar-spec-v1.html`: bottom tab state page
- `icon-spec-summary-v1.md`: summary spec
