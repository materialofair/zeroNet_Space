//
//  AVAudioSession+VideoPlayback.swift
//  ZeroNet-Space
//
//  视频播放音频会话配置
//

import AVFoundation

extension AVAudioSession {

    /// 激活计数：内嵌预览和全屏播放器可能同时持有会话，只有最后一个释放时才真正停用。
    /// 仅在主线程访问（所有调用点均为视图生命周期方法）。
    private static var playbackActivationCount = 0

    /// 配置并激活视频播放的音频会话。
    ///
    /// 使用 `.playback` 类别，保证播放声音不受设备静音开关影响；
    /// 若 App 进入后台需由调用方暂停播放，避免后台继续出声。
    static func activateForVideoPlayback() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback)
            if playbackActivationCount == 0 {
                try session.setActive(true)
            }
            playbackActivationCount += 1
        } catch {
            print("⚠️ 音频会话激活失败: \(error)")
        }
    }

    /// 结束视频播放后释放音频会话；仅当没有播放器再持有时才真正停用，
    /// 避免一个播放器关闭时把另一个正在播放的播放器静音。
    static func deactivateAfterVideoPlayback() {
        playbackActivationCount = max(0, playbackActivationCount - 1)
        guard playbackActivationCount == 0 else { return }
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation)
    }
}
