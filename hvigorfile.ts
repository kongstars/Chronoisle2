
import { appTasks } from '@ohos/hvigor-ohos-plugin';
import { ensureDevEcoEnv } from './hvigor/ensureDevEcoEnv';

ensureDevEcoEnv();

export default {
    system: appTasks
}
