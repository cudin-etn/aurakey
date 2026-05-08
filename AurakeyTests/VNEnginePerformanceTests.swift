import XCTest
@testable import Aurakey

final class VNEnginePerformanceTests: XCTestCase {
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
        " ": VietnameseData.KEY_SPACE,
    ]

    func testTelexHotPathPerformance() {
        let sequence = "tooi yeu tieengs vieetj va gox thaajt nhanh tren aurakey "

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let engine = VNEngine()
            for _ in 0..<500 {
                type(sequence, into: engine)
            }
        }
    }

    func testMixedEnglishVietnamesePerformance() {
        let sequence = "SwiftUI performance benchmark aurakey khong lam cham hot path khi go nhanh hello world "

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let engine = VNEngine()
            for _ in 0..<500 {
                type(sequence, into: engine)
            }
        }
    }

    func testPerKeyLatencyDistribution() {
        let engine = VNEngine()
        let sequence = Array("tooi yeu tieengs vieetj va aurakey performance hardening ")
        var samples: [UInt64] = []
        samples.reserveCapacity(sequence.count * 1_000)

        for _ in 0..<1_000 {
            for character in sequence {
                let start = DispatchTime.now().uptimeNanoseconds
                type(character, into: engine)
                samples.append(DispatchTime.now().uptimeNanoseconds - start)
            }
        }

        samples.sort()
        let p50 = percentile(samples, 0.50)
        let p95 = percentile(samples, 0.95)
        let p99 = percentile(samples, 0.99)
        print("VNEngine per-key latency: p50=\(p50)ns p95=\(p95)ns p99=\(p99)ns samples=\(samples.count)")

        XCTAssertLessThan(p95, 2_000_000, "p95 per-key latency should stay under 2ms in unit benchmark")
    }

    private func type(_ text: String, into engine: VNEngine) {
        for character in text {
            type(character, into: engine)
        }
    }

    private func type(_ character: Character, into engine: VNEngine) {
        guard let normalizedCharacter = character.lowercased().first,
              let keyCode = keyCodes[normalizedCharacter] else {
            return
        }
        if character == " " {
            engine.reset()
            return
        }
        _ = engine.processKey(character: character, keyCode: keyCode, isUppercase: character.isUppercase)
    }

    private func percentile(_ sortedSamples: [UInt64], _ percentile: Double) -> UInt64 {
        guard !sortedSamples.isEmpty else { return 0 }
        let index = min(sortedSamples.count - 1, Int(Double(sortedSamples.count - 1) * percentile))
        return sortedSamples[index]
    }
}

private extension Character {
    var isUppercase: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return CharacterSet.uppercaseLetters.contains(scalar)
    }
}
