# Repository Guidelines

## Project Structure & Module Organization
Core app code lives under `ZeroNet-Space/`. `App/` holds the SwiftUI entry point and app-wide constants, `Models/` defines SwiftData entities such as `MediaItem`, `Services/` encapsulates Keychain, encryption, storage, and import logic, and `ViewModels/` hosts the MVVM glue (`AuthenticationViewModel`, `GalleryViewModel`, `ImportViewModel`). SwiftUI screens are organized in `Views/Authentication`, `Views/Gallery`, and `Views/Import`. Shared utilities and UIKit bridges live in `Utilities/`. Tests sit in the sibling `ZeroNet-SpaceTests` (unit/business logic) and `ZeroNet-SpaceUITests` (XCTest UI flows). Assets reside in `Assets.xcassets`.

## Build, Test, and Development Commands
- `open ZeroNet-Space.xcodeproj` – launches the project in Xcode; preferred for day-to-day work.
- `xcodebuild -scheme "ZeroNet-Space" -destination 'platform=iOS Simulator,name=iPhone 15' build` – CI-friendly build that validates SwiftUI targets.
- `xcodebuild test -scheme "ZeroNet-Space" -destination 'platform=iOS Simulator,name=iPhone 15'` – runs both unit and UI test bundles. Use `-only-testing:ZeroNet-SpaceTests` when iterating on business logic.

## Coding Style & Naming Conventions
Follow standard Swift 5 conventions: four-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for members, and `snake_case` for asset catalogs if required by iOS tooling. Keep SwiftUI views small and compose via extensions when modifiers exceed ~10 lines. Prefer protocol-oriented abstractions between services and view models and reuse helpers in `Utilities/`. Use Xcode's built-in formatter (`Ctrl+I`) before committing; no external linter is currently enforced.

## Testing Guidelines
Unit tests target encryption, Keychain, and import services in `ZeroNet-SpaceTests` using XCTest; mirror the source file name plus `Tests` suffix (e.g., `EncryptionServiceTests`). UI workflows belong in `ZeroNet-SpaceUITests` and should assert login, gallery browsing, and media import flows. Aim to keep encryption and password logic covered, and document any gaps in `BUILD_ERRORS_SUMMARY.md` when skipping a test.

## Commit & Pull Request Guidelines
Commits follow short, imperative subjects (`Add session password storage`, `Fix photo picker crash`). Each commit should build and pass `xcodebuild test`. Pull requests must include: summary of behavior changes, linked issue or requirement doc, screenshots/video for UI adjustments, and a checklist confirming migrations or new assets. Highlight any security-sensitive changes (encryption tweaks, password handling) so reviewers can focus on regression risk.
