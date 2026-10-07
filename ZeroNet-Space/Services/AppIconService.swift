internal import Combine
import UIKit

@MainActor
protocol AppIconApplication {
    var alternateIconName: String? { get }
    var supportsAlternateIcons: Bool { get }
    func changeIcon(to name: String?) async throws
}

@MainActor
private struct SystemIconApplication: AppIconApplication {
    var alternateIconName: String? { UIApplication.shared.alternateIconName }
    var supportsAlternateIcons: Bool { UIApplication.shared.supportsAlternateIcons }

    func changeIcon(to name: String?) async throws {
        try await UIApplication.shared.setAlternateIconName(name)
    }
}

@MainActor
final class AppIconService: ObservableObject {
    enum IconError: LocalizedError {
        case vipRequired, unsupported

        var errorDescription: String? {
            switch self {
            case .vipRequired: return String(localized: "appicon.vip.message")
            case .unsupported: return String(localized: "appicon.error.unsupported")
            }
        }
    }

    @Published private(set) var selectedIconName: String?
    @Published private(set) var isChanging = false
    private let application: any AppIconApplication

    init(application: (any AppIconApplication)? = nil) {
        let application = application ?? SystemIconApplication()
        self.application = application
        selectedIconName = application.alternateIconName
    }

    func refresh() {
        selectedIconName = application.alternateIconName
    }

    func select(_ icon: AppIconOption, isVIP: Bool) async throws {
        guard !isChanging else { return }
        refresh()
        guard selectedIconName != icon.iconName else { return }
        guard !icon.requiresVIP || isVIP else { throw IconError.vipRequired }
        guard application.supportsAlternateIcons else { throw IconError.unsupported }

        isChanging = true
        defer {
            refresh()
            isChanging = false
        }
        try await application.changeIcon(to: icon.iconName)
    }
}
