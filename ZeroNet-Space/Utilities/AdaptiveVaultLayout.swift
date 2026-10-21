import SwiftUI

/// Decisions depend on the available window/content width, never a device name.
enum AdaptiveVaultLayout {
    static func showsSidebar(width: CGFloat, accessibility: Bool) -> Bool {
        width >= (accessibility ? 1_050 : 640)
    }

    static func photoColumns(width: CGFloat, accessibility: Bool) -> Int {
        let minimum: CGFloat = accessibility ? 180 : 100
        return max(1, min(8, Int((max(0, width - 32) + 4) / (minimum + 4))))
    }
}

private struct VaultSidebarKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var vaultUsesSidebar: Bool {
        get { self[VaultSidebarKey.self] }
        set { self[VaultSidebarKey.self] = newValue }
    }
}
