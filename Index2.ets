import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { UuidBasic } from './UuidBasic';
import { promptAction } from '@kit.ArkUI';

const TAG: string = 'TtsDemo';
let ttsEngine: textToSpeech.TextToSpeechEngine;

// 设置类型定义
interface TtsSettings {
  language: string;
  person: number;
  online: boolean;
  speed: number;
  volume: number;
  pitch: number;
  audioType: string;
  playType: number;
  saveHistory: boolean;
  autoSaveAudio: boolean;
}

@Entry
@Component
struct Index {
  // --- 状态变量 ---
  @State text: string = "请输入要合成的文本内容，然后点击播放按钮";
  @State currentStatus: string = "准备就绪";
  @State isPlaying: boolean = false;
  @State isDarkMode: boolean = false;
  @State visualizationData: number[] = [];
  @State canvasReady: boolean = false;

  // 设置参数
  @State settings: TtsSettings = {
    language: 'zh-CN',
    person: 0,
    online: true,
    speed: 1.0,
    volume: 1.0,
    pitch: 1.0,
    audioType: "pcm",
    playType: 1,
    saveHistory: true,
    autoSaveAudio: false
  };

  aboutToAppear() {
    // 初始化音频可视化数据
    this.initVisualizationData();
  }

  aboutToDisappear() {
    // 清理动画
    this.stopPlaying();
  }

  // 初始化可视化数据
  initVisualizationData() {
    this.visualizationData = [];
    for (let i = 0; i < 20; i++) {
      this.visualizationData.push(Math.random() * 0.5);
    }
  }

  // 更新可视化数据
  updateVisualizationData() {
    if (!this.isPlaying) {
      // 不播放时使用随机数据
      for (let i = 0; i < 20; i++) {
        this.visualizationData[i] = Math.random() * 0.5;
      }
    } else {
      // 播放时使用动态数据
      for (let i = 0; i < 20; i++) {
        const wave = Math.sin(Date.now() / 100 + i * 0.5) * 0.3 + 0.5;
        const random = Math.random() * 0.2;
        this.visualizationData[i] = Math.min(Math.max(wave + random, 0.1), 0.9);
      }
    }
  }

  // 创建TTS引擎
  createTtsEngine() {
    try {
      let extraParam: Record<string, Object> = {
        "style": 'interaction-broadcast',
        "locate": this.settings.language === 'zh-CN' ? 'CN' : 'US',
        "name": 'EnhancedTTS'
      };

      let initParamsInfo: textToSpeech.CreateEngineParams = {
        language: this.settings.language,
        person: this.settings.person,
        online: this.settings.online ? 1 : 0,
        extraParams: extraParam
      };

      textToSpeech.createEngine(initParamsInfo, (err: BusinessError, textToSpeechEngine: textToSpeech.TextToSpeechEngine) => {
        if (!err) {
          console.log('createEngine is success');
          ttsEngine = textToSpeechEngine;
          this.setListener();
          this.currentStatus = "就绪";
          promptAction.showToast({
            message: '✅ TTS引擎初始化成功',
            duration: 2000
          });
        } else {
          console.error("errCode is " + JSON.stringify(err.code));
          console.error("errMessage is " + JSON.stringify(err.message));
          this.currentStatus = "错误: " + err.code;
          promptAction.showToast({
            message: `❌ 引擎创建失败: ${err.code}`,
            duration: 3000
          });
        }
      });
    } catch (error) {
      let message = (error as BusinessError).message;
      let code = (error as BusinessError).code;
      console.error(`createEngine failed, error code: ${code}, message: ${message}.`);
      this.currentStatus = "错误";
      promptAction.showToast({
        message: `❌ 引擎创建异常: ${code}`,
        duration: 3000
      });
    }
  }

