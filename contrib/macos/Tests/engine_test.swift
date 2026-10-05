// SPDX-License-Identifier: LGPL-2.1-or-later
import Foundation
import CChewing

@main
struct EngineTests {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Pass the built dictionary directory") }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let engine = try ChewingEngine(dictionaryDirectory: URL(fileURLWithPath: CommandLine.arguments[1]),
                                      userDictionary: temporary.appendingPathComponent("user.dat"))
        // DaChen: ㄊ(w) ㄞ(9) second tone(6), ㄅ(1) ㄟ(o) third tone(3), ㄕ(g) fourth tone(4).
        for character in "w961o3g4".unicodeScalars {
            precondition(engine.handle(route: CM_TEXT, scalar: Int32(character.value)))
            precondition(engine.takeCommit().isEmpty)
        }
        precondition(engine.composition.text == "台北市", "Unexpected preedit: \(engine.composition.text.debugDescription)")
        precondition(engine.flush() == "台北市")
        precondition(engine.flush().isEmpty, "Repeated lifecycle flush must not duplicate commits")
        precondition(engine.composition.text.isEmpty)
        for character in "w961o3g4".unicodeScalars {
            _ = engine.handle(route: CM_TEXT, scalar: Int32(character.value))
            _ = engine.takeCommit()
        }
        _ = engine.handle(route: CM_DOWN, scalar: -1)
        precondition(!engine.candidates.isEmpty && engine.candidates.count <= 9)
        engine.selectVisibleCandidate(0)
        _ = engine.takeCommit()
        precondition(!engine.flush().isEmpty)
        precondition(engine.takeCommit().isEmpty)
        _ = engine.handle(route: CM_TEXT, scalar: 49) // ㄅ
        precondition(engine.hasComposition)
        _ = engine.handle(route: CM_ESCAPE, scalar: 27)
        precondition(engine.composition.text.isEmpty)
        _ = engine.handle(route: CM_TEXT, scalar: 49)
        precondition(engine.flush().isEmpty, "Incomplete phonetics are not committed as text")
        precondition(engine.composition.text.isEmpty)
        print("Engine smoke tests passed")
    }
}
