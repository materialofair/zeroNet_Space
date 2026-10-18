import SwiftUI
import UIKit

extension Notification.Name {
    static let vaultWillLock = Notification.Name("SealedPocket.vaultWillLock")
}

/// Tracks whole-app timeout semantics while protecting each scene independently.
struct PrivacyLifecycleState {
    enum Phase { case active, inactive, background }
    private(set) var phases: [String: Phase] = [:]
    private(set) var backgroundedAt: Date?
    private var generations: [String: Int] = [:]
    private var serial = 0

    mutating func register(_ id: String, phase: Phase, now: Date = Date()) {
        guard phases[id] == nil else { return }
        phases[id] = phase
        invalidate(id)
        if phase == .background && phases.values.allSatisfy({ $0 == .background })
            && backgroundedAt == nil {
            backgroundedAt = now
        }
    }

    mutating func invalidate(_ id: String) {
        serial += 1
        generations[id] = serial
    }

    mutating func deactivate(_ id: String) {
        phases[id] = .inactive
        invalidate(id)
    }

    mutating func enterBackground(_ id: String, now: Date) {
        phases[id] = .background
        invalidate(id)
        if phases.values.allSatisfy({ $0 == .background }) && backgroundedAt == nil {
            backgroundedAt = now
        }
    }

    func shouldLock(now: Date, timeout: AutoLockTimeout,
                    authenticated: Bool, recording: Bool) -> Bool {
        guard authenticated, !recording, timeout != .never,
              let backgroundedAt else { return false }
        return now.timeIntervalSince(backgroundedAt) >= Double(timeout.rawValue)
    }

    mutating func activate(_ id: String, now: Date, timeout: AutoLockTimeout,
                           authenticated: Bool, recording: Bool) -> Bool {
        let lock = shouldLock(now: now, timeout: timeout,
                              authenticated: authenticated, recording: recording)
        backgroundedAt = nil
        phases[id] = .active
        invalidate(id)
        return lock
    }

    mutating func disconnect(_ id: String, now: Date = Date()) {
        phases.removeValue(forKey: id)
        generations.removeValue(forKey: id)
        // Scene lifetimes are shorter than the shared authentication session. Keep
        // an existing background origin even when every scene disconnects; only
        // the next activation decision consumes it. No observed background means
        // a disconnect alone must not manufacture a timeout.
        if !phases.isEmpty && phases.values.allSatisfy({ $0 == .background })
            && backgroundedAt == nil {
            backgroundedAt = now
        }
    }

    func generation(for id: String) -> Int { generations[id] ?? -1 }

    func canReveal(_ id: String, generation: Int) -> Bool {
        phases[id] == .active && generations[id] == generation
    }
}

/// Attached directly to each window, above UIKit presentations and their snapshots.
/// It never becomes key and is not a separate scene/window with its own lifecycle.
@MainActor
final class PrivacyWindowCover {
    weak var window: UIWindow?
    let view = UIView()

