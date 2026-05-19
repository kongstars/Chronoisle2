import AbilityStage from '@ohos.app.ability.AbilityStage';
import hilog from '@ohos.hilog';

const DOMAIN = 0x0000;
const TAG = 'EntryAbilityStage';

export default class EntryAbilityStage extends AbilityStage {
  onCreate(): void {
    hilog.info(DOMAIN, TAG, 'EntryAbilityStage onCreate');
  }
}
