# ArkTS 渐变色修复指南

## 问题
ArkTS 不支持 `linearGradient()` 函数，需要使用 `LinearGradient` 类。

## 正确语法

```typescript
.background(
  new LinearGradient({
    x1: 0, y1: 0, x2: 1, y2: 1,
    colors: [
      { color: '#667EEA', offset: 0 },
      { color: '#764BA2', offset: 1 }
    ]
  })
)
```

或者使用纯色替代：
```typescript
.backgroundColor('#667EEA')
```

## 需要修复的文件
- MainPage.ets
- GoalDetailPage.ets
- CreateTaskPage.ets
- StatsPage.ets

## 其他问题
1. `any` 类型需要替换为 `Record<string, unknown>`
2. `Slider` 使用 `blockColor` 而不是 `activeColor`
3. `borderBottom` 应该使用 `.border({ width: 1, color: 'xxx', style: BorderStyle.Solid })`
