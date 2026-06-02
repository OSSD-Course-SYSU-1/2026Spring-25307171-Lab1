import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { UuidBasic } from './UuidBasic';
import { promptAction } from '@kit.ArkUI';

const TAG: string = 'TtsDemo';
let ttsEngine: textToSpeech.TextToSpeechEngine;

// 设备类型
enum DeviceType {
  PHONE = 'phone',
  TABLET = 'tablet',
  DESKTOP = 'desktop',
  UNKNOWN = 'unknown'
}

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

  // 多端适配状态
  @State deviceType: DeviceType = DeviceType.PHONE;
  @State isLandscape: boolean = false;
  @State screenWidth: number = 360;
  @State screenHeight: number = 640;
  @State isTabletMode: boolean = false;
  @State isDesktopMode: boolean = false;

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

    // 检测设备类型
    this.detectDevice();
  }

  aboutToDisappear() {
    this.stopPlaying();
  }

  // 设备检测
  detectDevice() {
    try {
      this.isLandscape = this.screenWidth > this.screenHeight;
      const minDimension = Math.min(this.screenWidth, this.screenHeight);

      // 根据屏幕尺寸判断设备类型
      if (minDimension < 600) {
        this.deviceType = DeviceType.PHONE;
        this.isTabletMode = false;
        this.isDesktopMode = false;
      } else if (minDimension < 1200) {
        this.deviceType = DeviceType.TABLET;
        this.isTabletMode = true;
        this.isDesktopMode = false;
      } else {
        this.deviceType = DeviceType.DESKTOP;
        this.isTabletMode = false;
        this.isDesktopMode = true;
      }
    } catch (error) {
      console.error('设备检测失败:', error);
    }
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
      for (let i = 0; i < 20; i++) {
        this.visualizationData[i] = Math.random() * 0.5;
      }
    } else {
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

  // 获取设备图标
  getDeviceIcon(): string {
    switch (this.deviceType) {
      case DeviceType.PHONE: return '📱';
      case DeviceType.TABLET: return '📱';
      case DeviceType.DESKTOP: return '💻';
      default: return '📱';
    }
  }

  // 获取设备描述
  getDeviceDescription(): string {
    switch (this.deviceType) {
      case DeviceType.PHONE:
        return this.isLandscape ? '手机横屏' : '手机竖屏';
      case DeviceType.TABLET:
        return this.isLandscape ? '平板横屏' : '平板竖屏';
      case DeviceType.DESKTOP: return '桌面端';
      default: return '未知设备';
    }
  }

  // 获取状态颜色
  getStatusColor(): string {
    switch (this.currentStatus) {
      case '播放中': return '#4CAF50';
      case '错误': return '#FF6B6B';
      case '就绪': return '#317AE7';
      case '已停止': return '#FF9800';
      case '准备就绪': return '#666666';
      case '播放完成': return '#9C27B0';
      default: return '#999999';
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

  // 获取字体大小
  getFontSize(): number {
    if (this.isDesktopMode) return 18;
    if (this.isTabletMode) return 16;
    return 14;
  }

  // 获取按钮高度
  getButtonHeight(): number {
    if (this.isDesktopMode) return 50;
    if (this.isTabletMode) return 45;
    return 40;
  }

  // 获取间距
  getSpacing(): number {
    if (this.isDesktopMode) return 20;
    if (this.isTabletMode) return 16;
    return 12;
  }

  // 获取圆角
  getBorderRadius(): number {
    if (this.isDesktopMode) return 12;
    if (this.isTabletMode) return 10;
    return 8;
  }

  build() {
    Column() {
      // 标题栏 - 修正后的代码
      Row({ space: 20 }) {
        Text(`${this.getDeviceIcon()} TTS语音合成`)
          .fontSize(this.getFontSize() + 8)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1)

        Row({ space: 8 }) {
          Text(this.getDeviceDescription())
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))

          Button() {
            Text(this.isDarkMode ? "☀️" : "🌙")
              .fontSize(this.getFontSize())
          }
          .type(ButtonType.Circle)
          .backgroundColor(Color.White)
          .width(this.getButtonHeight())
          .height(this.getButtonHeight())
          .onClick(() => {
            this.isDarkMode = !this.isDarkMode;
          })
        }
      }
      .width('100%')
      .padding(20)
      .backgroundColor('#317AE7')

      Scroll() {
        Column({ space: this.getSpacing() }) {
          // 文本输入区域
          Column({ space: 8 }) {
            Text("📝 请输入文本内容:")
              .fontSize(this.getFontSize())
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .fontColor(this.isDarkMode ? Color.White : Color.Black)

            TextArea({ placeholder: '请输入要合成的文本内容...', text: this.text })
              .width('100%')
              .height(120)
              .focusable(true)
              .border({ width: 2, color: 0x317AE7, radius: this.getBorderRadius() })
              .backgroundColor(this.isDarkMode ? '#2D2D2D' : Color.White)
              .fontColor(this.isDarkMode ? Color.White : Color.Black)
              .fontSize(this.getFontSize())
              .onChange((value: string) => {
                this.text = value;
              })
          }
          .width('100%')
          .padding(this.getSpacing())
          .backgroundColor(this.isDarkMode ? '#2D2D2D' : Color.White)
          .borderRadius(this.getBorderRadius())

          // 参数控制区域
          Column({ space: 12 }) {
            Text("⚙️ 参数控制")
              .fontSize(this.getFontSize())
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .fontColor(this.isDarkMode ? Color.White : Color.Black)

            // 语速控制
            Row({ space: 10 }) {
              Text("🎵 语速:")
                .fontSize(this.getFontSize() - 2)
                .fontColor(this.isDarkMode ? Color.White : '#333')
                .width(60)

              Slider({
                value: this.settings.speed,
                min: 0.5,
                max: 2.0,
                step: 0.1
              })
                .layoutWeight(1)
                .height(this.getButtonHeight())
                .onChange((value: number) => {
                  this.settings.speed = value;
                })

              Text(this.settings.speed.toFixed(1))
                .fontSize(this.getFontSize() - 2)
                .fontColor(this.isDarkMode ? Color.White : '#333')
                .width(40)
            }
            .width('100%')

            // 音量控制
            Row({ space: 10 }) {
              Text("🔈 音量:")
                .fontSize(this.getFontSize() - 2)
                .fontColor(this.isDarkMode ? Color.White : '#333')
                .width(60)

              Slider({
                value: this.settings.volume,
                min: 0.0,
                max: 1.0,
                step: 0.1
              })
                .layoutWeight(1)
                .height(this.getButtonHeight())
                .onChange((value: number) => {
                  this.settings.volume = value;
                })

              Text(this.settings.volume.toFixed(1))
                .fontSize(this.getFontSize() - 2)
                .fontColor(this.isDarkMode ? Color.White : '#333')
                .width(40)
            }
            .width('100%')

            // 音高控制
            Row({ space: 10 }) {
              Text("🎼 音高:")
                .fontSize(this.getFontSize() - 2)
                .fontColor(this.isDarkMode ? Color.White : '#333')
                .width(60)

              Slider({
                value: this.settings.pitch,
                min: 0.5,
                max: 2.0,
                step: 0.1
              })
                .layoutWeight(1)
                .height(this.getButtonHeight())
                .onChange((value: number) => {
                  this.settings.pitch = value;
                })

              Text(this.settings.pitch.toFixed(1))
                .fontSize(this.getFontSize() - 2)
                .fontColor(this.isDarkMode ? Color.White : '#333')
                .width(40)
            }
            .width('100%')
          }
          .width('100%')
          .padding(this.getSpacing())
          .backgroundColor(this.isDarkMode ? '#2D2D2D' : Color.White)
          .borderRadius(this.getBorderRadius())

          // 音频状态显示
          Column({ space: 8 }) {
            Text("🔊 音频状态")
              .fontSize(this.getFontSize())
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .fontColor(this.isDarkMode ? Color.White : Color.Black)

            // 实用的信息卡片
            Row({ space: 12 }) {
              // 播放状态
              Column({ space: 4 }) {
                Text(this.isPlaying ? "▶️" : "⏸️")
                  .fontSize(24)
                Text(this.isPlaying ? "播放中" : "已停止")
                  .fontSize(12)
                  .fontColor(this.isPlaying ? '#4CAF50' : '#666666')
              }
              .width(60)
              .height(60)
              .backgroundColor(this.isDarkMode ? '#2A2A2A' : '#F5F5F5')
              .borderRadius(8)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)

              // 字符数统计
              Column({ space: 4 }) {
                Text("🔤")
                  .fontSize(24)
                Text("字符数")
                  .fontSize(12)
                  .fontColor('#666666')
              }
              .width(60)
              .height(60)
              .backgroundColor(this.isDarkMode ? '#2A2A2A' : '#F5F5F5')
              .borderRadius(8)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .onClick(() => {
                promptAction.showToast({
                  message: `当前文本: ${this.text.length} 个字符`,
                  duration: 2000
                })
              })

              // 设备类型
              Column({ space: 4 }) {
                Text(this.deviceType === DeviceType.DESKTOP ? "💻" : "📱")
                  .fontSize(24)
                Text(this.deviceType === DeviceType.DESKTOP ? "电脑" :
                  this.deviceType === DeviceType.TABLET ? "平板" : "手机")
                  .fontSize(12)
                  .fontColor('#666666')
              }
              .width(60)
              .height(60)
              .backgroundColor(this.isDarkMode ? '#2A2A2A' : '#F5F5F5')
              .borderRadius(8)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceAround)

            // 实用信息行
            Row({ space: 15 }) {
              // 字符数
              Column() {
                Text(this.text.length.toString())
                  .fontSize(18)
                  .fontColor('#317AE7')
                  .fontWeight(FontWeight.Bold)
                Text("字符数")
                  .fontSize(10)
                  .fontColor('#666666')
              }

              // 分隔线
              Column() {
                Text("|")
                  .fontSize(16)
                  .fontColor('#CCCCCC')
              }

              // 语速
              Column() {
                Text(this.settings.speed.toFixed(1) + "x")
                  .fontSize(18)
                  .fontColor('#FF9800')
                  .fontWeight(FontWeight.Bold)
                Text("语速")
                  .fontSize(10)
                  .fontColor('#666666')
              }

              // 分隔线
              Column() {
                Text("|")
                  .fontSize(16)
                  .fontColor('#CCCCCC')
              }

              // 音量
              Column() {
                Text((this.settings.volume * 100).toFixed(0) + "%")
                  .fontSize(18)
                  .fontColor('#4CAF50')
                  .fontWeight(FontWeight.Bold)
                Text("音量")
                  .fontSize(10)
                  .fontColor('#666666')
              }
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 12 })
          }
          .width('100%')
          .padding(this.getSpacing())
          .backgroundColor(this.isDarkMode ? '#2D2D2D' : Color.White)
          .borderRadius(this.getBorderRadius())

          // 控制按钮
          Column({ space: 10 }) {
            // 主控制按钮
            Column({ space: 10 }) {
              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Text("🚀 创建引擎")
                  .fontColor(Color.White)
                  .fontSize(this.getFontSize())
              }
              .backgroundColor('#317AE7')
              .borderRadius(this.getBorderRadius())
              .width('100%')
              .height(this.getButtonHeight())
              .onClick(() => {
                this.createTtsEngine();
              })

              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Text(this.isPlaying ? "⏹️ 停止播放" : "▶️ 开始播放")
                  .fontColor(Color.White)
                  .fontSize(this.getFontSize())
              }
              .backgroundColor(this.isPlaying ? '#FF6B6B' : '#4CAF50')
              .borderRadius(this.getBorderRadius())
              .width('100%')
              .height(this.getButtonHeight())
              .onClick(() => {
                if (this.isPlaying) {
                  this.stopPlaying();
                } else {
                  this.startPlaying();
                }
              })
            }
            .width('100%')

            // 辅助按钮
            Row({ space: 10 }) {
              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Text("🗑️ 清空")
                  .fontColor(Color.White)
                  .fontSize(this.getFontSize() - 2)
              }
              .backgroundColor('#607D8B')
              .borderRadius(this.getBorderRadius())
              .layoutWeight(1)
              .height(this.getButtonHeight() - 5)
              .onClick(() => {
                this.text = "";
              })

              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Text("🔄 重置")
                  .fontColor(Color.White)
                  .fontSize(this.getFontSize() - 2)
              }
              .backgroundColor('#FF9800')
              .borderRadius(this.getBorderRadius())
              .layoutWeight(1)
              .height(this.getButtonHeight() - 5)
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
          .padding(this.getSpacing())
          .backgroundColor(this.isDarkMode ? '#2D2D2D' : Color.White)
          .borderRadius(this.getBorderRadius())

          // 状态显示
          Column({ space: 8 }) {
            Text("📱 系统状态")
              .fontSize(this.getFontSize())
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .fontColor(this.isDarkMode ? Color.White : Color.Black)

            // 状态行
            Row({ space: 10 }) {
              Text(this.getStatusEmoji() + " 状态:")
                .fontSize(this.getFontSize() - 2)
                .fontColor(this.isDarkMode ? Color.White : '#333')

              Text(this.currentStatus)
                .fontSize(this.getFontSize() - 2)
                .fontColor(this.getStatusColor())
                .layoutWeight(1)
                .textAlign(TextAlign.End)
            }
            .width('100%')
            .padding({ top: 5, bottom: 5 })

            // 字符数
            Row({ space: 10 }) {
              Text("🔤 字符数:")
                .fontSize(this.getFontSize() - 2)
                .fontColor(this.isDarkMode ? Color.White : '#333')

              Text(this.text.length.toString())
                .fontSize(this.getFontSize() - 2)
                .fontColor(this.isDarkMode ? Color.White : '#333')
                .layoutWeight(1)
                .textAlign(TextAlign.End)
            }
            .width('100%')
            .padding({ top: 5, bottom: 5 })

            // 设备信息
            Row({ space: 10 }) {
              Text("📱 设备:")
                .fontSize(this.getFontSize() - 2)
                .fontColor(this.isDarkMode ? Color.White : '#333')

              Text(this.getDeviceDescription())
                .fontSize(this.getFontSize() - 2)
                .fontColor('#317AE7')
                .layoutWeight(1)
                .textAlign(TextAlign.End)
            }
            .width('100%')
            .padding({ top: 5, bottom: 5 })
          }
          .width('100%')
          .padding(this.getSpacing())
          .backgroundColor(this.isDarkMode ? '#2D2D2D' : Color.White)
          .borderRadius(this.getBorderRadius())
        }
        .width('100%')
        .padding(this.getSpacing())
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? '#1E1E1E' : '#F5F5F5')
  }
}