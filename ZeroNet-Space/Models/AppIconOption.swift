import Foundation

enum AppIconOption: String, CaseIterable, Identifiable {
    case primary, paper, calculator, pebble, ruler

    var id: String { rawValue }
    var requiresVIP: Bool { self != .primary }

    var iconName: String? {
        switch self {
        case .primary: return nil
        case .paper: return "AppIcon-Paper"
        case .calculator: return "AppIcon-Calculator"
        case .pebble: return "AppIcon-Pebble"
        case .ruler: return "AppIcon-Ruler"
        }
    }

    var previewAsset: String {
        switch self {
        case .primary: return "AppIconDisplay"
        case .paper: return "IconPreview-Paper"
        case .calculator: return "IconPreview-Calculator"
        case .pebble: return "IconPreview-Pebble"
        case .ruler: return "IconPreview-Ruler"
        }
    }

    var title: String {
        switch self {
        case .primary: return String(localized: "appicon.name.primary")
        case .paper: return String(localized: "appicon.name.paper")
        case .calculator: return String(localized: "appicon.name.calculator")
        case .pebble: return String(localized: "appicon.name.pebble")
        case .ruler: return String(localized: "appicon.name.ruler")
        }
    }

    var subtitle: String {
        switch self {
        case .primary: return String(localized: "appicon.description.primary")
        case .paper: return String(localized: "appicon.description.paper")
        case .calculator: return String(localized: "appicon.description.calculator")
        case .pebble: return String(localized: "appicon.description.pebble")
        case .ruler: return String(localized: "appicon.description.ruler")
        }
    }
}
