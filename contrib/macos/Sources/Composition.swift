// SPDX-License-Identifier: LGPL-2.1-or-later
import Foundation

/// libchewing indexes Unicode scalars; IMK expects UTF-16 offsets.
struct Composition {
    let text: String
    let selection: NSRange

    init(buffer: String, bopomofo: String, scalarCursor: Int) {
        let scalars = Array(buffer.unicodeScalars)
        let cursor = min(max(scalarCursor, 0), scalars.count)
        let prefix = String(String.UnicodeScalarView(scalars[..<cursor]))
        let suffix = String(String.UnicodeScalarView(scalars[cursor...]))
        text = prefix + bopomofo + suffix
        selection = NSRange(location: (prefix + bopomofo).utf16.count, length: 0)
    }
}
