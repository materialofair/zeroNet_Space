import Foundation
import Security
import Testing

@testable import ZeroNet_Space

@MainActor
struct CalculatorUnlockTests {
    private func enter(_ password: String, into calculator: CalculatorViewModel) {
        for character in password {
            if character == "." {
                calculator.decimalPressed()
            } else if let number = character.wholeNumberValue {
                calculator.numberPressed(number)
            }
        }
        calculator.equalsPressed()
    }

    @Test
    func ownerUnlockSurvivesChangedVendorIdentifier() throws {
        let service = "calculator-unlock-test-" + UUID().uuidString
        let keychain = KeychainService(service: service)
        defer { keychain.clearAllKeychainData() }
        let password = "246810"
        try keychain.savePassword(password)
        try keychain.saveDisguisePassword(password)

        // 模拟开发包保存的副本：App Store 包的 vendor ID 已不同。
        let encrypted = try EncryptionService.shared.encrypt(
            data: Data(password.utf8), password: "ZNS_DISGUISE_previous_vendor")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "disguisePassword",
        ]
        #expect(SecItemUpdate(query as CFDictionary,
            [kSecValueData as String: encrypted] as CFDictionary) == errSecSuccess)
        #expect(keychain.isDisguisePasswordSet())
        #expect(keychain.loadDisguisePassword() == nil)

        let calculator = CalculatorViewModel(
            keychainService: keychain, notificationCenter: NotificationCenter())
        enter(password, into: calculator)
        #expect(calculator.shouldUnlock)
        #expect(try keychain.retrieveDataPassword(using: password) == password)
    }

    @Test
    func staleDisguisePasswordCannotUnlockAfterOwnerPasswordChanges() throws {
        let keychain = KeychainService(service: "calculator-unlock-test-" + UUID().uuidString)
        defer { keychain.clearAllKeychainData() }
        try keychain.savePassword("246810")
        try keychain.saveDisguisePassword("135790")
        let calculator = CalculatorViewModel(
            keychainService: keychain, notificationCenter: NotificationCenter())
        enter("135790", into: calculator)
        #expect(!calculator.shouldUnlock)
        enter("246810", into: calculator)
        #expect(calculator.shouldUnlock)
    }

    @Test
    func guestUnlockStillWorksAndWrongPasswordIsRejected() throws {
        let keychain = KeychainService(service: "calculator-unlock-test-" + UUID().uuidString)
        defer { keychain.clearAllKeychainData() }
        try keychain.savePassword("246810")
        try keychain.saveGuestPassword("135790")
        let calculator = CalculatorViewModel(
            keychainService: keychain, notificationCenter: NotificationCenter())
        enter("111111", into: calculator)
        #expect(!calculator.shouldUnlock)
        enter("135790", into: calculator)
        #expect(calculator.shouldUnlock)
    }

    @Test
    func decimalOwnerPasswordUnlocksWithoutDisguiseCopy() throws {
        let keychain = KeychainService(service: "calculator-unlock-test-" + UUID().uuidString)
        defer { keychain.clearAllKeychainData() }
        try keychain.savePassword("2468.10")
        let calculator = CalculatorViewModel(
            keychainService: keychain, notificationCenter: NotificationCenter())
        enter("2468.10", into: calculator)
        #expect(calculator.shouldUnlock)
    }
}
