import { SPACE_MD, SPACE_SM } from '../../foundation/tokens/SpacingTokens';
import { AppButton, type AppButtonVariant } from './AppButton';

@Component
export struct AppDialogActions {
  @Prop primaryText: string = '';
  @Prop secondaryText: string = '取消';
  @Prop primaryVariant: AppButtonVariant = 'primary';
  @Prop secondaryVariant: AppButtonVariant = 'secondary';
  @Prop primaryDisabled: boolean = false;
  @Prop secondaryDisabled: boolean = false;
  @Prop primaryLoading: boolean = false;
  @Prop secondaryLoading: boolean = false;
  @Prop primaryIconName: string = '';
  @Prop secondaryIconName: string = '';
  @Prop stacked: boolean = false;
  onPrimary?: () => void;
  onSecondary?: () => void;

  @Builder
  private SecondaryButton() {
    if (this.secondaryText.length > 0) {
      AppButton({
        text: this.secondaryText,
        variant: this.secondaryVariant,
        buttonSize: 'md',
        fullWidth: true,
        disabled: this.secondaryDisabled,
        loading: this.secondaryLoading,
        iconName: this.secondaryIconName,
        tapAction: this.onSecondary
      })
        .layoutWeight(1)
    }
  }

  @Builder
  private PrimaryButton() {
    if (this.primaryText.length > 0) {
      AppButton({
        text: this.primaryText,
        variant: this.primaryVariant,
        buttonSize: 'md',
        fullWidth: true,
        disabled: this.primaryDisabled,
        loading: this.primaryLoading,
        iconName: this.primaryIconName,
        tapAction: this.onPrimary
      })
        .layoutWeight(1)
    }
  }

  build() {
    if (this.stacked) {
      Column({ space: SPACE_SM }) {
        this.PrimaryButton()
        this.SecondaryButton()
      }
      .width('100%')
    } else {
      Row({ space: SPACE_MD }) {
        this.SecondaryButton()
        this.PrimaryButton()
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }
}
