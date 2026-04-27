TTS示例代码结构分析

一、整体架构设计

这是一个基于ArkTS实现的Text-to-Speech（TTS）语音合成示例应用，采用了鸿蒙系统的UI框架和TTS服务API。代码结构清晰，包含了完整的TTS功能演示：

1.1 核心组件

• 主组件：Index 结构体，作为应用入口

• 状态管理：使用@State装饰器管理组件状态

• TTS引擎：ttsEngine 全局变量，管理TTS服务实例

1.2 模块依赖

- @kit.CoreSpeechKit    // TTS核心服务
- @kit.BasicServicesKit  // 基础服务
- @kit.PerformanceAnalysisKit  // 日志工具
- @kit.ArkUI             // UI组件库


二、UI界面布局分析

2.1 布局结构

├── Scroll
│   └── Column
│       ├── TextArea (文本输入区域)
│       ├── 12个功能按钮
│       └── 状态展示区域


2.2 主要UI组件

1. TextArea：用于输入TTS合成的文本内容
2. Button：各种功能操作的触发按钮
3. promptAction：Toast提示，提供用户反馈

三、TTS功能实现原理

3.1 引擎创建功能

3.1.1 createByCallback() - 回调方式创建引擎

实现原理：
1. 设置引擎参数：
   let initParamsInfo: textToSpeech.CreateEngineParams = {
     language: 'zh-CN',  // 语言
     person: 0,          // 音色索引
     online: 1,         // 在线模式
     extraParams: {...}  // 额外参数
   };
   
2. 调用textToSpeech.createEngine()，通过回调函数处理结果
3. 成功时获取TextToSpeechEngine实例
4. 失败时捕获错误（错误码1002300005：引擎创建失败）

应用场景：适用于需要立即处理创建结果的场景

3.1.2 createByPromise() - Promise方式创建引擎

实现原理：
1. 使用Promise API异步创建引擎
2. 通过.then()处理成功结果
3. 通过.catch()处理异常
4. 参数配置与回调方式相同

优势：代码结构更简洁，适合现代异步编程

3.2 语音合成功能

3.2.1 speak() - 文本转语音合成

实现原理：
1. 配置合成参数：
   let speakParams: textToSpeech.SpeakParams = {
     requestId: UuidBasic.createUUID(),  // 唯一标识
     extraParams: {                       // 音质参数
       "queueMode": 0,    // 队列模式
       "speed": 1,        // 语速
       "volume": 2,       // 音量
       "pitch": 1,        // 音高
       "audioType": "pcm" // 音频格式
     }
   };
   
2. 设置监听器setListener()
3. 调用ttsEngine.speak(text, params)启动合成
4. 通过监听器接收合成状态和音频数据

音频流程：

文本输入 → 引擎处理 → 音频合成 → 回调通知 → 音频播放


3.3 监听器机制

3.3.1 setListener() - 事件监听

实现原理：
实现了textToSpeech.SpeakListener接口的5个回调方法：

1. onStart：合成开始时触发
   • 参数：utteranceId（合成ID）、response（开始响应）

   • 用途：开始播放提示

2. onComplete：合成完成时触发
   • 参数：utteranceId、response（完成响应）

   • 用途：播放完成处理

3. onStop：停止播放时触发
   • 参数：utteranceId、response（停止响应）

   • 用途：手动停止回调

4. onData：音频数据返回
   • 参数：utteranceId、audio（音频数据）、response（合成响应）

   • 用途：获取原始音频数据

5. onError：错误发生时触发
   • 参数：utteranceId、errorCode、errorMessage

   • 重要错误码：

     ◦ 1002300007：合成播放失败（引擎未初始化）

     ◦ 1002300006：服务忙（连续调用speak）

3.4 音色查询功能

3.4.1 listVoicesCallback() - 回调方式查询

实现原理：
1. 创建查询参数：
   let voicesQuery: textToSpeech.VoiceQuery = {
     requestId: UuidBasic.createUUID(),
     online: 1  // 查询在线音色
   };
   
2. 调用ttsEngine.listVoices(query, callback)
3. 返回支持的音色列表VoiceInfo[]

3.4.2 listVoicesPromise() - Promise方式查询

实现原理类似，使用Promise API处理异步结果

3.5 错误处理演示

3.5.1 createOfErrorLanguage() - 不支持的语言

实现原理：
1. 故意设置不支持的语言参数：language: 'ZH-CN'
2. 预期触发错误码：1002300002（语言不支持）

3.5.2 createOfErrorPerson() - 不支持的音色

实现原理：
1. 故意设置不存在的音色索引：person: 1
2. 预期触发错误码：1002300003（音色不支持）

3.5.3 illegalSpeak() - 非法文本

实现原理：
1. 使用空字符串或无效文本调用speak()
2. 预期触发错误码：1002300001（文本长度无效）

3.6 控制功能

3.6.1 stop() - 停止播放

实现原理：
• 直接调用ttsEngine.stop()

• 触发onStop监听器回调

• 立即中断当前合成

3.6.2 isBusy() - 查询忙状态

实现原理：
• 调用ttsEngine.isBusy()

• 返回布尔值表示引擎是否正在工作

• 用于防止重复调用

3.6.3 shutdown() - 关闭引擎

实现原理：
• 调用ttsEngine.shutdown()

• 释放引擎资源

• 需要重新创建引擎才能再次使用

四、关键技术点

4.1 状态管理

• 使用@State装饰器实现数据驱动UI更新

• 当状态变量改变时，自动触发UI重新渲染

4.2 异步处理

• 支持回调函数和Promise两种异步模式

• 合理处理异步操作的错误和结果

4.3 错误处理

• 通过BusinessError捕获异常

• 详细的错误码和错误信息

• 用户友好的Toast提示

4.4 日志系统

• 使用hilog进行性能分析和调试

• 关键操作记录日志，便于问题排查

五、工作流程


1. 创建引擎
   ├── 配置参数
   ├── 创建实例
   └── 错误处理

2. 配置监听
   ├── 实现SpeakListener
   └── 设置回调函数

3. 文本合成
   ├── 输入文本
   ├── 配置参数
   ├── 启动合成
   ├── 接收回调
   └── 播放控制

4. 资源管理
   ├── 状态查询
   ├── 停止播放
   └── 关闭引擎


六、最佳实践

1. 引擎复用：避免频繁创建和销毁引擎
2. 错误防御：在调用speak前检查引擎状态
3. 资源释放：不再使用时及时调用shutdown
4. 参数验证：验证输入参数的合法性
5. 用户体验：通过Toast提供操作反馈

这个示例完整展示了鸿蒙TTS API的使用方法，包括引擎管理、语音合成、状态监听、错误处理等核心功能，可以作为开发TTS应用的参考模板。