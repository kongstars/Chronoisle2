import { Task } from '../models/Task';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';

export interface ManualTaskSelectDialogParams {
  tasks: Task[];
  existingTaskIds: string[];
  onConfirm: (selectedIds: string[]) => void;
}

@Builder
export function ManualTaskSelectDialog(params: ManualTaskSelectDialogParams) {
  AppCard({ variant: 'raised', spacing: SPACE_MD, paddingLevel: 'lg' }) {
    Row({ space: SPACE_SM }) {
      Text('手动选择任务')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)

      AppStatusBadge({
        text: `${params.tasks.length} 项`,
        tone: 'info',
        iconName: 'task'
      })
    }
    .width('100%')

    Text(`当前已选 ${params.existingTaskIds.length} 项。后续接入完整交互前，这里会沿用现有选中结果继续保存。`)
      .fontSize(TYPE_META)
      .lineHeight(18)
      .width('100%')

    if (params.tasks.length > 0) {
      Column({ space: SPACE_XS }) {
        ForEach(params.tasks.slice(0, 4), (task: Task) => {
          Row({ space: SPACE_SM }) {
            Text(task.title)
              .fontSize(TYPE_BODY)
              .fontColor(this.themeColors.textPrimary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            if (params.existingTaskIds.includes(task.id)) {
              AppStatusBadge({ text: '已选', tone: 'primary', iconName: 'success' })
            }
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })
        }, (task: Task) => task.id)
      }
      .width('100%')
    }

    Row() {
      AppButton({
        text: '确认',
        variant: 'primary',
        fullWidth: true,
        iconName: 'success',
        tapAction: () => params.onConfirm(params.existingTaskIds)
      })
    }
  }
  .width('100%')
  .padding(16)
}
