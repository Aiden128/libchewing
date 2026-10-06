// SPDX-License-Identifier: LGPL-2.1-or-later
// Integration tests on a disposable CI Mac with EXISTING UI automation permission.
import AppKit
import ApplicationServices
import Carbon
import Darwin

struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

@main
struct GUIIntegrationTests {
    static let sourceID = "org.chewing.inputmethod.ChewingMac.Development"
    static let taipeiKeys: [CGKeyCode] = [13, 25, 22, 18, 31, 20, 5, 21] // w961o3g4
    static var evidence: URL!

    static func pause(_ seconds: Double = 0.2) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }
    static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
        print("PASS: \(message)")
        fflush(stdout)
    }
    static func stringProperty(_ source: TISInputSource, _ key: CFString) -> String {
        guard let raw = TISGetInputSourceProperty(source, key) else { return "" }
        return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
    }
    static func findSource(_ id: String) -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        let sources = TISCreateInputSourceList(filter, true).takeRetainedValue() as! [TISInputSource]
        return sources.first
    }
    static func selectedID() -> String {
        stringProperty(TISCopyCurrentKeyboardInputSource().takeRetainedValue(), kTISPropertyInputSourceID)
    }
    static func select(_ source: TISInputSource, expectedID: String) throws {
        let status = TISSelectInputSource(source)
        try require(status == noErr, "TISSelectInputSource status=\(status)")
        for _ in 0..<30 { if selectedID() == expectedID { break }; pause(0.1) }
        try require(selectedID() == expectedID, "Selected input source is \(expectedID), actual=\(selectedID())")
    }
    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
    static func textArea(_ root: AXUIElement, depth: Int = 0) -> AXUIElement? {
        if attribute(root, kAXRoleAttribute) as? String == kAXTextAreaRole { return root }
        guard depth < 14, let children = attribute(root, kAXChildrenAttribute) as? [AXUIElement] else { return nil }
        for child in children.prefix(100) {
            if let result = textArea(child, depth: depth + 1) { return result }
        }
        return nil
    }
    static func windows(_ application: AXUIElement) -> [AXUIElement] {
        attribute(application, kAXWindowsAttribute) as? [AXUIElement] ?? []
    }
    static func document(_ application: AXUIElement, named name: String) -> (AXUIElement, AXUIElement)? {
        for window in windows(application) {
            let title = attribute(window, kAXTitleAttribute) as? String ?? ""
            if title.contains(name), let area = textArea(window) { return (window, area) }
        }
        return nil
    }
    static func read(_ area: AXUIElement) -> String { attribute(area, kAXValueAttribute) as? String ?? "<AXValue unavailable>" }
    static func expectText(_ area: AXUIElement, _ expected: String, _ label: String) throws {
        for _ in 0..<40 { if read(area) == expected { break }; pause(0.1) }
        try require(read(area) == expected, "\(label): expected=\(expected.debugDescription) actual=\(read(area).debugDescription)")
    }
    static func key(_ code: CGKeyCode, flags: CGEventFlags = []) throws {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.TextEdit" else {
            throw TestFailure("TextEdit lost foreground before physical key injection")
        }
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) else {
            throw TestFailure("Cannot construct keyboard event")
        }
        down.flags = flags; up.flags = flags
        down.post(tap: .cghidEventTap); pause(0.04)
        up.post(tap: .cghidEventTap); pause(0.12)
    }
    static func taipei() throws { for code in taipeiKeys { try key(code) }; pause(0.4) }
    static func visibleWindows() -> [[String: Any]] {
        (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
    }
    static func screenshot(_ name: String) {
        guard CGPreflightScreenCaptureAccess() else { print("SKIPPED screenshot: no existing capture access"); return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", evidence.appendingPathComponent(name + ".png").path]
        try? process.run(); process.waitUntilExit()
    }
    static func openDocument(_ url: URL, application: AXUIElement) throws -> (AXUIElement, AXUIElement) {
        try "".write(to: url, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "TextEdit", url.path]
        try process.run(); process.waitUntilExit()
        try require(process.terminationStatus == 0, "Launch Services opened \(url.lastPathComponent)")
        for _ in 0..<100 {
            if let target = document(application, named: url.lastPathComponent) {
                AXUIElementPerformAction(target.0, kAXRaiseAction as CFString)
                AXUIElementSetAttributeValue(target.1, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                pause(0.5)
                return target
            }
            pause(0.1)
        }
        throw TestFailure("TextEdit document/text area unavailable: \(url.lastPathComponent); permission dialog or missing GUI may be blocking")
    }
    static func main() {
        do { try run() }
        catch {
            print("FAIL: \(error)"); fflush(stdout)
            if evidence != nil { screenshot("failure") }
            exit(1)
        }
    }
    static func run() throws {
        guard CommandLine.arguments.count == 3 else { throw TestFailure("Usage: gui-test APP_PATH EVIDENCE_DIR") }
        evidence = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        // Preflight only. Never request, reset, or write TCC permissions.
        try require(AXIsProcessTrusted(), "Existing Accessibility permission")
        try require(CGPreflightPostEventAccess(), "Existing keyboard event permission")
        try require(CGSessionCopyCurrentDictionary() != nil, "Existing logged-in GUI session")
        let original = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let originalID = stringProperty(original, kTISPropertyInputSourceID)
        defer { TISSelectInputSource(original) }
        print("ORIGINAL_SOURCE=\(originalID)")
        let bundle = URL(fileURLWithPath: CommandLine.arguments[1])
        let registration = TISRegisterInputSource(bundle as CFURL)
        try require(registration == noErr, "Register IMK bundle status=\(registration)")
        var targetSource: TISInputSource?
        for _ in 0..<50 { targetSource = findSource(sourceID); if targetSource != nil { break }; pause(0.2) }
        guard let targetSource else { throw TestFailure("Registered bundle did not expose expected input source; no logout or security changes attempted") }
        let enabling = TISEnableInputSource(targetSource)
        try require(enabling == noErr, "Enable development input source status=\(enabling)")
        defer { TISDisableInputSource(targetSource) }
        // Start TextEdit through Launch Services; no direct AppleEvents grant is needed.
        let firstURL = evidence.appendingPathComponent("chewing-first.txt")
        try "".write(to: firstURL, atomically: true, encoding: .utf8)
        let launch = Process(); launch.executableURL = URL(fileURLWithPath: "/usr/bin/open"); launch.arguments = ["-a", "TextEdit", firstURL.path]
        try launch.run(); launch.waitUntilExit()
        var textEdit: NSRunningApplication?
        for _ in 0..<50 { textEdit = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first; if textEdit != nil { break }; pause(0.2) }
        guard let textEdit else { throw TestFailure("TextEdit did not launch") }
        textEdit.activate(options: [.activateIgnoringOtherApps])
        let application = AXUIElementCreateApplication(textEdit.processIdentifier)
        let first = try openDocument(evidence.appendingPathComponent("chewing-first.txt"), application: application)
        try select(targetSource, expectedID: sourceID)
        try expectText(first.1, "", "Blank TextEdit client")
        try taipei()
        try expectText(first.1, "台北市", "Physical Bopomofo keys produced Chinese preedit")
        let beforeCandidates = Set(visibleWindows().compactMap { $0[kCGWindowNumber as String] as? Int })
        try key(125) // Down: open candidates
        pause(0.8)
        let newWindows = visibleWindows().filter {
            guard let id = $0[kCGWindowNumber as String] as? Int else { return false }
            return !beforeCandidates.contains(id)
        }
        print("CANDIDATE_NEW_WINDOWS=\(newWindows)")
        screenshot("candidate-window")
        try require(!newWindows.isEmpty, "Candidate presentation created a visible window")
        try key(18) // Candidate 1 via physical number key
        try key(36) // Return commits
        try expectText(first.1, "台北市", "Selected candidate committed exactly once")
        try key(18); try key(53) // Partial ㄅ, then Escape
        try expectText(first.1, "台北市", "Escape cancels partial composition")
        try select(original, expectedID: originalID)
        try select(targetSource, expectedID: sourceID)
        try expectText(first.1, "台北市", "Repeated source activation does not duplicate commit")
        try key(0, flags: .maskCommand); try key(53) // Cmd-A, Escape while engine idle
        try expectText(first.1, "台北市", "Idle Escape preserves selected client text")
        try key(124) // Move caret to end
        try taipei(); try key(36)
        try expectText(first.1, "台北市台北市", "Repeated composition remains functional")
        try taipei() // pending third phrase; changing documents should flush exactly once
        let second = try openDocument(evidence.appendingPathComponent("chewing-second.txt"), application: application)
        try expectText(first.1, "台北市台北市台北市", "Focus change commits to original client once")
        try expectText(second.1, "", "New client receives no stale composition")
        try select(targetSource, expectedID: sourceID)
        try taipei(); try key(36)
        try expectText(second.1, "台北市", "Independent second TextEdit client")
        screenshot("textedit-result")
        print("GUI_INTEGRATION_PASSED: registration, selection, physical-key typing, candidate window, candidate selection, cancellation, activation, selection preservation, repeated input, and focus isolation")
    }
}
