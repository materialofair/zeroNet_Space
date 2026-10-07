import XCTest
@testable import ZeroNet_Space

final class CalculatorLocalizationTests: XCTestCase {
    func testGermanDecimalDisplayPreservesInputAndPasswordSyntax() {
        let calculator = CalculatorViewModel()
        calculator.numberPressed(1)
        calculator.decimalPressed()
        calculator.numberPressed(5)
        let locale = Locale(identifier: "de_DE")
        XCTAssertEqual(calculator.state.localizedDisplayValue(locale: locale), "1,5")
        XCTAssertEqual(CalculatorButton.decimal.localizedTitle(locale: locale), ",")
        XCTAssertEqual(calculator.state.displayValue, "1.5")
        XCTAssertEqual(calculator.state.inputHistory.joined(), "1.5")
        calculator.operationPressed(.add)
        XCTAssertEqual(calculator.state.previousValue, 1.5)
    }

    func testFrenchDecimalDisplayPreservesInputAndPasswordSyntax() {
        let calculator = CalculatorViewModel()
        calculator.numberPressed(1)
        calculator.decimalPressed()
        calculator.numberPressed(5)
        let locale = Locale(identifier: "fr_FR")
        XCTAssertEqual(calculator.state.localizedDisplayValue(locale: locale), "1,5")
        XCTAssertEqual(CalculatorButton.decimal.localizedTitle(locale: locale), ",")
        XCTAssertEqual(calculator.state.displayValue, "1.5")
        XCTAssertEqual(calculator.state.inputHistory.joined(), "1.5")
        calculator.operationPressed(.multiply)
        XCTAssertEqual(calculator.state.previousValue, 1.5)
    }
}
