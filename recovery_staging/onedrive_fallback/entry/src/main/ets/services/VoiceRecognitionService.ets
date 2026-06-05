import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import {
  AsrResult,
  CommonUtils,
  Constants,
  INativeNuiCallback,
  KwsResult,
  MapToJson,
  NativeNui
} from 'neonui';
import { hasMicrophonePermission } from '../Utils/UserPerm';
import { TokenService } from './TokenService';

class Uint8ArrayFIFOQueue {
  private queue: Uint8Array[] = [];
  private totalLength: number = 0;

  enqueue(data: Uint8Array): void {
    this.queue.push(data);
    this.totalLength += data.length;
  }

  dequeue(length: number): Uint8Array | undefined {
    if (length <= 0 || this.totalLength <= 0) {
      return undefined;
    }

    if (length >= this.totalLength) {
      const result = new Uint8Array(this.totalLength);
      let offset = 0;
      for (const chunk of this.queue) {
        result.set(chunk, offset);
        offset += chunk.length;
      }
      this.clear();
      return result;
    }

    const result = new Uint8Array(length);
    let bytesRead = 0;
    while (bytesRead < length && this.queue.length > 0) {
      const chunk = this.queue[0];
      const bytesToCopy = Math.min(chunk.length, length - bytesRead);
      result.set(chunk.subarray(0, bytesToCopy), bytesRead);
      bytesRead += bytesToCopy;

      if (bytesToCopy < chunk.length) {
        this.queue[0] = chunk.subarray(bytesToCopy);
      } else {
        this.queue.shift();
      }
    }

    this.totalLength -= bytesRead;
    return result;
  }

  clear(): void {
    this.queue = [];
    this.totalLength = 0;
  }
}

export class VoiceRecognitionService implements INativeNuiCallback {
  private static instance: VoiceRecognitionService;
  private isRecording: boolean = false;
  private realtimeText: string = '';
  private statusDescription: string = '语音识别就绪';
  private recognitionCompleteCallback: ((text: string) => void) | null = null;
  private realtimeUpdateCallback: ((text: string) => void) | null = null;
  private stopResolve: ((text: string) => void) | null = null;
  private stopTimeoutId: number = -1;
  private hasInitialized: boolean = false;
  private initContextKey: string = '';
  private currentContext: common.UIAbilityContext | null = null;
  private deviceId: string = 'chronoisle-device';
  private audioCapturer: audio.AudioCapturer | null = null;
  private audioCapturerReady: Promise<void> | null = null;
  private readonly audioQueue: Uint8ArrayFIFOQueue = new Uint8ArrayFIFOQueue();
  private readonly nui: NativeNui = new NativeNui(Constants.ModeType.MODE_DIALOG, 'voice_create');

  private constructor() {}

  public static getInstance(): VoiceRecognitionService {
    if (!VoiceRecognitionService.instance) {
      VoiceRecognitionService.instance = new VoiceRecognitionService();
    }
    return VoiceRecognitionService.instance;
  }

  public preInitialize(context: Context): void {
    this.currentContext = context as common.UIAbilityContext;
    void this.ensureInitialized(this.currentContext);
  }

  public async startRecognition(
    context: Context,
    onRealtimeUpdate?: (text: string) => void,
    onRecognitionComplete?: (text: string) => void
  ): Promise<string> {
    this.currentContext = context as common.UIAbilityContext;
    this.realtimeUpdateCallback = onRealtimeUpdate || null;
    this.recognitionCompleteCallback = onRecognitionComplete || null;
    this.realtimeText = '';
    this.statusDescription = '正在准备语音识别';
    this.audioQueue.clear();

    const granted = await hasMicrophonePermission();
    if (!granted) {
      this.isRecording = false;
      this.statusDescription = '请先允许麦克风权限后再使用语音输入';
      return this.statusDescription;
    }

    try {
      await this.ensureInitialized(this.currentContext);
      this.nui.setParams(this.buildRuntimeParams());
      const ret = this.nui.startDialog(Constants.VadMode.TYPE_P2T, '{}');
      if (ret !== Constants.NuiResultCode.SUCCESS) {
        this.isRecording = false;
        this.statusDescription = `语音识别启动失败，错误码: ${ret}`;
        return this.statusDescription;
      }
      this.isRecording = true;
      this.statusDescription = '正在录音';
      return '';
    } catch (_) {
      const message = '语音识别暂时不可用，请稍后重试';
      this.isRecording = false;
      this.statusDescription = message;
      return message;
    }
  }