    init(window: UIWindow) {
        self.window = window
        view.backgroundColor = .systemBackground
        view.isOpaque = true
        view.layer.zPosition = 10_000
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = "privacy-shield"
        view.accessibilityLabel = "SealedPocket"
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let label = UILabel()
        label.text = "SealedPocket"
        label.font = .systemFont(ofSize: 28, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    func show() {
        guard let window else { return }
        UIView.performWithoutAnimation {
            view.frame = window.bounds
            if view.superview !== window { window.addSubview(view) }
            window.bringSubviewToFront(view)
            window.layoutIfNeeded()
        }
    }

    func hide() { view.removeFromSuperview() }
}

@MainActor
final class PrivacyShieldCoordinator: NSObject {
    static let shared = PrivacyShieldCoordinator()

    private final class SceneEntry {
        weak var scene: UIWindowScene?
        var covers: [ObjectIdentifier: PrivacyWindowCover] = [:]
        init(_ scene: UIWindowScene) { self.scene = scene }
    }

    private weak var authentication: AuthenticationViewModel?
    private var scenes: [String: SceneEntry] = [:]
    private var state = PrivacyLifecycleState()

    override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(willDeactivate), name: UIScene.willDeactivateNotification, object: nil)
        center.addObserver(self, selector: #selector(didEnterBackground), name: UIScene.didEnterBackgroundNotification, object: nil)
        center.addObserver(self, selector: #selector(willEnterForeground), name: UIScene.willEnterForegroundNotification, object: nil)
        center.addObserver(self, selector: #selector(didActivate), name: UIScene.didActivateNotification, object: nil)
        center.addObserver(self, selector: #selector(didDisconnect), name: UIScene.didDisconnectNotification, object: nil)
        center.addObserver(self, selector: #selector(willLock), name: .vaultWillLock, object: nil)
        center.addObserver(self, selector: #selector(windowBecameVisible), name: UIWindow.didBecomeVisibleNotification, object: nil)
        // App notifications also cover interruptions that arrive before a scene callback.
        center.addObserver(self, selector: #selector(applicationWillResign), name: UIApplication.willResignActiveNotification, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    func attach(_ scene: UIWindowScene, authentication: AuthenticationViewModel) {
        self.authentication = authentication
        let id = scene.session.persistentIdentifier
        guard scenes[id] == nil else { return }
        scenes[id] = SceneEntry(scene)
        let phase: PrivacyLifecycleState.Phase = scene.activationState == .foregroundActive
            ? .active : (scene.activationState == .background ? .background : .inactive)
        state.register(id, phase: phase)
        cover(id)
        // A SwiftUI window can attach after its activation notification. Bootstrap
        // under the shield, including a newly restored scene after a long background.
        if phase == .active {
            DispatchQueue.main.async { [weak self, weak scene] in
                guard let self, let scene else { return }
                self.didActivate(Notification(name: UIScene.didActivateNotification, object: scene))
            }
        }
    }

    private func sceneID(_ notification: Notification) -> String? {
        guard let scene = notification.object as? UIWindowScene,
              scenes[scene.session.persistentIdentifier] != nil else { return nil }
        return scene.session.persistentIdentifier
    }

    private func cover(_ id: String) {
        guard let entry = scenes[id], let scene = entry.scene else { return }
        entry.covers = entry.covers.filter { $0.value.window != nil }
        for window in scene.windows where !window.isHidden && window.alpha > 0 {
            let key = ObjectIdentifier(window)
            let shield = entry.covers[key] ?? PrivacyWindowCover(window: window)
            entry.covers[key] = shield
            shield.show()
        }
    }

    /// Wait for the SwiftUI authentication transaction/layout, never a timed fade.
    /// A new interruption invalidates this reveal before either main-loop turn.
    private func revealAfterLayout(_ id: String) {
        let generation = state.generation(for: id)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.state.canReveal(id, generation: generation) else { return }
            self.scenes[id]?.scene?.windows.forEach { $0.layoutIfNeeded() }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.state.canReveal(id, generation: generation),
                      self.scenes[id]?.scene?.activationState == .foregroundActive else { return }
                self.scenes[id]?.covers.values.forEach { $0.hide() }
            }
        }
    }

    @objc private func willDeactivate(_ notification: Notification) {
        guard let id = sceneID(notification) else { return }
        state.deactivate(id)
        cover(id)
    }

    @objc private func applicationWillResign(_ notification: Notification) {
        for (id, entry) in scenes where entry.scene?.activationState == .foregroundActive {
            state.deactivate(id)
            cover(id)
        }
    }

    @objc private func didEnterBackground(_ notification: Notification) {
        guard let id = sceneID(notification) else { return }
        state.enterBackground(id, now: Date())
        cover(id)
        // Immediately revokes the session behind the shield, before a return animation.
        if AppSettings.shared.autoLockTimeout == .immediately,
           state.shouldLock(now: Date(), timeout: .immediately,
                            authenticated: authentication?.isAuthenticated == true,
                            recording: AudioSessionController.shared.hasRecording) {
            authentication?.logout()
        }
    }

    @objc private func willEnterForeground(_ notification: Notification) {
        guard let id = sceneID(notification) else { return }
        state.invalidate(id)
        cover(id)
    }

    @objc private func didActivate(_ notification: Notification) {
        guard let id = sceneID(notification),
              scenes[id]?.scene?.activationState == .foregroundActive else { return }
        cover(id)
        let lock = state.activate(id, now: Date(), timeout: AppSettings.shared.autoLockTimeout,
                                  authenticated: authentication?.isAuthenticated == true,
                                  recording: AudioSessionController.shared.hasRecording)
        if lock { authentication?.logout() }
        revealAfterLayout(id)
    }

    @objc private func willLock(_ notification: Notification) {
        guard let source = notification.object as? AuthenticationViewModel,
              source === authentication else { return }
        // Raise covers BEFORE the authentication flag/caches change. Presented UIKit
        // controllers are dismissed without animation while their pixels are covered.
        for (id, entry) in scenes {
            state.invalidate(id)
            cover(id)
            entry.scene?.windows.forEach {
                $0.rootViewController?.presentedViewController?.dismiss(animated: false)
            }
            if state.phases[id] == .active { revealAfterLayout(id) }
        }
    }

    @objc private func windowBecameVisible(_ notification: Notification) {
        guard let window = notification.object as? UIWindow,
              let id = window.windowScene?.session.persistentIdentifier,
              let entry = scenes[id] else { return }
        let alreadyCovered = entry.covers.values.contains { $0.view.superview != nil }
        if state.phases[id] != .active || alreadyCovered { cover(id) }
    }

    @objc private func didDisconnect(_ notification: Notification) {
        guard let id = sceneID(notification) else { return }
        scenes.removeValue(forKey: id)?.covers.values.forEach { $0.hide() }
        state.disconnect(id)
        if AppSettings.shared.autoLockTimeout == .immediately,
           state.shouldLock(now: Date(), timeout: .immediately,
                            authenticated: authentication?.isAuthenticated == true,
                            recording: AudioSessionController.shared.hasRecording) {
            authentication?.logout()
        }
    }
}

struct PrivacySceneObserver: UIViewRepresentable {
    let authentication: AuthenticationViewModel

    final class Probe: UIView {
        var authentication: AuthenticationViewModel?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let scene = window?.windowScene, let authentication {
                PrivacyShieldCoordinator.shared.attach(scene, authentication: authentication)
            }
        }
    }

    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.authentication = authentication
        return view
    }

    func updateUIView(_ view: Probe, context: Context) {
        view.authentication = authentication
        if let scene = view.window?.windowScene {
            PrivacyShieldCoordinator.shared.attach(scene, authentication: authentication)
        }
    }
}
