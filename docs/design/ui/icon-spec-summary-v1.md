# Chronoisle Icon Spec Summary V1

## 1. Design Conclusion

- Principle: keep icon geometry unified, and keep color layered instead of fully uniform.
- Goal: improve consistency, recognizability, and scene fit without changing layout.
- Boundary: only redesign icons; do not change spacing, containers, hierarchy, or tab-bar structure.
- Delivery direction: keep `AppIcon` as the single implementation entry in code.

## 2. Visual Rules

### 2.1 Grid And Size

- `12`: tiny state markers
- `16`: inline status, checklist, tail affordance
- `20`: small controls
- `24`: standard navigation and operation icons
- `32`: primary business icons on cards
- `40 / 48`: empty states and hero icons

### 2.2 Stroke

- `12 / 16`: `1.5 - 1.65`
- `20 / 24`: `1.75 - 1.9`
- `32+`: `2`

### 2.3 Color

- `80%` unified neutral or theme foreground
- semantic colors only for `success / warning / info / danger`
- branded accents only for a small set of scene icons such as `voice`, `focus`, `ai`, `tomato`

## 3. State Rules

- Default state should be lighter and outline-led.
- Selected state should use the same skeleton with local fill or stronger mass.
- Do not rely on color only.
- Do not replace the icon with a completely different shape when selected.

## 4. Bottom Tab Bar

- Tabs covered: `today`, `action`, `goal`, `profile`
- Voice stays a special action button and does not follow standard tab selected logic.
- Tab icons need both:
  - geometry difference
  - color difference

### Tab State Direction

- `today`: outline calendar -> filled calendar plate with active dot
- `action`: outline bolt -> solid bolt
- `goal`: outline target -> solid outer ring with preserved center
- `profile`: outline avatar -> solid head and shoulder mass
- `voice`: weak-emphasis default, stronger emphasis only on expand or active

## 5. Icon Families

### Navigation And Actions

`search`, `close`, `plus`, `minus`, `edit`, `delete`, `share`, `filter`, `sort`, `copy`, `link`, `lock`, `unlock`, `eye`, `eye-off`, `chevron-left`, `chevron-right`, `chevron-up`, `chevron-down`

### Status And Feedback

`success`, `warning`, `info`, `help`, `sync`, `archive`, `unknown`

### Business Core

`today`, `goal`, `task`, `reminder`, `calendar`, `habit`, `milestone`, `counter`, `countdown`, `stats`, `wallet`, `ai`, `plan`, `progress`, `action`, `review`, `note`, `idea`

### Category And Growth

`health`, `growth`, `finance`, `joy`, `focus`

### Scene And Environment

`tomato`, `voice`, `noise`, `rain`, `storm`, `wind`, `water`, `bird`, `power`, `radio`, `phone`

### Personal And System

`gear`, `profile`, `spark`, `star`, `star-fill`, `heart`, `flag`, `tag`, `location`, `time`, `date`

## 6. Bitmap Resource Strategy

- `startIcon.png`: keep as brand asset
- `huawei_login_logo_white.png`: keep as partner brand asset
- `tomato.png`: gradually replace with vector icon
- `icon_appgallery_*`: keep as store assets, not app icon system

## 7. Related Deliverables

- `icon-redesign-v1.md`
- `icon-redesign-v1-board.html`
- `icon-redesign-v2-board.html`
- `icon-tabbar-spec-v1.html`
- `icon-spec-summary-v1-preview.html`
