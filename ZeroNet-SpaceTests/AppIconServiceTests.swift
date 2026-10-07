import XCTest
import UIKit

@testable import ZeroNet_Space

@MainActor
final class AppIconServiceTests: XCTestCase {
    func testNonVIPCannotChangeToPaidIcon() async throws {
        let app = IconApplicationMock()
        let service = AppIconService(application: app)
        do {
            try await service.select(.paper, isVIP: false)
            XCTFail("Paid icons require VIP")
        } catch AppIconService.IconError.vipRequired {}
        XCTAssertEqual(app.changeCount, 0)
        XCTAssertNil(service.selectedIconName)
    }

    func testVIPCanChangeAndNonVIPCanRestoreDefault() async throws {
        let app = IconApplicationMock()
        let service = AppIconService(application: app)
        try await service.select(.calculator, isVIP: true)
        XCTAssertEqual(service.selectedIconName, "AppIcon-Calculator")
        try await service.select(.primary, isVIP: false)
        XCTAssertNil(service.selectedIconName)
        XCTAssertEqual(app.changeCount, 2)
    }

    func testAlreadySelectedIconDoesNotCallSystemAgain() async throws {
        let app = IconApplicationMock()
        app.alternateIconName = "AppIcon-Paper"
        let service = AppIconService(application: app)
        try await service.select(.paper, isVIP: true)
        XCTAssertEqual(app.changeCount, 0)
    }

    func testFailureKeepsSystemSelectionAndAllowsRetry() async throws {
        let app = IconApplicationMock()
        app.alternateIconName = "AppIcon-Paper"
        app.shouldFail = true
        let service = AppIconService(application: app)
        do {
            try await service.select(.pebble, isVIP: true)
            XCTFail("The system error should propagate")
        } catch IconApplicationMock.Failure.rejected {}
        XCTAssertEqual(service.selectedIconName, "AppIcon-Paper")
        XCTAssertFalse(service.isChanging)
        app.shouldFail = false
        try await service.select(.pebble, isVIP: true)
        XCTAssertEqual(service.selectedIconName, "AppIcon-Pebble")
    }

    func testUnsupportedDeviceDoesNotCallSystem() async throws {
        let app = IconApplicationMock()
        app.supportsAlternateIcons = false
        let service = AppIconService(application: app)
        do {
            try await service.select(.paper, isVIP: true)
            XCTFail("Unsupported devices must be rejected")
        } catch AppIconService.IconError.unsupported {}
        XCTAssertEqual(app.changeCount, 0)
    }

    func testConcurrentSelectionCannotStartSecondSystemRequest() async throws {
        let app = IconApplicationMock()
        app.holdChange = true
        let service = AppIconService(application: app)
        let first = Task { try await service.select(.paper, isVIP: true) }
        for _ in 0..<100 where app.pending == nil { await Task.yield() }
        XCTAssertTrue(service.isChanging)
        try await service.select(.calculator, isVIP: true)
        XCTAssertEqual(app.changeCount, 1)
        app.pending?.resume()
        try await first.value
        XCTAssertEqual(service.selectedIconName, "AppIcon-Paper")
        XCTAssertFalse(service.isChanging)
    }

    func testAllIconsAndPreviewsAreBundledForCurrentDevice() throws {
        let key = UIDevice.current.userInterfaceIdiom == .pad ? "CFBundleIcons~ipad" : "CFBundleIcons"
        do {
            let icons = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: key) as? [String: Any])
            let alternates = try XCTUnwrap(icons["CFBundleAlternateIcons"] as? [String: Any])
            for option in AppIconOption.allCases {
                XCTAssertNotNil(UIImage(named: option.previewAsset), option.previewAsset)
                if let name = option.iconName {
                    XCTAssertNotNil(alternates[name], "Missing \(name) in \(key)")
                }
            }
        }
    }
}

@MainActor
private final class IconApplicationMock: AppIconApplication {
    enum Failure: Error { case rejected }
    var alternateIconName: String?
    var supportsAlternateIcons = true
    var shouldFail = false
    var holdChange = false
    var pending: CheckedContinuation<Void, Never>?
    var changeCount = 0

    func changeIcon(to name: String?) async throws {
        changeCount += 1
        if holdChange {
            await withCheckedContinuation { pending = $0 }
        }
        if shouldFail { throw Failure.rejected }
        alternateIconName = name
    }
}
