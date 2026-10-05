// SPDX-License-Identifier: LGPL-2.1-or-later
import AppKit
import InputMethodKit
import CChewing

@objc(ChewingInputController)
final class ChewingInputController: IMKInputController {
    private var engine: ChewingEngine?
    private var candidatePanel: IMKCandidates?
    private var visibleCandidates: [String] = []
    private var isFlushing = false
    private var ownsMarkedText = false
    private let replacement = NSRange(location: NSNotFound, length: 0)

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
        candidatePanel = IMKCandidates(server: server, panelType: kIMKSingleColumnScrollingCandidatePanel)
        candidatePanel?.setSelectionKeys([18, 19, 20, 21, 23, 22, 26, 28, 25].map { NSNumber(value: $0) })
        do {
            guard let resources = Bundle.main.resourceURL else { throw ChewingEngine.Failure.missingDictionary }
            let user = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
                .appendingPathComponent("ChewingMac/userphrase.dat")
            engine = try ChewingEngine(dictionaryDirectory: resources.appendingPathComponent("libchewing"),
                                       userDictionary: user)
        } catch {
            // Fail open: unavailable dictionaries must not prevent normal typing.
            NSLog("ChewingMac engine initialization failed: %@", String(describing: error))
        }
    }

    override func recognizedEvents(_ sender: Any!) -> Int { Int(NSEvent.EventTypeMask.keyDown.rawValue) }

    override func activateServer(_ sender: Any!) {
        visibleCandidates.removeAll()
        candidatePanel?.hide()
        super.activateServer(sender)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let engine,
              let client = sender as? IMKTextInput else { return false }
        var modifiers: UInt32 = 0
        if event.modifierFlags.contains(.shift) { modifiers |= UInt32(CM_MOD_SHIFT) }
        if event.modifierFlags.contains(.command) { modifiers |= UInt32(CM_MOD_COMMAND) }
        if event.modifierFlags.contains(.control) { modifiers |= UInt32(CM_MOD_CONTROL) }
        if event.modifierFlags.contains(.option) { modifiers |= UInt32(CM_MOD_OPTION) }
        if event.modifierFlags.contains(.capsLock) { modifiers |= UInt32(CM_MOD_CAPS_LOCK) }
        let scalars = event.characters?.unicodeScalars
        let scalar: Int32 = scalars?.count == 1 ? Int32(scalars!.first!.value) : -1
        let route = cm_key_route(event.keyCode, scalar, modifiers)
        if route == CM_PASS {
            // Resolve marked text before a shortcut or an unsupported text event.
            if engine.hasComposition { commitComposition(sender) }
            return false
        }
        let consumed = engine.handle(route: route, scalar: scalar)
        deliverCurrentCommit(to: client)
        render(to: client)
        return consumed
    }

    @objc override func candidates(_ sender: Any!) -> [Any]! { visibleCandidates }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        guard let candidateString, let engine, let client = client(),
              let index = visibleCandidates.firstIndex(of: candidateString.string) else { return }
        engine.selectVisibleCandidate(index)
        deliverCurrentCommit(to: client)
        render(to: client)
    }

    override func commitComposition(_ sender: Any!) {
        guard !isFlushing, let engine else { return }
        guard let destination = (sender as? IMKTextInput) ?? client() else {
            engine.reset()
            visibleCandidates.removeAll()
            candidatePanel?.hide()
            return
        }
        isFlushing = true
        defer { isFlushing = false }
        let flushed = engine.flush()
        if !flushed.isEmpty {
            destination.insertText(flushed, replacementRange: replacement)
            ownsMarkedText = false
        }
        visibleCandidates.removeAll()
        candidatePanel?.hide()
        if ownsMarkedText {
            destination.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: replacement)
            ownsMarkedText = false
        }
    }

    override func deactivateServer(_ sender: Any!) {
        commitComposition(sender)
        super.deactivateServer(sender)
    }

    override func inputControllerWillClose() {
        candidatePanel?.hide()
        engine?.reset()
        super.inputControllerWillClose()
    }

    private func deliverCurrentCommit(to client: IMKTextInput) {
        guard let engine else { return }
        let text = engine.takeCommit()
        if !text.isEmpty {
            client.insertText(text, replacementRange: replacement)
            ownsMarkedText = false
        }
    }

    private func render(to client: IMKTextInput) {
        guard let engine else { return }
        let composition = engine.composition
        let marked = NSAttributedString(string: composition.text, attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
        // Empty setMarkedText with no owned mark may delete the client's selection.
        if !composition.text.isEmpty || ownsMarkedText {
            client.setMarkedText(marked, selectionRange: composition.selection, replacementRange: replacement)
            ownsMarkedText = !composition.text.isEmpty
        }
        visibleCandidates = engine.candidates
        if visibleCandidates.isEmpty { candidatePanel?.hide() }
        else {
            candidatePanel?.update()
            candidatePanel?.show(kIMKLocateCandidatesBelowHint)
        }
    }
}