  public async stopRecognition(): Promise<string> {
    if (!this.isRecording) {
      return this.realtimeText;
    }

    this.isRecording = false;
    this.statusDescription = '正在结束录音';

    return await new Promise<string>((resolve) => {
      this.stopResolve = resolve;
      this.clearStopTimeout();
      this.stopTimeoutId = setTimeout(() => {
        this.finishRecognition(this.realtimeText);
      }, 1200);

      const ret = this.nui.stopDialog();
      if (ret !== Constants.NuiResultCode.SUCCESS) {
        this.finishRecognition(this.realtimeText);
      }
    });
  }

  public cancelRecognition(): void {
    this.isRecording = false;
    this.clearStopTimeout();
    this.audioQueue.clear();
    try {
      this.nui.cancelDialog();
    } catch (_) {
      console.warn('[VoiceRecognitionService] cancelDialog failed');
    }
  }

  public getRealtimeText(): string {
    return this.realtimeText;
  }

  public isRecordingInProgress(): boolean {
    return this.isRecording;
  }

  public reset(): void {
    this.isRecording = false;
    this.realtimeText = '';
    this.statusDescription = '语音识别已重置';
    this.realtimeUpdateCallback = null;
    this.recognitionCompleteCallback = null;
    this.stopResolve = null;
    this.clearStopTimeout();
    this.audioQueue.clear();
  }

  public resetInitialization(): void {
    this.hasInitialized = false;
    this.initContextKey = '';
    try {
      this.nui.release();
    } catch (_) {
      console.warn('[VoiceRecognitionService] release failed');
    }
  }

  public static async isSDKAvailable(): Promise<boolean> {
    return true;
  }

  public getStatusDescription(): string {
    return this.statusDescription;
  }

  onNuiEventCallback(
    event: Constants.NuiEvent,
    resultCode: number,
    _arg2: number,
    _kwsResult: KwsResult,
    asrResult: AsrResult
  ): void {
    if (event === Constants.NuiEvent.EVENT_ASR_ERROR || event === Constants.NuiEvent.EVENT_MIC_ERROR) {
      this.statusDescription = `语音识别出错，错误码: ${resultCode}`;
      this.finishRecognition(this.realtimeText);
      return;
    }

    if (asrResult && asrResult.asrResult) {
      const parsedText = this.extractAsrText(asrResult.asrResult);
      if (parsedText) {
        this.realtimeText = parsedText;
        if (this.realtimeUpdateCallback) {
          this.realtimeUpdateCallback(parsedText);
        }
      }
    }

    if (
      event === Constants.NuiEvent.EVENT_SENTENCE_END ||
      event === Constants.NuiEvent.EVENT_ASR_RESULT ||
      event === Constants.NuiEvent.EVENT_TRANSCRIBER_COMPLETE
    ) {
      this.finishRecognition(this.realtimeText);
    }
  }

  onNuiNeedAudioData(buffer: ArrayBuffer): number {
    const source = this.audioQueue.dequeue(buffer.byteLength);
    if (!source) {
      return 0;
    }

    const target = new Uint8Array(buffer);
    target.set(source);
    return source.byteLength;
  }

  onNuiAudioStateChanged(state: Constants.AudioState): void {
    if (state === Constants.AudioState.STATE_OPEN) {
      this.startAudioCapturer();
      return;
    }

    if (state === Constants.AudioState.STATE_CLOSE || state === Constants.AudioState.STATE_PAUSE) {
      this.stopAudioCapturer();
    }
  }

  onNuiAudioRMSChanged(_val: number): number {
    return 0;
  }

  onNuiLogTrackCallback(_level: Constants.LogLevel, log: string): void {
    if (log) {
      console.info(`[VoiceRecognitionService] ${log}`);
    }
  }

  private async ensureInitialized(context: common.UIAbilityContext): Promise<void> {
    const contextKey = `${context.resourceDir}|${context.filesDir}`;
    if (this.hasInitialized && this.initContextKey === contextKey) {
      return;
    }

    await this.ensureAudioCapturer();

    let deviceId = 'chronoisle-device';
    try {
      const fetched = await CommonUtils.getDeviceInfo();
      if (fetched && fetched.trim()) {
        deviceId = fetched;
      }
    } catch (_) {
      console.warn('[VoiceRecognitionService] getDeviceInfo failed');
    }
    this.deviceId = deviceId;

    const tokenInfo = await TokenService.getSpeechToken();
    const initParams = this.buildInitParams(context, tokenInfo.token, tokenInfo.appKey);
    const initRet = this.nui.initialize(this, initParams, Constants.LogLevel.LOG_LEVEL_INFO, false);
    if (initRet !== Constants.NuiResultCode.SUCCESS) {
      throw new Error(`语音 SDK 初始化失败，错误码: ${initRet}`);
    }

    this.hasInitialized = true;
    this.initContextKey = contextKey;
    this.statusDescription = '语音识别已初始化';
  }

