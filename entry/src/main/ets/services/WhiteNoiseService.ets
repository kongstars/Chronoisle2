// 白噪音服务 - 管理专注时白噪音播放
import media from '@ohos.multimedia.media';
import dataPreferences from '@ohos.data.preferences';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('WhiteNoiseService');

const WHITE_NOISE_PREFS_NAME = 'pomodoro_white_noise_prefs';
const LAST_SELECTED_NOISE_KEY = 'last_selected_noise_key';

export interface NoiseOption {
  key: string;
  label: string;
  icon: string;
  category: 'nature' | 'artificial';
  isPremium: boolean;
  fileName: string;
}

interface AVFileDescriptor {
  fd: number;
  offset: number;
  length: number;
}

/**
 * 白噪音播放服务
 *
 * 实现说明：
 * - 使用 `media.AVPlayer` 替代已废弃的 `media.AudioPlayer`。
 * - AVPlayer 状态机：idle → initialized → prepared → playing → completed/stopped → released。
 *   每次状态切换通过 `on('stateChange', ...)` 事件触发，必须按事件驱动写法。
 * - 切换音频时，先 reset() 回到 idle，再设置新的 fdSrc。
 */
export class WhiteNoiseService {
  private static instance: WhiteNoiseService;
  private avPlayer: media.AVPlayer | null = null;
  private pendingKey: string = '';
  private currentKey: string = '';
  private _isPlaying: boolean = false;
  private _volume: number = 0.6;
  private prefs: dataPreferences.Preferences | null = null;

  static readonly NOISE_OPTIONS: NoiseOption[] = [
    { key: 'light-rain', label: '轻雨循环', icon: 'rain', category: 'nature', isPremium: true, fileName: '轻雨循环.wav' },
    { key: 'thunderstorm', label: '雷雨', icon: 'storm', category: 'nature', isPremium: true, fileName: '雷雨.wav' },
    { key: 'strong-wind', label: '大风', icon: 'wind', category: 'nature', isPremium: true, fileName: '大风.wav' },
    { key: 'stream', label: '流水', icon: 'water', category: 'nature', isPremium: true, fileName: '流水.wav' },
    { key: 'birds', label: '鸟鸣', icon: 'bird', category: 'nature', isPremium: true, fileName: '鸟鸣.wav' },
    { key: 'riverside-birds', label: '河边鸟鸣', icon: 'water', category: 'nature', isPremium: true, fileName: '河边鸟儿鸣叫.wav' },
    { key: 'battery-current', label: '低电量电流', icon: 'power', category: 'artificial', isPremium: true, fileName: '低电量电流声.wav' },
    { key: 'radio-static', label: '无线电故障', icon: 'radio', category: 'artificial', isPremium: true, fileName: '无线电波故障白噪声.wav' },
    { key: 'dial-error', label: '拨号错误音', icon: 'phone', category: 'artificial', isPremium: true, fileName: '拨号错误音.wav' },
    { key: 'industrial-loop', label: '工业嗡鸣', icon: 'gear', category: 'artificial', isPremium: true, fileName: '工业嗡嗡声回路.wav' },
    { key: 'spaceship-hum', label: '飞船嗡鸣', icon: 'spark', category: 'artificial', isPremium: true, fileName: '太空飞船嗡嗡声.wav' },
    { key: 'rocket-turbine', label: '火箭涡轮', icon: 'power', category: 'artificial', isPremium: true, fileName: '太空火箭全功率涡轮机.wav' }
  ];

  private constructor() {}

  static getInstance(): WhiteNoiseService {
    if (!WhiteNoiseService.instance) {
      WhiteNoiseService.instance = new WhiteNoiseService();
    }
    return WhiteNoiseService.instance;
  }

  static getOptionByKey(key: string): NoiseOption | undefined {
    return WhiteNoiseService.NOISE_OPTIONS.find((option: NoiseOption) => option.key === key);
  }

  static getOptionsByCategory(category: 'nature' | 'artificial'): NoiseOption[] {
    return WhiteNoiseService.NOISE_OPTIONS.filter((option: NoiseOption) => option.category === category);
  }

  private async getPreferences(context: Context): Promise<dataPreferences.Preferences | null> {
    if (this.prefs) {
      return this.prefs;
    }

    try {
      this.prefs = await dataPreferences.getPreferences(context, WHITE_NOISE_PREFS_NAME);
      return this.prefs;
    } catch (error) {
      logger.warn('getPreferences error', error as Object);
      return null;
    }
  }

  async getLastSelectedKey(context: Context): Promise<string> {
    const prefs = await this.getPreferences(context);
    if (!prefs) {
      return '';
    }

    try {
      return prefs.getSync(LAST_SELECTED_NOISE_KEY, '') as string;
    } catch (error) {
      logger.warn('getLastSelectedKey error', error as Object);
      return '';
    }
  }

