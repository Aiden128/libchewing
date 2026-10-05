// SPDX-License-Identifier: LGPL-2.1-or-later
import Foundation
import CChewing

final class ChewingEngine {
    enum Failure: Error { case missingDictionary, initialization }
    private let context: OpaquePointer

    init(dictionaryDirectory: URL, userDictionary: URL) throws {
        guard FileManager.default.fileExists(atPath: dictionaryDirectory.appendingPathComponent("tsi.dat").path),
              FileManager.default.fileExists(atPath: dictionaryDirectory.appendingPathComponent("word.dat").path)
        else { throw Failure.missingDictionary }
        try FileManager.default.createDirectory(at: userDictionary.deletingLastPathComponent(), withIntermediateDirectories: true)
        let created = dictionaryDirectory.path.withCString { systemPath in
            userDictionary.path.withCString { userPath in
                chewing_new2(systemPath, userPath, nil, nil)
            }
        }
        guard let created else { throw Failure.initialization }
        context = created
        chewing_set_KBType(context, 0) // KB_DEFAULT / DaChen
        chewing_set_ChiEngMode(context, 1)
        chewing_set_candPerPage(context, 9)
        chewing_set_maxChiSymbolLen(context, 39)
        chewing_set_escCleanAllBuf(context, 1)
        chewing_set_spaceAsSelection(context, 1)
        let keys: [Int32] = Array(49...57) + [48]
        keys.withUnsafeBufferPointer { chewing_set_selKey(context, $0.baseAddress, Int32($0.count)) }
    }

    deinit { chewing_delete(context) }

    var composition: Composition {
        Composition(buffer: string(chewing_buffer_String_static(context)),
                    bopomofo: string(chewing_bopomofo_String_static(context)),
                    scalarCursor: Int(chewing_cursor_Current(context)))
    }

    var hasComposition: Bool { !composition.text.isEmpty }

    /// Acknowledge ephemeral output so redraws and focus changes cannot insert it twice.
    func takeCommit() -> String {
        let output = chewing_commit_Check(context) != 0 ? string(chewing_commit_String_static(context)) : ""
        chewing_ack(context)
        return output
    }

    /// Commit converted text; discard an incomplete phonetic syllable on session end.
    func flush() -> String {
        let previousCommit = takeCommit()
        chewing_cand_close(context)
        chewing_clean_bopomofo_buf(context)
        let converted = string(chewing_buffer_String_static(context))
        let result = chewing_commit_preedit_buf(context)
        let flushed = result == 0 ? takeCommit() : converted
        chewing_Reset(context)
        return previousCommit + flushed
    }

    var candidates: [String] {
        guard chewing_cand_TotalPage(context) > 0 else { return [] }
        let pageSize = Int(chewing_cand_ChoicePerPage(context))
        let start = Int(chewing_cand_CurrentPage(context)) * pageSize
        let end = min(start + pageSize, Int(chewing_cand_TotalChoice(context)))
        guard start >= 0, end > start else { return [] }
        return (start..<end).map { string(chewing_cand_string_by_index_static(context, Int32($0))) }
    }

    func selectVisibleCandidate(_ index: Int) {
        let absolute = Int(chewing_cand_CurrentPage(context)) * Int(chewing_cand_ChoicePerPage(context)) + index
        guard absolute >= 0, absolute < Int(chewing_cand_TotalChoice(context)) else { return }
        chewing_cand_choose_by_index(context, Int32(absolute))
    }

    func handle(route: Int32, scalar: Int32) -> Bool {
        switch route {
        case CM_TEXT: chewing_handle_Default(context, scalar)
        case CM_SPACE: chewing_handle_Space(context)
        case CM_SHIFT_SPACE: chewing_handle_ShiftSpace(context)
        case CM_ENTER: chewing_handle_Enter(context)
        case CM_ESCAPE: chewing_handle_Esc(context)
        case CM_BACKSPACE: chewing_handle_Backspace(context)
        case CM_DELETE: chewing_handle_Del(context)
        case CM_LEFT: chewing_handle_Left(context)
        case CM_RIGHT: chewing_handle_Right(context)
        case CM_SHIFT_LEFT: chewing_handle_ShiftLeft(context)
        case CM_SHIFT_RIGHT: chewing_handle_ShiftRight(context)
        case CM_UP: chewing_handle_Up(context)
        case CM_DOWN: chewing_handle_Down(context)
        case CM_HOME: chewing_handle_Home(context)
        case CM_END: chewing_handle_End(context)
        case CM_PAGE_UP: chewing_handle_PageUp(context)
        case CM_PAGE_DOWN: chewing_handle_PageDown(context)
        case CM_TAB: chewing_handle_Tab(context)
        default: return false
        }
        return chewing_keystroke_CheckIgnore(context) == 0
    }

    func reset() { chewing_Reset(context) }
    private func string(_ value: UnsafePointer<CChar>?) -> String {
        value.map { String(cString: $0) } ?? ""
    }
}