  private async ensureAudioCapturer(): Promise<void> {
    if (this.audioCapturer) {
      return;
    }
    if (this.audioCapturerReady) {
      await this.audioCapturerReady;
      return;
    }

    const streamInfo: audio.AudioStreamInfo = {
      samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
    };
    const capturerInfo: audio.AudioCapturerInfo = {
      source: audio.SourceType.SOURCE_TYPE_MIC,
      capturerFlags: 0
    };
    const options: audio.AudioCapturerOptions = {
      streamInfo,
      capturerInfo
    };

    this.audioCapturerReady = audio.createAudioCapturer(options).then((capturer: audio.AudioCapturer) => {
      this.audioCapturer = capturer;
      this.audioCapturer.on('readData', (buffer: ArrayBuffer) => {
        this.audioQueue.enqueue(new Uint8Array(buffer));
      });
    }).catch((error: BusinessError) => {
      this.audioCapturer = null;
      throw new Error(`创建录音器失败: ${error.message}`);
    });

    await this.audioCapturerReady;
  }

  private startAudioCapturer(): void {
    if (!this.audioCapturer) {
      return;
    }
    this.audioCapturer.start().catch((error: BusinessError) => {
      console.error(`[VoiceRecognitionService] start capturer failed: ${error.message}`);
    });
  }

  private stopAudioCapturer(): void {
    if (!this.audioCapturer) {
      return;
    }
    this.audioCapturer.stop().catch((error: BusinessError) => {
      console.warn(`[VoiceRecognitionService] stop capturer failed: ${error.message}`);
    });
  }

  private buildInitParams(context: common.UIAbilityContext, token: string, appKey: string): string {
    const params: Map<string, string | number | boolean | object> = new Map();
    params.set('app_key', appKey);
    params.set('token', token);
    params.set('url', 'wss://nls-gateway.cn-shanghai.aliyuncs.com/ws/v1');
    params.set('device_id', this.deviceId);
    params.set('workspace', `${context.resourceDir}/resources_cloud`);
    params.set('debug_path', context.filesDir);
    params.set('service_mode', Constants.ModeFullCloud);
    params.set('audio_update_manually', 'false');
    params.set('log_track_level', `${Constants.LogLevel.LOG_LEVEL_INFO}`);
    return MapToJson(params);
  }

  private buildRuntimeParams(): string {
    const nlsConfig: Map<string, string | number | boolean | object> = new Map();
    nlsConfig.set('enable_intermediate_result', true);
    nlsConfig.set('enable_punctuation_prediction', true);
    nlsConfig.set('enable_inverse_text_normalization', true);

    const params: Map<string, string | number | boolean | object> = new Map();
    params.set('nls_config', Object(JSON.parse(MapToJson(nlsConfig))));
    params.set('service_type', Constants.kServiceTypeSpeechTranscriber);
    return MapToJson(params);
  }

  private extractAsrText(raw: string): string {
    try {
      const result = JSON.parse(raw) as Record<string, Object>;
      const payload = result['payload'] as Record<string, string> | undefined;
      const text = payload ? payload['result'] : '';
      return text || this.realtimeText;
    } catch (_) {
      console.warn('[VoiceRecognitionService] parse ASR text failed');
      return this.realtimeText;
    }
  }

  private finishRecognition(text: string): void {
    this.clearStopTimeout();
    const finalText = text || this.realtimeText;
    this.realtimeText = finalText;
    this.statusDescription = finalText ? '语音识别完成' : '未识别到语音内容';

    if (this.recognitionCompleteCallback) {
      this.recognitionCompleteCallback(finalText);
    }

    if (this.stopResolve) {
      const resolve = this.stopResolve;
      this.stopResolve = null;
      resolve(finalText);
    }
  }

  private clearStopTimeout(): void {
    if (this.stopTimeoutId !== -1) {
      clearTimeout(this.stopTimeoutId);
      this.stopTimeoutId = -1;
    }
  }

}
