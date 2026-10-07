import XCTest

/// Runs only reachable production password validation paths; never bypasses Keychain.
final class LocalizationLayoutUITests: XCTestCase {
    private let cases: [(String, String, String, String, String, String, String)] = [
        ("en", "Set Password", "Enter password", "Re-enter password", "Finish Setup", "Passwords do not match.", "Remember this password, it cannot be recovered"),
        ("zh-Hant", "設定密碼", "輸入密碼", "再次輸入密碼", "完成設定", "兩次輸入的密碼不一致。", "請牢記該密碼，無法找回"),
        ("ja", "パスワードを設定", "パスワードを入力", "パスワードを再入力", "設定を完了", "パスワードが一致しません。", "このパスワードを忘れないでください。復元はできません"),
        ("pl", "Ustaw hasło", "Wpisz hasło", "Wpisz hasło ponownie", "Zakończ konfigurację", "Hasła nie są zgodne.", "Zapamiętaj to hasło. Nie można go odzyskać"),
        ("de", "Passwort festlegen", "Passwort eingeben", "Passwort erneut eingeben", "Einrichtung abschließen", "Passwörter stimmen nicht überein.", "Merke dir dieses Passwort; es kann nicht wiederhergestellt werden"),
        ("fr", "Définir le mot de passe", "Saisir le mot de passe", "Saisir à nouveau le mot de passe", "Terminer la configuration", "Les mots de passe ne correspondent pas.", "Retenez ce mot de passe : il ne peut pas être récupéré"),
        ("es", "Configurar contraseña", "Introduce la contraseña", "Vuelve a introducir la contraseña", "Finalizar configuración", "Las contraseñas no coinciden.", "Recuerda esta contraseña; no puede recuperarse"),
        ("pt-BR", "Definir senha", "Digite a senha", "Digite a senha novamente", "Concluir configuração", "As senhas não coincidem.", "Memorize esta senha; ela não pode ser recuperada"),
        ("id", "Atur kata sandi", "Masukkan kata sandi", "Masukkan ulang kata sandi", "Selesaikan pengaturan", "Kata sandi tidak cocok.", "Ingat kata sandi ini; kata sandi tidak dapat dipulihkan")
    ]

    @MainActor
    func testEightLanguagesInitialScreensAndRestartSwitch() throws {
        continueAfterFailure = false
        // English bookends show that the same installation switches back as well.
        for item in cases + [cases[0]] {
            try checkPasswordScreen(item, scenario: "standard", validate: true)
        }
    }

    @MainActor
    func testRepresentativeLongTextAtCurrentFontSize() throws {
        continueAfterFailure = false
        for item in cases where ["ja", "pl", "de", "fr"].contains(item.0) {
            try checkPasswordScreen(item, scenario: "large-font", validate: true)
        }
    }

    @MainActor
    func testPolishFrenchLongButtonsAfterLayoutFix() throws {
        continueAfterFailure = false
        for item in cases where ["pl", "fr"].contains(item.0) {
            try checkPasswordScreen(item, scenario: "large-font-final", validate: true)
        }
    }

    @MainActor
    func testPolishStandardViewportAfterLayoutFix() throws {
        continueAfterFailure = false
        try checkPasswordScreen(cases[3], scenario: "standard-final", validate: true)
    }

    @MainActor
    private func checkPasswordScreen(_ item: (String, String, String, String, String, String, String), scenario: String, validate: Bool) throws {
        let (language, title, first, second, finish, error, hint) = item
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", language, "-DemoModeEnabled", "NO"]
        app.launch()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 8), "Localized title missing: \(language)")
        XCTAssertTrue(app.staticTexts[title].isHittable, "Initial title is not visible: \(language)")
        capture(app, name: "Space \(scenario) \(language) initial-unscrolled")
        // Scope to app content: keyboard suggestions also expose a ScrollView.
        let scroll = app.scrollViews.containing(.staticText, identifier: title).firstMatch
        let firstField = app.secureTextFields[first]
        let secondField = app.secureTextFields[second]
        reach(firstField, scroll: scroll, app: app)
        firstField.tap()
        firstField.typeText("I18N-Test-7391")
        reach(secondField, scroll: scroll, app: app)
        secondField.tap()
        secondField.typeText("Different-7391")
        let button = app.buttons[finish]
        reach(button, scroll: scroll, app: app, fullyVisible: true)
        XCTAssertTrue(button.isEnabled)
        capture(app, name: "Space \(scenario) \(language) finish-visible")
        button.tap()
        let errorText = app.staticTexts[error]
        XCTAssertTrue(errorText.waitForExistence(timeout: 3))
        reach(errorText, scroll: scroll, app: app)
        capture(app, name: "Space \(scenario) \(language) validation-visible")
        reach(app.staticTexts[hint], scroll: scroll, app: app)
        capture(app, name: "Space \(scenario) \(language) bottom-hint-visible")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Space \(scenario) \(language) accessibility-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        app.terminate()
    }

    @MainActor
    private func reach(_ element: XCUIElement, scroll: XCUIElement, app: XCUIApplication, fullyVisible: Bool = false) {
        for _ in 0..<12 {
            // XCUI's default swipe starts near the full ScrollView bottom, which
            // can be underneath the keyboard. Drag only within unobscured content.
            let top = max(scroll.frame.minY + 12, app.frame.minY + 80)
            let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY - 44 : app.frame.maxY - 34
            let bottom = min(scroll.frame.maxY, keyboardTop) - 12
            let rect = element.frame
            if element.isHittable && (!fullyVisible || (rect.minY >= top && rect.maxY <= bottom)) { return }
            let height = max(bottom - top, 60)
            let upper = top + height * 0.2
            let lower = top + height * 0.8
            let needsDown = fullyVisible ? rect.minY < top : rect.maxY < top
            let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            let start = origin.withOffset(CGVector(dx: scroll.frame.minX + 8, dy: needsDown ? upper : lower))
            let end = origin.withOffset(CGVector(dx: scroll.frame.minX + 8, dy: needsDown ? lower : upper))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        XCTFail("Element did not reach the unobscured viewport; fullyVisible=\(fullyVisible), frame=\(element.frame)")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Unreachable element hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        XCTAssertTrue(element.isHittable, "Localized element cannot be reached by scrolling: \(element.debugDescription)")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
