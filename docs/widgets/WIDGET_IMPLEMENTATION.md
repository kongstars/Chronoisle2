# 四时清单桌面小组件实现总结

## 已完成的工作

### 1. 配置文件更新

#### form_config.json
已配置 7 种卡片类型：
- `widget_todo` - 今日待办 (2*4)
- `widget_habit` - 习惯打卡 (2*2)
- `widget_countdown` - 重要日子 (2*2)
- `widget_today_plan` - AI 今日计划 (2*4)
- `widget_focus` - 专注时钟 (2*2)
- `widget_dashboard` - 数据仪表盘 (4*4)
- `widget_voice` - 语音创建 (2*2)

#### string.json
已添加所有卡片的描述文本。

### 2. 数据模型 (WidgetData.ets)
已更新包含所有卡片所需的数据接口：
- `WidgetTask` - 任务数据
- `WidgetHabit` - 习惯数据
- `WidgetCountdown` - 倒计时数据
- `WidgetTodayPlan` / `WidgetPlanTask` - AI 计划数据
- `WidgetFocus` - 专注数据
- `WidgetStats` - 统计数据
- 对应的 WidgetData 类

### 3. 卡片页面组件 (7 个)

#### TodoWidget.ets (今日待办)
- 显示 Pending 状态的任务
- 按优先级和截止时间排序
- 逾期任务红色标记
- 点击任务跳转到 TaskDetailPage
- 点击添加跳转到 CreateTaskPage

#### HabitWidget.ets (习惯打卡)
- 显示 HABIT 类型的 DayEvent
- 展示今日完成进度条
- 已完成习惯显示删除线
- 点击跳转到 DayEventDetailPage
- 点击添加跳转到 DayEventCreatePage

#### CountdownWidget.ets (重要日子)
- 显示 MILESTONE/COUNTDOWN/COUNTER 类型事件
- 按目标日期排序
- 不同颜色区分类型
- 点击跳转到 DayEventDetailPage

#### TodayPlanWidget.ets (AI 今日计划)
- 显示已采纳或待采纳的 AI 计划
- 展示计划任务列表和时间槽
- 点击可采纳计划
- 跳转到 TodayPlanPage

#### FocusWidget.ets (专注时钟)
- 显示当前专注状态和剩余时间
- 显示今日累计专注分钟
- 点击跳转到 PomodoroPage

#### DashboardWidget.ets (数据仪表盘)
- 今日专注时长、完成任务数、连续打卡天数
- 本周专注时长和完成任务数
- 三个彩色数据卡片布局
- 点击跳转到 StatsHubPage

#### VoiceWidget.ets (语音创建)
- 麦克风图标和提示文字
- 点击跳转到 MainPage 并触发语音创建

### 4. EntryFormAbility.ets 更新
- 支持多卡片类型识别
- 根据 `formName` 构建不同的卡片数据
- `onAddForm` 和 `onUpdateForm` 都支持多类型
- 数据从 `life_goal_storage` 和 `chronoisle_settings` 读取

## 技术要点

### 鸿蒙卡片交互
- 使用 `postCardAction` 实现卡片跳转
- `action: 'router'` 打开应用页面
- 支持传递参数（如 taskId、eventId）

### 数据刷新
- `updateDuration: 1` 表示每 30 分钟刷新一次
- 每天最多 48 次刷新（平台限制）
- 数据变更后需手动调用 `updateForm`

## 待完成的工作

### 1. 路由参数处理
需要在 `MainPage.ets` 或 `EntryAbility.ets` 中处理来自卡片的参数：
- `showVoiceCreate: true` - 拉起语音创建弹窗
- 其他卡片跳转已使用标准页面路径

### 2. 数据变更刷新
在以下服务中，数据变更后需要触发 widget 刷新：
- `Database.ets` - 任务/目标/习惯变更后
- `TodayPlanService.ets` - 今日计划采纳后
- `PomodoroPage.ets` - 专注状态变更时

实现方式：
```typescript
import formProvider from '@ohos.app.form.formProvider';

// 获取保存的 formIds 并调用 updateForm
```

### 3. 构建验证
由于开发环境 NODE_HOME 配置问题，暂时无法运行完整构建。
需要在 DevEco Studio 中：
1. 打开项目
2. 运行 `hvigorw assembleApp`
3. 修复可能的 TypeScript 编译错误

### 4. 真机测试
- 添加卡片到桌面
- 验证各卡片数据显示正确
- 验证点击跳转功能
- 验证数据刷新频率

## 文件清单

### 新建文件
- `entry/src/main/ets/widget/pages/TodoWidget.ets`
- `entry/src/main/ets/widget/pages/HabitWidget.ets`
- `entry/src/main/ets/widget/pages/CountdownWidget.ets`
- `entry/src/main/ets/widget/pages/TodayPlanWidget.ets`
- `entry/src/main/ets/widget/pages/FocusWidget.ets`
- `entry/src/main/ets/widget/pages/DashboardWidget.ets`
- `entry/src/main/ets/widget/pages/VoiceWidget.ets`

### 修改文件
- `entry/src/main/resources/base/profile/form_config.json`
- `entry/src/main/resources/base/element/string.json`
- `entry/src/main/ets/models/WidgetData.ets`
- `entry/src/main/ets/entryformability/EntryFormAbility.ets`

## 后续建议

1. **统一刷新机制**: 创建一个 `WidgetRefreshService`，在数据变更时统一调用
2. **按需刷新**: 只在用户添加/完成任务后刷新，避免频繁刷新
3. **错误处理**: 卡片数据加载失败时显示友好提示
4. **性能优化**: 大数据量时考虑分页或缓存
5. **可配置性**: 允许用户在设置中启用/禁用特定卡片

## 注意事项

1. 鸿蒙卡片不支持复杂交互（如文本输入、录音）
2. 所有数据变更操作需要跳转到 App 内完成
3. 卡片刷新频率有限制（每 30 分钟一次，每天最多 48 次）
4. 专注倒计时等实时数据无法在卡片内精确显示
