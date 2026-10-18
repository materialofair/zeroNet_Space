import Testing
import UIKit

@testable import ZeroNet_Space

@MainActor
struct PrivacyShieldTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    @Test func inactiveInterruptionDoesNotStartLockTimer() {
        var state = PrivacyLifecycleState()
        state.register("one", phase: .active)
        state.deactivate("one")
        #expect(state.backgroundedAt == nil)
        let activationExpectation1 = !state.activate("one", now: start, timeout: .immediately,
                               authenticated: true, recording: false)
        #expect(activationExpectation1)
    }

    @Test func timeoutBoundariesAndRecordingException() {
        for timeout in AutoLockTimeout.allCases {
            for elapsed in [0.0, 59.0, 60.0, 299.0, 300.0] {
                for recording in [false, true] {
                    var state = PrivacyLifecycleState()
                    state.register("one", phase: .active)
                    state.enterBackground("one", now: start)
                    let expected = !recording && timeout != .never
                        && elapsed >= Double(timeout.rawValue)
                    let activationExpectation2 = state.activate("one", now: start.addingTimeInterval(elapsed),
                                           timeout: timeout, authenticated: true,
                                           recording: recording) == expected
                    #expect(activationExpectation2)
                }
            }
        }
    }

    @Test func activeSiblingScenePreventsWholeAppLock() {
        var state = PrivacyLifecycleState()
        state.register("one", phase: .active)
        state.register("two", phase: .active)
        state.enterBackground("one", now: start)
        #expect(state.backgroundedAt == nil)
        let activationExpectation3 = !state.activate("one", now: start.addingTimeInterval(500),
                               timeout: .immediately, authenticated: true, recording: false)
        #expect(activationExpectation3)
        state.enterBackground("one", now: start)
        state.enterBackground("two", now: start.addingTimeInterval(10))
        #expect(state.backgroundedAt == start.addingTimeInterval(10))
        let activationExpectation4 = state.activate("two", now: start.addingTimeInterval(70),
                              timeout: .oneMinute, authenticated: true, recording: false)
        #expect(activationExpectation4)
    }

    @Test func rapidReentryInvalidatesDeferredUncover() {
        var state = PrivacyLifecycleState()
        state.register("one", phase: .active)
        let oldGeneration = state.generation(for: "one")
        state.deactivate("one")
        #expect(!state.canReveal("one", generation: oldGeneration))
        _ = state.activate("one", now: start, timeout: .never,
                           authenticated: true, recording: false)
        let current = state.generation(for: "one")
        #expect(state.canReveal("one", generation: current))
        state.enterBackground("one", now: start)
        #expect(!state.canReveal("one", generation: current))
        state.disconnect("one")
        #expect(!state.canReveal("one", generation: current))
    }

    @Test func eachBackgroundIntervalStartsFresh() {
        var state = PrivacyLifecycleState()
        state.register("one", phase: .active)
        state.enterBackground("one", now: start)
        let activationExpectation5 = !state.activate("one", now: start.addingTimeInterval(59),
                               timeout: .oneMinute, authenticated: true, recording: false)
        #expect(activationExpectation5)
        state.enterBackground("one", now: start.addingTimeInterval(80))
        let activationExpectation6 = !state.activate("one", now: start.addingTimeInterval(81),
                               timeout: .oneMinute, authenticated: true, recording: false)
        #expect(activationExpectation6)
    }

    @Test func disconnectedForegroundSceneStartsRemainingBackgroundInterval() {
        var state = PrivacyLifecycleState()
        state.register("background", phase: .active)
        state.register("foreground", phase: .active)
        state.enterBackground("background", now: start)
        state.disconnect("foreground", now: start.addingTimeInterval(10))
        #expect(state.backgroundedAt == start.addingTimeInterval(10))
        #expect(state.shouldLock(now: start.addingTimeInterval(10), timeout: .immediately,
                                 authenticated: true, recording: false))
        #expect(!state.shouldLock(now: start.addingTimeInterval(500), timeout: .immediately,
                                  authenticated: false, recording: false))
    }

    @Test func sceneAttachedAfterBackgroundNotificationStillLocksOnActivation() {
        var state = PrivacyLifecycleState()
        state.register("restored", phase: .background, now: start)
        state.register("new-window", phase: .active, now: start.addingTimeInterval(70))
        let locks = state.activate("new-window", now: start.addingTimeInterval(70),
                                   timeout: .oneMinute, authenticated: true, recording: false)
        #expect(locks)
    }

    @Test func windowCoverIsOpaqueResizesAndDoesNotReplaceKeyWindow() {
        let phone = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        let tablet = UIWindow(frame: CGRect(x: 0, y: 0, width: 1_024, height: 1_366))
        let covers = [PrivacyWindowCover(window: phone), PrivacyWindowCover(window: tablet)]
        for (window, cover) in zip([phone, tablet], covers) {
            let wasKey = window.isKeyWindow
            cover.show()
            #expect(cover.view.superview === window)
            #expect(cover.view.isOpaque && cover.view.alpha == 1)
            #expect(cover.view.frame == window.bounds)
            #expect(window.subviews.last === cover.view)
            #expect(window.isKeyWindow == wasKey)
            window.frame.size = CGSize(width: window.frame.height, height: window.frame.width)
            window.layoutIfNeeded()
            cover.show()
            #expect(cover.view.frame == window.bounds)
            cover.hide()
            #expect(cover.view.superview == nil)
        }
    }
    @Test func allScenesDisconnectPreservesElapsedTimeoutOnReconnect() {
        for (timeout, elapsed) in [(AutoLockTimeout.oneMinute, 70.0), (.fiveMinutes, 310.0)] {
            var state = PrivacyLifecycleState()
            state.register("old", phase: .active, now: start)
            state.enterBackground("old", now: start)
            state.disconnect("old", now: start.addingTimeInterval(10))
            #expect(state.backgroundedAt == start)
            state.register("reconnected", phase: .active, now: start.addingTimeInterval(elapsed))
            let locks = state.activate("reconnected", now: start.addingTimeInterval(elapsed),
                                       timeout: timeout, authenticated: true, recording: false)
            #expect(locks)
        }
    }

    @Test func disconnectedReconnectMatrixPreservesSettingsAndRecordingException() {
        for timeout in AutoLockTimeout.allCases {
            for elapsed in [0.0, 59.0, 60.0, 70.0, 299.0, 300.0, 310.0] {
                for recording in [false, true] {
                    for phase in [PrivacyLifecycleState.Phase.active, .background] {
                        var state = PrivacyLifecycleState()
                        state.register("old", phase: .active, now: start)
                        state.enterBackground("old", now: start)
                        state.disconnect("old", now: start)
                        state.register("new", phase: phase, now: start.addingTimeInterval(elapsed))
                        let locks = state.activate("new", now: start.addingTimeInterval(elapsed),
                                                   timeout: timeout, authenticated: true, recording: recording)
                        let expected = !recording && timeout != .never
                            && elapsed >= Double(timeout.rawValue)
                        #expect(locks == expected)
                        #expect(state.backgroundedAt == nil)
                    }
                }
            }
        }
    }

    @Test func disconnectWithoutObservedBackgroundDoesNotManufactureTimeout() {
        var state = PrivacyLifecycleState()
        state.register("old", phase: .active, now: start)
        state.deactivate("old")
        state.disconnect("old", now: start.addingTimeInterval(10))
        #expect(state.backgroundedAt == nil)
        state.register("new", phase: .active, now: start.addingTimeInterval(310))
        let locks = state.activate("new", now: start.addingTimeInterval(310),
                                   timeout: .immediately, authenticated: true, recording: false)
        #expect(!locks)
    }

    @Test func disconnectOfBackgroundSceneDoesNotLockActiveSibling() {
        var state = PrivacyLifecycleState()
        state.register("closed", phase: .active, now: start)
        state.register("still-active", phase: .active, now: start)
        state.enterBackground("closed", now: start)
        state.disconnect("closed", now: start.addingTimeInterval(70))
        #expect(state.backgroundedAt == nil)
        #expect(!state.shouldLock(now: start.addingTimeInterval(310), timeout: .immediately,
                                  authenticated: true, recording: false))
        #expect(state.phases["still-active"] == .active)
    }

}
