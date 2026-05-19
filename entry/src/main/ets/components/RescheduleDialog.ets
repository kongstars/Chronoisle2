import { AppCard } from '../ui/base/AppCard';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { SPACE_SM } from '../foundation/tokens/SpacingTokens';
import { TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';

@Builder
export function RescheduleDialog() {
  AppCard({ variant: 'raised', spacing: SPACE_SM, paddingLevel: 'lg' }) {
    Row({ space: SPACE_SM }) {
      Text('一键整理')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)

      AppStatusBadge({ text: '待完善', tone: 'warning', iconName: 'warning' })
    }
    .width('100%')

    Text('该功能当前仍为占位入口，后续会接入真实的今日任务重排与建议预览。')
      .fontSize(TYPE_META)
      .lineHeight(18)
      .width('100%')
  }
  .width('100%')
  .padding(16)
}
