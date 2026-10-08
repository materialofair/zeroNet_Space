# 计算器解锁验证记录（2026-10-08）

## 原因与修复

计算器原先解密 `disguisePassword` 副本后比对输入；副本使用
`identifierForVendor` 派生的字符串加密。开发包与 App Store 包的 vendor ID
可能不同，副本解密失败时密码序列为空，但 `isDisguisePasswordSet` 标记仍存在，
用户留在计算器页且正确密码不触发解锁。旧副本未同步也会匹配过期密码。

计算器现在直接调用 `verifyPassword` 验证主密码哈希，与普通登录共用验证依据，
不再读取设备标识绑定的副本。保持原有数据密码解密及访客验证流程。
旧 Keychain 条目和媒体数据没有清除或重加密。

## 验证命令与结果

```sh
xcodebuild test -scheme ZeroNet-Space -configuration Release -destination 'platform=iOS Simulator,id=7D7DA111-3384-4622-8976-F59F28EFFE4F' -derivedDataPath /tmp/zeronet-auth-release -only-testing:ZeroNet-SpaceTests/CalculatorUnlockTests ENABLE_TESTABILITY=YES
xcodebuild test -scheme ZeroNet-Space -configuration Release -destination 'platform=iOS Simulator,id=7D7DA111-3384-4622-8976-F59F28EFFE4F' -derivedDataPath /tmp/zeronet-auth-release -only-testing:ZeroNet-SpaceTests ENABLE_TESTABILITY=YES
xcodebuild build -scheme ZeroNet-Space -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/zeronet-auth-device-release CODE_SIGNING_ALLOWED=NO
git diff --check
```

- 修复前：4 项新增测试中 3 项失败；vendor ID 变化和副本缺失时正确密码无法解锁，过期副本可错误触发解锁。访客/错误密码用例通过。
- 修复后：37 项单元测试全部通过，0 项跳过；4 项新增回归测试全部通过。
- iOS arm64 Release 构建通过；未签名，未安装到真机。
- 日志：`/tmp/zeronet-auth-regression-before.log`、`/tmp/zeronet-auth-regression-after.log`、`/tmp/zeronet-auth-device-release.log`。
- 测试使用 UUID 命名的 Keychain service 和独立 NotificationCenter，避免改动正常凭据或触发应用的认证通知。

## 尚需验证

尚未读取用户真机上的故障日志，vendor ID 变化是与症状一致、已由回归测试复现的原因，
并未测量该手机实际的旧/新 ID。未覆盖安装现有 App Store 包到修复发行包的升级过程。
需要发布修复版本后，在原有数据保留的前提下，输入原主密码并按等号验证解锁与媒体读取。
现有 Swift 并发兼容性和资源警告未在本次修复中处理。

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
