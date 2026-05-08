import XCTest
@testable import Aurakey

final class VNEngineRegressionTests: XCTestCase {
    private let keyCodes: [Character: CGKeyCode] = [
        "a": VietnameseData.KEY_A,
        "b": VietnameseData.KEY_B,
        "c": VietnameseData.KEY_C,
        "d": VietnameseData.KEY_D,
        "e": VietnameseData.KEY_E,
        "f": VietnameseData.KEY_F,
        "g": VietnameseData.KEY_G,
        "h": VietnameseData.KEY_H,
        "i": VietnameseData.KEY_I,
        "j": VietnameseData.KEY_J,
        "k": VietnameseData.KEY_K,
        "l": VietnameseData.KEY_L,
        "m": VietnameseData.KEY_M,
        "n": VietnameseData.KEY_N,
        "o": VietnameseData.KEY_O,
        "p": VietnameseData.KEY_P,
        "q": VietnameseData.KEY_Q,
        "r": VietnameseData.KEY_R,
        "s": VietnameseData.KEY_S,
        "t": VietnameseData.KEY_T,
        "u": VietnameseData.KEY_U,
        "v": VietnameseData.KEY_V,
        "w": VietnameseData.KEY_W,
        "x": VietnameseData.KEY_X,
        "y": VietnameseData.KEY_Y,
        "z": VietnameseData.KEY_Z,
    ]

    func testFastTelexWordsStayStable() {
        XCTAssertTyped("tieengs", equals: "tiếng")
        XCTAssertTyped("vieetj", equals: "việt")
        XCTAssertTyped("ddawng", equals: "đăng")
        XCTAssertTyped("truowngf", equals: "trường")
        XCTAssertTyped("nghieeng", equals: "nghiêng")
    }

    func testTonePlacementRegression() {
        XCTAssertTyped("hoas", equals: "hoá")
        XCTAssertTyped("hoaf", equals: "hoà")
        XCTAssertTyped("thuyr", equals: "thuỷ")
        XCTAssertTyped("nguyeenx", equals: "nguyễn")
    }

    func testEnglishLikeSequencesDoNotCrashOrStall() {
        let engine = VNEngine()
        type("SwiftUI benchmark performance hello world", into: engine)
        XCTAssertFalse(engine.getCurrentWord().isEmpty)
    }

    private func XCTAssertTyped(_ raw: String, equals expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let engine = VNEngine()
        type(raw, into: engine)
        XCTAssertEqual(engine.getCurrentWord(), expected, file: file, line: line)
    }

    private func type(_ text: String, into engine: VNEngine) {
        for character in text {
            guard let keyCode = keyCodes[character] else { continue }
            _ = engine.processKey(character: character, keyCode: keyCode, isUppercase: false)
        }
    }
}
