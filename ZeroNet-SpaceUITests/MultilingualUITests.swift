import XCTest

final class MultilingualUITests: XCTestCase {
    @MainActor
    func testAllLanguagesAuthenticationNavigationAndPurchaseCopy() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["SPACE_SIGNED_KEYCHAIN_UI_TESTS"] == "1" else {
            throw XCTSkip("Vault setup/navigation requires a signed test app with Keychain access. Production signing is unchanged; unsigned resource and initial-screen tests run separately.")
        }
        let cases: [(String, String, String, String, String, String, String, String)] = [
            ("zh-Hant", "輸入密碼", "再次輸入密碼", "請輸入密碼", "解鎖", "設定", "影音", "恢復購買"),
            ("ja", "パスワードを入力", "パスワードを再入力", "パスワードを入力", "解除", "設定", "メディア", "購入を復元"),
            ("pl", "Wpisz hasło", "Wpisz hasło ponownie", "Wpisz hasło", "Odblokuj", "Ustawienia", "Multimedia", "Odtwórz zakupy"),
            ("de", "Passwort eingeben", "Passwort erneut eingeben", "Passwort eingeben", "Entsperren", "Einstellungen", "Medien", "Käufe wiederherstellen"),
            ("fr", "Saisir le mot de passe", "Saisir à nouveau le mot de passe", "Saisir le mot de passe", "Déverrouiller", "Réglages", "Médias", "Restaurer les achats"),
            ("es", "Introduce la contraseña", "Vuelve a introducir la contraseña", "Introduce la contraseña", "Desbloquear", "Ajustes", "Archivos multimedia", "Restaurar compras"),
            ("pt-BR", "Digite a senha", "Digite a senha novamente", "Digite a senha", "Desbloquear", "Ajustes", "Mídias", "Restaurar compras"),
            ("id", "Masukkan kata sandi", "Masukkan ulang kata sandi", "Masukkan kata sandi", "Buka kunci", "Pengaturan", "Media", "Pulihkan pembelian")
        ]
        let password = "I18N-Test-7391"
        for (language, setup, confirm, login, unlock, settings, media, restore) in cases {
            let app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", language, "-DemoModeEnabled", "NO", "-hasUnlockedUnlimited", "NO", "-autoLockTimeout", "-1"]
            app.launch()
            if app.secureTextFields[confirm].waitForExistence(timeout: 5) {
                app.secureTextFields[setup].tap()
                app.secureTextFields[setup].typeText(password)
                app.secureTextFields[confirm].tap()
                app.secureTextFields[confirm].typeText(password + "\n")
            } else {
                XCTAssertTrue(app.secureTextFields[login].waitForExistence(timeout: 5))
                app.secureTextFields[login].tap()
                app.secureTextFields[login].typeText(password)
                app.buttons[unlock].tap()
            }
            XCTAssertTrue(app.tabBars.buttons[settings].waitForExistence(timeout: 10))
            XCTAssertTrue(app.tabBars.buttons[media].exists)
            app.tabBars.buttons[settings].tap()
            let restoreButton = app.buttons[restore]
            for _ in 0..<5 where !restoreButton.exists { app.swipeUp() }
            XCTAssertTrue(restoreButton.exists, "Missing restore purchase UI in \(language)")
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Space \(language) Settings"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
    }

    @MainActor
    func testAllLanguagesInitialPasswordValidation() throws {
        continueAfterFailure = false
        let cases: [(String, String, String, String, String, String, String)] = [
            ("zh-Hant", "設定密碼", "輸入密碼", "再次輸入密碼", "密碼不一致", "完成設定", "兩次輸入的密碼不一致。"),
            ("ja", "パスワードを設定", "パスワードを入力", "パスワードを再入力", "パスワードが一致しません", "設定を完了", "パスワードが一致しません。"),
            ("pl", "Ustaw hasło", "Wpisz hasło", "Wpisz hasło ponownie", "Hasła nie są zgodne", "Zakończ konfigurację", "Hasła nie są zgodne."),
            ("de", "Passwort festlegen", "Passwort eingeben", "Passwort erneut eingeben", "Passwörter stimmen nicht überein", "Einrichtung abschließen", "Passwörter stimmen nicht überein."),
            ("fr", "Définir le mot de passe", "Saisir le mot de passe", "Saisir à nouveau le mot de passe", "Les mots de passe ne correspondent pas", "Terminer la configuration", "Les mots de passe ne correspondent pas."),
            ("es", "Configurar contraseña", "Introduce la contraseña", "Vuelve a introducir la contraseña", "Las contraseñas no coinciden", "Finalizar configuración", "Las contraseñas no coinciden."),
            ("pt-BR", "Definir senha", "Digite a senha", "Digite a senha novamente", "As senhas não coincidem", "Concluir configuração", "As senhas não coincidem."),
            ("id", "Atur kata sandi", "Masukkan kata sandi", "Masukkan ulang kata sandi", "Kata sandi tidak cocok", "Selesaikan pengaturan", "Kata sandi tidak cocok.")
        ]
        for (language, title, passwordField, confirmField, mismatch, finish, validationError) in cases {
            let app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", language, "-DemoModeEnabled", "NO"]
            app.launch()
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 8), "Missing localized setup title in \(language)")
            XCTAssertTrue(app.secureTextFields[passwordField].exists)
            XCTAssertTrue(app.secureTextFields[confirmField].exists)
            app.secureTextFields[passwordField].tap()
            app.secureTextFields[passwordField].typeText("I18N-Test-7391")
            app.secureTextFields[confirmField].tap()
            app.secureTextFields[confirmField].typeText("Different-7391")
            XCTAssertTrue(app.staticTexts[mismatch].waitForExistence(timeout: 3))
            XCTAssertTrue(app.buttons[finish].exists)
            // Production validates mismatch when tapped; it does not disable this button.
            app.buttons[finish].tap()
            XCTAssertTrue(app.staticTexts[validationError].waitForExistence(timeout: 3))
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Space \(language) password validation"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
    }
}
