import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { AppCard } from '../ui/base/AppCard';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { PAGE_PADDING, SECTION_GAP, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { ComplianceInfo } from '../common/ComplianceInfo';

/**
 * 算法披露页
 *
 * 监管要求：
 * - 互联网信息服务深度合成、生成式 AI 服务、个性化推荐都需要在 App 内提供算法说明入口。
 * - 用户应当能查到算法名称、用途、原理、是否影响其决策以及关闭路径。
 *
 * 本页面集中披露应用内三类算法：
 * 1. AI 今日计划（生成合成 + 个性化推送）。
 * 2. AI 一键重排（生成合成 + 决策辅助）。
 * 3. 语音意图分类与字段解析（生成合成）。
 */
interface AlgorithmEntry {
  name: string;
  category: string;
  purpose: string;
  inputs: string;
  output: string;
  controlPath: string;
}

@Entry
@Component
struct AlgorithmDisclosurePage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;

  private static readonly ENTRIES: AlgorithmEntry[] = [
    {
      name: 'AI 今日计划',
      category: '生成合成 / 个性化推送',
      purpose: '基于您当天的待办、目标和历史完成情况，生成今日建议任务安排。',
      inputs: '本地任务标题、截止时间、优先级、目标关联、过去七天的完成记录。',
      output: '一组带分组、入选原因和顺序建议的任务列表，您可在采纳前编辑或拒绝。',
      controlPath: '在「今日」页面右上角的设置中，可以关闭今日计划自动生成。'
    },
    {
      name: 'AI 一键重排',
      category: '生成合成 / 决策辅助',
      purpose: '面对大量逾期或冲突任务时，提供专注、延期、降级、删除等处理建议。',
      inputs: '当前待办的标题、截止时间、目标关联、依赖关系、是否周期任务。',
      output: '按处理类型分组的任务清单，每条建议附带原因，删除建议需您勾选后才会生效。',
      controlPath: '该功能仅在您主动点击「一键整理」按钮时触发，不会自动改动数据。'
    },
    {
      name: '语音意图分类与字段解析',
      category: '生成合成',
      purpose: '将您口述的语音转写为文本后，识别意图（任务 / 提醒 / 目标 / 专注）并解析字段。',
      inputs: '您主动按下录音按钮后产生的语音文本，配合本地词典与规则。',
      output: '建议的页面跳转、预填的标题、时间、目标关联，您可在创建页修改后再保存。',
      controlPath: '语音功能仅在您按下录音按钮时启动，停止后不再持续录音。'
    }
  ];

  @Builder
  private EntryCard(entry: AlgorithmEntry) {
    AppCard({ spacing: SPACE_SM }) {
      Text(entry.name)
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      Row({ space: SPACE_XS }) {
        Text('分类')
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textMuted)
        Text(entry.category)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.primary)
      }
      .width('100%')

      this.LabelLine('用途', entry.purpose)
      this.LabelLine('数据输入', entry.inputs)
      this.LabelLine('输出与影响', entry.output)
      this.LabelLine('关闭与控制', entry.controlPath)
    }
  }

  @Builder
  private LabelLine(label: string, content: string) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textMuted)
        .width('100%')
      Text(content)
        .fontSize(TYPE_BODY)
        .lineHeight(22)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
  }

  build() {
    Scroll() {
      Column({ space: SECTION_GAP }) {
        AppPageHeader({
          title: '算法说明',
          subtitle: '我们使用了哪些算法、如何使用、如何关闭',
          onBack: () => this.getUIContext().getRouter().back()
        })

        Column({ space: SECTION_GAP }) {
          AppCard({ spacing: SPACE_SM }) {
            Text('算法服务总览')
              .fontSize(TYPE_SECTION_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textPrimary)
              .width('100%')
            Text('四时清单使用以下算法服务为您提供 AI 计划、重排和语音创建能力。所有 AI 输出仅作为建议，最终是否采用由您决定。')
              .fontSize(TYPE_BODY)
              .lineHeight(22)
              .fontColor(this.themeColors.textSecondary)
              .width('100%')
            if (!ComplianceInfo.isPlaceholder(ComplianceInfo.ALGORITHM_BEIAN_NO)) {
              Text(`算法备案号：${ComplianceInfo.ALGORITHM_BEIAN_NO}`)
                .fontSize(TYPE_META)
                .fontColor(this.themeColors.textMuted)
                .width('100%')
            }
          }

          ForEach(AlgorithmDisclosurePage.ENTRIES, (entry: AlgorithmEntry) => {
            this.EntryCard(entry)
          }, (entry: AlgorithmEntry) => entry.name)

          AppCard({ spacing: SPACE_SM }) {
            Text('您的权利')
              .fontSize(TYPE_SECTION_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textPrimary)
              .width('100%')
            Text('您可以随时在设置中关闭对应 AI 功能；您也可以通过注销账号或导出数据来管理您的个人信息。如果您对算法有疑问，欢迎通过「关于」页中的客服邮箱联系我们。')
              .fontSize(TYPE_BODY)
              .lineHeight(22)
              .fontColor(this.themeColors.textSecondary)
              .width('100%')
          }
        }
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING })
      }
      .width('100%')
      .padding({ bottom: PAGE_PADDING })
    }
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
    .scrollBar(BarState.Off)
  }
}
