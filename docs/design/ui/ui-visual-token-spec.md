# Chronoisle UI System V2 视觉组件级规范

> 本规范详细定义了具体 UI 组件的视觉构造规则。开发者在封装基础组件时，需完全符合此文档的定义。

## 1. 列表容器与行 (List Container & Row)

在 V2 版本中，列表采取“大白卡容器 + 无界内部行”的设计。

- **大容器 (List Container)**:
  - 必须使用 `radiusLg` (14vp)。
  - 具有 `borderLight` 细边框和 `shadowCard`。
  - **切除溢出**: 必须设置 `clip(true)`，防止内部行在点击时超出圆角。
  - **取消内部 Padding**: 容器内部不能有统一的 `padding`，直接包裹 `Row`。
- **列表行 (List Row)**:
  - 自身 `padding: 12vp 14vp`。
  - 点击态使用 `Scale(0.98)` + `backgroundColor(surfacePressed)`。
  - **底部分割线**:
    - **禁止使用通栏实线**。
    - 必须使用伪元素/渐变渲染技术，实现左右两端透明淡出 (`LinearGradient`：透明 -> 15% 处实色 -> 85% 处实色 -> 透明)。

## 2. 复选框 (Checkbox)

- 尺寸: `20vp * 20vp`。
- 圆角: `radiusSm` (6vp)。
- **未选中态**:
  - 浅色: 极淡的灰底 (`#F8F9FB`) + 边框 + **微弱内阴影**。
  - 深色: 极深的黑底 (`#090A0C`) + 边框 + **沉重内阴影**。
- **选中态**:
  - 边框变为 `brandPrimary`。
  - 背景变为 `brandLight` (带透明度，不要用实心主色)。

## 3. 分类标签 (Category Tags)

- 必须保持极简的“淡色底 + 鲜明字”风格。
- 尺寸: `padding: 2vp 6vp`，圆角 `radiusSm` (4vp)。
- **浅色模式**:
  - 背景色透明度: 8%~10%。
  - 文字色/边框色透明度: 100% / 10%~15%。
- **深色模式**:
  - 背景色透明度保持 10%，但文字颜色必须提高亮度 (如原版紫色 `#8B5CF6` 需提亮为 `#A78BFA`)。

## 4. 悬浮 AI 按钮 (AI FAB)

AI 按钮不再是一个巨大的发光球，而是一个深邃、专业的终端入口。

- **尺寸**: `48vp * 48vp`。
- **形状**: `radius: 20vp` (接近 Squircle 超椭圆)。
- **浅色模式背景**:
  - 使用深邃黑渐变: `Linear(135deg, #1C1D24, #2A2C36)`。
  - 阴影: 强烈的向下投影 `0 6px 16px rgba(0,0,0,0.25)`。
- **深色模式背景**:
  - 相同的黑渐变底色。
  - 阴影: **极强的黑色投影** `0 8px 24px rgba(0,0,0,0.6)` + 白色的 `borderHighlight` 描边。
- **AI 极光点 (Dot)**:
  - 位于右上角 (`top: 8vp, right: 8vp`)。
  - 尺寸 `6vp * 6vp`。
  - 使用 `aiGradient` 填充，并带有发光阴影 (浅色下光晕弱，深色下光晕极强)。

## 5. 进度环 (Progress Ring)

这是体现“精工质感”的核心组件，必须摒弃原生的纯色边框画法，采用 **环形渐变 (Conic Gradient)**。

- **外环尺寸**: `32vp * 32vp`，`radius: 50%`。
- **渲染方式**: 必须使用 Conic Gradient。
  - 浅色示例: `conic-gradient(brandPrimary 65%, #E5E7EB 0)`
  - 深色示例: `conic-gradient(brandPrimary 65%, #2A2C38 0)`
- **内环挖空 (Cutout)**: 
  - 通过覆盖一个白底/黑底的内圆来实现挖空。
  - 浅色内圆: `#FFFFFF`，带有 `inset 0 1px 2px rgba(0,0,0,0.05)` 内阴影。
  - 深色内圆: `#1A1B23`，带有 `inset 0 2px 4px rgba(0,0,0,0.5)` 内阴影。
- **文字**: 等宽字体，字号 `9vp`，居中对齐。

## 7. 开发者核心实现指南 (ArkTS Snippets)

为了降低实现门槛，请直接参考以下代码片段在 ArkTS 中实现复杂视觉效果：

### A. 极速按压动效 (Crisp Animation)
不再使用复杂的显式动画，而是利用 ArkUI 的状态驱动：
```typescript
.scale({ x: this.isPressed ? 0.96 : 1, y: this.isPressed ? 0.96 : 1 })
.backgroundColor(this.isPressed ? this.themeColors.surfacePressed : this.themeColors.surfaceBase)
.animation({ duration: 100, curve: Curve.Friction })
```

### B. 内阴影平替方案 (Inset Shadow Workaround)
ArkUI 默认的 `shadow` 无法直接写 `inset`。
**平替方案**：给组件内层覆盖一个透明度极低的 `border`，或者嵌套一个覆盖层。
```typescript
// 浅色模式卡片的顶部高光 (伪 Inset)
.border({ width: { top: 1 }, color: 'rgba(255,255,255,0.8)' })

// 深色模式复选框的沉重内阴影
Stack() {
  // 底部黑框
  Row().width('100%').height('100%').backgroundColor('#090A0C')
  // 顶部覆盖一层黑色半透明边框模拟内阴影
  Row().width('100%').height('100%').border({ width: 2, color: 'rgba(0,0,0,0.8)' })
}
```

### C. 点阵科技底纹 (Dot-matrix Pattern)
ArkUI 中可通过平铺极小的背景图，或者使用简单的径向渐变 (`radialGradient`) 矩阵实现。
最简单的平替方案是使用 `.backgroundImage` 和 `ImageRepeat.XY`：
```typescript
.backgroundImage($r('app.media.dot_pattern')) // 一张 20x20 的极淡小圆点透明 PNG
.backgroundImageSize({ width: 20, height: 20 })
.backgroundImagePosition(Alignment.TopStart)
.backgroundImageRepeat(ImageRepeat.XY)
```

### D. 毛玻璃特效 (Glassmorphism)
```typescript
.backgroundColor(this.isDark ? 'rgba(26,27,35,0.85)' : 'rgba(255,255,255,0.9)')
.backgroundBlurStyle(BlurStyle.Thin) // 或直接使用 .backdropBlur(24)
```