  // 设置监听器
  setListener() {
    if (!ttsEngine) return;

    let speakListener: textToSpeech.SpeakListener = {
      onStart: (utteranceId: string, response: textToSpeech.StartResponse) => {
        console.log('onStart: ', utteranceId, response);
        this.currentStatus = "播放中";
        this.isPlaying = true;
      },

      onComplete: (utteranceId: string, response: textToSpeech.CompleteResponse) => {
        console.log('onComplete: ', utteranceId, response);
        this.currentStatus = "播放完成";
        this.isPlaying = false;
      },

      onStop: (utteranceId: string, response: textToSpeech.StopResponse) => {
        console.log('onStop: ', utteranceId, response);
        this.currentStatus = "已停止";
        this.isPlaying = false;
      },

      onData: (utteranceId: string, audio: ArrayBuffer, response: textToSpeech.SynthesisResponse) => {
        // 更新可视化数据
        this.updateVisualizationData();
      },

      onError: (utteranceId: string, errorCode: number, errorMessage: string) => {
        console.error('onError: ', utteranceId, errorCode, errorMessage);
        this.currentStatus = "错误: " + errorMessage;
        this.isPlaying = false;

        promptAction.showToast({
          message: `❌ 错误: ${errorCode}`,
          duration: 3000
        });
      }
    };

    ttsEngine.setListener(speakListener);
  }

  // 开始播放
  startPlaying() {
    if (!ttsEngine) {
      promptAction.showToast({
        message: '⚠️ 请先创建TTS引擎',
        duration: 2000
      });
      return;
    }

    if (!this.text || this.text.trim().length === 0) {
      promptAction.showToast({
        message: '⚠️ 请输入文本内容',
        duration: 2000
      });
      return;
    }

    let extraParam: Record<string, Object> = {
      "queueMode": 0,
      "speed": this.settings.speed,
      "volume": this.settings.volume,
      "pitch": this.settings.pitch,
      "languageContext": this.settings.language,
      "audioType": this.settings.audioType,
      "soundChannel": 1,
      "playType": this.settings.playType
    };

    let speakParams: textToSpeech.SpeakParams = {
      requestId: UuidBasic.createUUID(),
      extraParams: extraParam
    };

    this.isPlaying = true;
    this.currentStatus = "播放中";

    try {
      ttsEngine.speak(this.text, speakParams);
    } catch (error) {
      console.error('speak error:', error);
      this.currentStatus = "错误";
      this.isPlaying = false;
      promptAction.showToast({
        message: '❌ 播放失败',
        duration: 2000
      });
    }
  }

  // 停止播放
  stopPlaying() {
    if (ttsEngine) {
      ttsEngine.stop();
      this.isPlaying = false;
      this.currentStatus = "已停止";
    }
  }

  // 获取状态颜色
  getStatusColor(): ResourceColor {
    switch (this.currentStatus) {
      case '播放中': return '#4CAF50';
      case '错误': return '#FF6B6B';
      case '就绪': return '#317AE7';
      case '已停止': return '#FF9800';
      case '准备就绪': return '#666666';
      case '播放完成': return '#9C27B0';
      default: return Color.Gray;
    }
  }

  // 获取状态表情
  getStatusEmoji(): string {
    switch (this.currentStatus) {
      case '播放中': return '🔊';
      case '错误': return '❌';
      case '就绪': return '✅';
      case '已停止': return '⏹️';
      case '准备就绪': return '⚡';
      case '播放完成': return '🎉';
      default: return '📱';
    }
  }