  async rememberLastSelectedKey(context: Context, key: string): Promise<void> {
    const prefs = await this.getPreferences(context);
    if (!prefs) {
      return;
    }

    try {
      await prefs.put(LAST_SELECTED_NOISE_KEY, key);
      await prefs.flush();
    } catch (error) {
      logger.warn('rememberLastSelectedKey error', error as Object);
    }
  }

  async play(context: Context, key: string): Promise<void> {
    // 如果正在播放同一个，直接停止
    if (this._isPlaying && this.currentKey === key) {
      this.stop();
      return;
    }

    // 先停止当前播放，确保播放器处于干净状态
    this.stop();

    const option = WhiteNoiseService.NOISE_OPTIONS.find((o: NoiseOption) => o.key === key);
    if (!option) {
      return;
    }

    try {
      await this.rememberLastSelectedKey(context, key);

      this.pendingKey = key;
      const player = await media.createAVPlayer();
      player.loop = true;
      this.avPlayer = player;
      this.bindAVPlayerEvents(player);

      const rawFd = await context.resourceManager.getRawFd(option.fileName);
      const descriptor: AVFileDescriptor = {
        fd: rawFd.fd,
        offset: rawFd.offset,
        length: rawFd.length
      };
      // 触发状态机：idle → initialized
      player.fdSrc = descriptor;
    } catch (e) {
      logger.warn(`音频加载失败 - ${key}`, e as Object);
      this._isPlaying = false;
      this.currentKey = '';
      this.pendingKey = '';
    }
  }

  /**
   * 绑定 AVPlayer 状态机事件。AVPlayer 必须显式驱动每个状态切换。
   *
   *  initialized 状态：可以设置 loop / volume，并调用 prepare()
   *  prepared 状态：可以调用 play()
   *  playing 状态：标记 isPlaying = true
   *  stopped/completed 状态：可以 reset() 重新使用，或 release() 销毁
   *  error 状态：清空当前播放器
   */
  private bindAVPlayerEvents(player: media.AVPlayer): void {
    player.on('stateChange', (state: media.AVPlayerState) => {
      switch (state) {
        case 'initialized':
          try {
            player.loop = true;
            player.setVolume(this._volume);
            player.prepare();
          } catch (err) {
            logger.warn('AVPlayer prepare failed', err as Object);
          }
          break;
        case 'prepared':
          try {
            player.loop = true;
            player.setVolume(this._volume);
            player.play();
          } catch (err) {
            logger.warn('AVPlayer play failed', err as Object);
          }
          break;
        case 'playing':
          this._isPlaying = true;
          this.currentKey = this.pendingKey;
          break;
        case 'completed':
          // 原生 loop 正常生效时不应出现 completed；若出现，手动重启播放
          this._isPlaying = false;
          logger.warn('AVPlayer entered completed state while white-noise loop is enabled, restarting');
          try {
            player.seek(0);
            player.play();
          } catch (err) {
            logger.warn('Manual loop restart failed', err as Object);
            this._isPlaying = false;
          }
          break;
        case 'stopped':
        case 'idle':
        case 'released':
          this._isPlaying = false;
          break;
        default:
          break;
      }
    });

    player.on('error', (err: Object) => {
      logger.warn('AVPlayer error', err);
      this._isPlaying = false;
      this.currentKey = '';
      this.pendingKey = '';
    });
  }

  /**
   * 停止当前播放并释放播放器资源。
   *
   * 为保持向后兼容（旧调用方按同步使用），保持同步签名：
   * 立即把 `isPlaying` 切到 false 并解绑当前 player，
   * 然后异步执行 `stop()` / `release()`，失败也不影响后续 play()。
   */
  stop(): void {
    const player = this.avPlayer;
    this.avPlayer = null;
    this._isPlaying = false;
    this.currentKey = '';
    this.pendingKey = '';

    if (!player) {
      return;
    }

    void this.disposePlayer(player);
  }

  private async disposePlayer(player: media.AVPlayer): Promise<void> {
    try {
      const state = player.state as media.AVPlayerState;
      if (state === 'playing' || state === 'paused' || state === 'completed') {
        try {
          await player.stop();
        } catch (err) {
          logger.warn('AVPlayer stop failed', err as Object);
        }
      }
      try {
        await player.release();
      } catch (err) {
        logger.warn('AVPlayer release failed', err as Object);
      }
    } catch (e) {
      logger.warn('disposePlayer error', e as Object);
    }
  }

  isPlaying(): boolean {
    return this._isPlaying;
  }

  getCurrentKey(): string {
    return this.currentKey;
  }

  getVolume(): number {
    return this._volume;
  }

  setVolume(volume: number): void {
    this._volume = Math.max(0, Math.min(1, volume));
    if (this.avPlayer) {
      try {
        this.avPlayer.setVolume(this._volume);
      } catch (err) {
        logger.warn('setVolume failed', err as Object);
      }
    }
  }
}

export const whiteNoiseService = WhiteNoiseService.getInstance();
