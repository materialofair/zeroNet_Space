# 音频模块验证记录（2026-09-06）

## 验证环境

Xcode / iOS 26.5 SDK，iPhone 17 模拟器。当前机器没有 iPhone 15 模拟器，所以使用可用的 iPhone 17。应用最低版本仍为 iOS 17.6。

模拟器测试使用 `CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES` 本地临时签名；未修改项目的开发团队或签名配置。关闭签名的构建可编译，但模拟器登录流程写入 Keychain 会失败。

## 需真机验收

- 麦克风首次授权、拒绝后从系统设置重新授权。
- 录音音质、长时间录制、暂停/继续与来电中断。
- 锁屏/切后台自动结束保存，返回后按现有自动锁定策略重新认证。
- 低存储空间时保留录音供重试；取消、保存完成和退出认证后的临时文件清理。
- 访客模式隐藏音频列表并禁止导入、录音、播放、重命名与删除。
- iOS 17.6 与 iPad 布局尚未在对应运行时验收。

## 构建提示

已有 SwiftData 主线程隔离/Swift 6 兼容性及资源目录未分配图片警告仍存在。本次未更改这些无关配置或资源。

## 已完成的验证

- `xcodebuild -scheme ZeroNet-Space -destination 'platform=iOS Simulator,id=F2782680-DF7F-4426-BD3E-38B904C76527' -derivedDataPath /tmp/zeronet-audio-build build CODE_SIGNING_ALLOWED=NO`：构建通过。
- 最终本地签名测试：`xcodebuild -scheme ZeroNet-Space -destination 'platform=iOS Simulator,id=F2782680-DF7F-4426-BD3E-38B904C76527' -derivedDataPath /tmp/zeronet-audio-build -resultBundlePath /tmp/zeronet-audio-final.xcresult -only-testing:ZeroNet-SpaceTests -only-testing:ZeroNet-SpaceUITests/AudioUITests -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 90 test CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES`。
- 19 项单元测试通过（14 项 XCTest + 5 项 Swift Testing），其中 6 项新增音频测试覆盖格式识别、旧数据兼容、真实 WAV 加密往返、损坏输入拒绝、取消导入及遗留明文清理。
- `AudioUITests.testAudioNavigationAndImportPicker` 通过：底部五项顺序、音频按钮、设置打开/关闭、系统音频文件选择器打开/取消。
- `git diff --check` 通过；`plutil -lint` 检查项目文件和中英文 InfoPlist.strings 通过；构建产物包含 NSMicrophoneUsageDescription。

## 未通过的录音 UI 验证

`AudioUITests.testAudioNavigationRecordingPlaybackAndDelete` 在当前 iOS 26.5 模拟器的 `AVAudioRecorder.prepareToRecord()` 卡住。进程采样落在 AudioToolbox 的 `AudioQueueObject::ConnectToIONodeEffects` / `AQMixEngine_Base::DevLock` 等待；未执行到暂停、保存、重命名、删除等后续断言。切换模拟器输出设备及重启未解决，输出设备已恢复为原系统默认值。不将此用例计为通过，完整录音链路仍需要真机验收。

本次改为只录音的 AVAudioSession.record 类别，播放时单独切换 playback；不启用后台持续录音。已有可解码音频的加密和解密测试通过，但不等同于麦克风硬件验收。