  build() {
    Column() {
      // 1. 标题栏
      Row({ space: 20 }) {
        Text("🔊 TTS语音合成")
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1)

        Button() {
          Text(this.isDarkMode ? "☀️" : "🌙")
            .fontSize(20)
        }
        .type(ButtonType.Circle)
        .backgroundColor(Color.White)
        .onClick(() => {
          this.isDarkMode = !this.isDarkMode;
        })
      }
      .width('100%')
      .padding(20)
      .backgroundColor('#317AE7')
      .margin({ bottom: 16 })

      Scroll() {
        Column({ space: 16 }) {
          // 2. 文本输入区域
          Column({ space: 8 }) {
            Text("📝 请输入文本内容:")
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .textAlign(TextAlign.Start)
              .fontColor(this.isDarkMode ? Color.White : Color.Black)

            TextArea({ placeholder: '请输入要合成的文本内容...', text: this.text })
              .width('100%')
              .height(120)
              .focusable(true)
              .border({ width: 2, color: 0x317AE7, radius: 8 })
              .backgroundColor(this.isDarkMode ? '#2D2D2D' : Color.White)
              .fontColor(this.isDarkMode ? Color.White : Color.Black)
              .onChange((value: string) => {
                this.text = value;
              })
          }
          .width('100%')
          .padding(15)
          .backgroundColor(this.isDarkMode ? '#2D2D2D' : Color.White)
          .borderRadius(12)

          // 3. 参数控制
          Column({ space: 8 }) {
            Text("⚙️ 参数控制")
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .textAlign(TextAlign.Start)
              .fontColor(this.isDarkMode ? Color.White : Color.Black)

            // 语速控制
            Row({ space: 10 }) {
              Text("🎵 语速:")
                .fontSize(14)
                .fontColor(this.isDarkMode ? Color.White : '#333')
                .width(60)

              Slider({
                value: this.settings.speed,
                min: 0.5,
                max: 2.0,
                step: 0.1
              })
                .layoutWeight(1)
                .onChange((value: number) => {
                  this.settings.speed = value;
                })

              Text(this.settings.speed.toFixed(1))
                .fontSize(14)
                .fontColor(this.isDarkMode ? Color.White : '#333')
                .width(40)
            }
            .width('100%')

            // 音量控制
            Row({ space: 10 }) {
              Text("🔈 音量:")
                .fontSize(14)
                .fontColor(this.isDarkMode ? Color.White : '#333')
                .width(60)

              Slider({
                value: this.settings.volume,
                min: 0.0,
                max: 1.0,
                step: 0.1
              })
                .layoutWeight(1)
                .onChange((value: number) => {
                  this.settings.volume = value;
                })

              Text(this.settings.volume.toFixed(1))
                .fontSize(14)
                .fontColor(this.isDarkMode ? Color.White : '#333')
                .width(40)
            }
            .width('100%')

            // 音高控制
            Row({ space: 10 }) {
              Text("🎼 音高:")
                .fontSize(14)
                .fontColor(this.isDarkMode ? Color.White : '#333')
                .width(60)

              Slider({
                value: this.settings.pitch,
                min: 0.5,
                max: 2.0,
                step: 0.1
              })
                .layoutWeight(1)
                .onChange((value: number) => {
                  this.settings.pitch = value;
                })

              Text(this.settings.pitch.toFixed(1))
                .fontSize(14)
                .fontColor(this.isDarkMode ? Color.White : '#333')
                .width(40)
            }
            .width('100%')
          }
          .width('100%')
          .padding(15)
          .backgroundColor(this.isDarkMode ? '#2D2D2D' : Color.White)
          .borderRadius(12)

          // 4. 音频可视化
          Column({ space: 8 }) {
            Text("📊 音频可视化")
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .textAlign(TextAlign.Start)
              .fontColor(this.isDarkMode ? Color.White : Color.Black)

            Canvas(this.ctx)
              .width('100%')
              .height(100)
              .backgroundColor(this.isDarkMode ? '#333333' : '#F0F0F0')
              .onReady(() => {
                this.canvasReady = true;
                this.updateCanvas();
              })
          }
          .width('100%')
          .padding(15)
          .backgroundColor(this.isDarkMode ? '#2D2D2D' : Color.White)
          .borderRadius(12)

          // 5. 控制按钮
          Column({ space: 10 }) {
            Row({ space: 10 }) {
              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Text("🚀 创建引擎")
                  .fontColor(Color.White)
                  .fontSize(16)
              }
              .backgroundColor('#317AE7')
              .borderRadius(8)
              .layoutWeight(1)
              .height(45)
              .onClick(() => {
                this.createTtsEngine();
              })

              Button({ type: ButtonType.Normal, stateEffect: true }) {
                if (this.isPlaying) {
                  Text("⏹️ 停止")
                    .fontColor(Color.White)
                    .fontSize(16)
                } else {
                  Text("▶️ 播放")
                    .fontColor(Color.White)
                    .fontSize(16)
                }
              }
              .backgroundColor(this.isPlaying ? '#FF6B6B' : '#4CAF50')
              .borderRadius(8)
              .layoutWeight(1)
              .height(45)
              .onClick(() => {
                if (this.isPlaying) {
                  this.stopPlaying();
                } else {
                  this.startPlaying();
                }
              })
            }
            .width('100%')

            Row({ space: 10 }) {
              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Text("🗑️ 清空文本")
                  .fontColor(Color.White)
                  .fontSize(14)
              }
              .backgroundColor('#607D8B')
              .borderRadius(8)
              .layoutWeight(1)
              .height(40)
              .onClick(() => {
                this.text = "";
              })

              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Text("🔄 重置参数")
                  .fontColor(Color.White)
                  .fontSize(14)
              }
              .backgroundColor('#FF9800')
              .borderRadius(8)
              .layoutWeight(1)
              .height(40)
              .onClick(() => {
                this.settings.speed = 1.0;
                this.settings.volume = 1.0;
                this.settings.pitch = 1.0;
                promptAction.showToast({
                  message: '参数已重置',
                  duration: 1000
                });
              })
            }
            .width('100%')
          }
          .width('100%')
          .padding(15)
          .backgroundColor(this.isDarkMode ? '#2D2D2D' : Color.White)
          .borderRadius(12)

