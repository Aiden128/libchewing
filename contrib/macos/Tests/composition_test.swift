// SPDX-License-Identifier: LGPL-2.1-or-later
import Foundation

@main
struct CompositionTests {
    static func main() {
        let cases: [(String, String, Int, String, Int)] = [
            ("", "", 0, "", 0),
            ("中文", "ㄅ", 1, "中ㄅ文", 2),
            ("𠮷文", "ㄅㄚ", 1, "𠮷ㄅㄚ文", 4),
            ("文", "ㄅ", -9, "ㄅ文", 1),
            ("文", "", 99, "文", 1),
            ("e\u{301}文", "ㄅ", 2, "e\u{301}ㄅ文", 3),
        ]
        for (buffer, bopomofo, cursor, expected, offset) in cases {
            let result = Composition(buffer: buffer, bopomofo: bopomofo, scalarCursor: cursor)
            precondition(result.text == expected)
            precondition(result.selection == NSRange(location: offset, length: 0))
        }
        print("Composition: 6 cases passed")
    }
}
