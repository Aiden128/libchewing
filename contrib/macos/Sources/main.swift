// SPDX-License-Identifier: LGPL-2.1-or-later
import AppKit
import InputMethodKit

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
guard let identifier = Bundle.main.bundleIdentifier,
      let connection = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String,
      let server = IMKServer(name: connection, bundleIdentifier: identifier) else {
    fatalError("Missing or invalid input-method bundle registration")
}
withExtendedLifetime(server) { application.run() }