          // 6. 状态显示
          Column({ space: 8 }) {
            Text("📱 系统状态")
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .textAlign(TextAlign.Start)
              .fontColor(this.isDarkMode ? Color.White : Color.Black)

            Row({ space: 10 }) {
              Text(this.getStatusEmoji() + " 状态:")
                .fontSize(14)
                .fontColor(this.isDarkMode ? Color.White : '#333')

              Text(this.currentStatus)
                .fontSize(14)
                .fontColor(this.getStatusColor())
                .layoutWeight(1)
                .textAlign(TextAlign.End)
            }
            .width('100%')
            .padding({ top: 5, bottom: 5 })

            Row({ space: 10 }) {
              Text("🔤 字符数:")
                .fontSize(14)
                .fontColor(this.isDarkMode ? Color.White : '#333')

              Text(this.text.length.toString())
                .fontSize(14)
                .fontColor(this.isDarkMode ? Color.White : '#333')
                .layoutWeight(1)
                .textAlign(TextAlign.End)
            }
            .width('100%')
            .padding({ top: 5, bottom: 5 })
          }
          .width('100%')
          .padding(15)
          .backgroundColor(this.isDarkMode ? '#2D2D2D' : Color.White)
          .borderRadius(12)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 20 })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? '#1E1E1E' : '#F5F5F5')
  }

  // Canvas 上下文
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D();

  // 更新 Canvas
  updateCanvas() {
    if (!this.canvasReady) return;

    this.updateVisualizationData();

    const width = 300; // Canvas 宽度
    const height = 100; // Canvas 高度
    const barCount = this.visualizationData.length;
    const barWidth = width / barCount;

    // 清除画布
    this.ctx.clearRect(0, 0, width, height);

    // 绘制背景
    this.ctx.fillStyle = this.isDarkMode ? '#333333' : '#F0F0F0';
    this.ctx.fillRect(0, 0, width, height);

    // 绘制音频柱状图
    for (let i = 0; i < barCount; i++) {
      const barHeight = this.visualizationData[i] * height * 0.8;
      const x = i * barWidth + 1;
      const y = (height - barHeight) / 2;

      // 创建渐变效果
      const gradient = this.ctx.createLinearGradient(x, y, x, y + barHeight);
      if (this.isPlaying) {
        gradient.addColorStop(0, '#4CAF50');
        gradient.addColorStop(0.5, '#8BC34A');
        gradient.addColorStop(1, '#CDDC39');
      } else {
        gradient.addColorStop(0, '#317AE7');
        gradient.addColorStop(1, '#2196F3');
      }

      this.ctx.fillStyle = gradient;
      this.ctx.fillRect(x, y, barWidth - 2, barHeight);
    }
  }
}