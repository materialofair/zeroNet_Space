# Audio Memos Implementation Plan

**Goal:** Add secure audio import and voice recording after the video tab.
**Architecture:** Extend MediaType without changing the persistent schema. Separate audio persistence, recording/playback state, and SwiftUI presentation. Reuse FileStorageService encryption and existing authentication.
**Tech Stack:** SwiftUI, SwiftData, AVFoundation, XCTest, string catalogs.

- [x] Extend MediaType detection and exhaustive switches; validate audio extensions, UTType, MIME and legacy values in AudioServiceTests.
- [x] Add AudioImportService with playable-track validation and stream encryption; verify a generated WAV round-trips through encryption and corrupt input is rejected.
- [x] Add AudioSessionController for microphone authorization, protected temporary recording, pause/resume, metering, playback and cleanup; test cancellation cleanup without microphone access.
- [x] Add AudioView with owner guards, item limit, import failures, rename/delete rollback and lifecycle handling. Place settings in all five home toolbars, with an explicit close button in its sheet.
- [x] Add English/Chinese strings and microphone usage text for both build configurations.
- [x] Run xcodebuild build and unit tests on the available iPhone 17 simulator. Inspect UI and record hardware-only checks in BUILD_ERRORS_SUMMARY.md.

Existing user changes to CHANGELOG.md and APP_STORE_COPY_1.3.0.md are outside scope. No publishing or push.

Verification boundary: the recording UI test reaches AVAudioRecorder preparation but blocks in the current simulator audio backend. This is documented in BUILD_ERRORS_SUMMARY.md and is not counted as a passing test. Hardware recording, incoming calls, and lock-screen behavior require device acceptance.
