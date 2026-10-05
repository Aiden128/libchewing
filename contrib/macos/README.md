# ChewingMac native input-method prototype

**Development source, not a validated release.** This adds an independently written
macOS InputMethodKit shell to the existing Rust libchewing core. It does not replace
the engine, alter its dictionary, or copy vChewing source. The initial development
bundle has a distinct identifier so it need not replace another installed IME.

Patch base: `chewing/libchewing` GitHub commit
`3c4a93aa03d574c7f011ff84e8a2437c2f79b2cf`.
That repository has migrated to Codeberg. The GitHub snapshot is a reproducible
starting point, **not a claim to contain the newest Codeberg changes**.

## Structure

- `ChewingEngine.swift`: owns one libchewing context per input session, creates a
  separate user dictionary, copies C strings into Swift, and acknowledges commits
- `ChewingInputController.swift`: documented IMK lifecycle, events, marked text,
  committed text, and candidate presentation via IMKCandidates
- `Composition.swift`: Unicode-scalar cursor to UTF-16 range conversion
- `KeyRoute.c`: isolated key/modifier routing, tested independently of AppKit
- `main.swift` / `Info.plist`: persistent IMKServer and bundle registration

The existing public C interface is exposed as `CChewing`, matching the upstream
Swift bridge's module boundary. The standalone build uses an app-local dynamically
linked libchewing instead of depending on the upstream SwiftPM plugin's internal
build-output paths. Dictionary data and license notices are bundled with the app. The prototype
build disables optional SQLite so it uses libchewing's native user-dictionary
backend and does not accidentally depend on a build machine's Homebrew SQLite.

Initial behavior: DaChen keyboard; nine candidates per page; Enter, Escape,
Backspace, Delete, arrows, Home/End, Page Up/Down, Tab and Shift-arrow selection.
Command/Control/Option shortcuts and Caps Lock pass through after flushing the
converted composition. Session-end flushing discards an unfinished phonetic
syllable rather than leaking it into the next application. Preferences, Shift-only
mode switching, custom keyboard layouts, phrase editor, signed installer,
notarization, and release packaging are outside this initial slice.

## Build on a Mac

Prerequisites: Xcode command-line tools, CMake >= 3.24, Rust >= 1.88, and the
upstream data submodule. Use the architecture of the current Mac; this script does
not produce a universal binary. The intended minimum is macOS 13, pending testing.

From the actual upstream checkout with this patch applied:

```sh
git submodule update --init --recursive
bash contrib/macos/build.sh
```

The script builds the Rust/C ABI core and dictionary through the upstream CMake
build, runs upstream CTest, compiles the Swift input method, bundles its dylib and
dictionaries, ad-hoc signs the development app, checks its plist/signature, and
runs the routing, composition, and real-engine smoke tests. It does **not** install,
activate, notarize, or publish the input method. Output is
`build-macos/ChewingMac.app`.

A separate workflow builds this same target and uploads a development zip. A green
headless build is necessary but insufficient evidence for real IMK behavior.

## Validation status

Verified in the Linux preparation workspace:

- C key routing: 1,047 assertions passed using `cc -std=c11 -Wall -Wextra -Werror -pedantic`
- Build and test scripts: `bash -n` passed
- `Info.plist`: parsed with Python `plistlib`

Not yet run:

- Swift compilation and its six Unicode composition test cases
- libchewing real-engine smoke tests (Taipei example, flush idempotence, cancellation)
- macOS app build, signing validation, or GitHub Actions workflow
- IMK registration, activation, or actual typing into any Mac application

The working fork is https://github.com/Aiden128/libchewing on branch
`feature/macos-input-method`. macOS CI is being introduced with this prototype.
Do not interpret source preparation or passing portable tests as a working macOS
input-method release; inspect the exact commit's CI results.

## Required interactive acceptance checks

After a successful build, installation into `~/Library/Input Methods/` and enabling
the input source must be explicitly authorized. Run these on an actual Mac and
record OS, architecture, app version and result; do not silently mark them passed.

1. Registration: the development input source appears after any required logout/login
2. TextEdit: `w91o3g4` composes 台北市 and Enter commits exactly once
3. Open candidates, choose with numbers and mouse, then use paging and Escape
4. Edit composition in the middle, Backspace/Delete, Shift-arrows, and supplementary-plane characters
5. Enter on empty composition, English shortcuts, Caps Lock, Option and Command keys;
   select existing client text and press idle arrows/Escape or switch sources without deleting the selection
6. Switch input sources and apps with composition/candidates open; no duplicate text,
   lost converted buffer, stale marked text, or candidate window left behind
7. Safari textarea and a Chromium/Electron editor; repeated activation and focus changes
8. Full-screen applications, multiple monitors, and screen-edge candidate placement
9. Missing dictionaries: engine fails open, with no blocked normal typing
10. User dictionary persists after relaunch; one session's preedit never appears in another

## Architecture references and licensing

All new files use LGPL-2.1-or-later consistent with libchewing. Preserve upstream
COPYING, AUTHORS, and any dictionary/submodule notices when distributing.

The user requested architectural reference to vChewing. Only its separation between
Darwin IMK/controller, engine session, and presentation was consulted; no source,
private IMK hooks, dictionary data, assets, names, or branding were imported.
Current vChewing modules have different licenses (including MulanPSL-2.0 and
LGPL-3.0-or-later), so copying should not be assumed safe merely because an older
version used other terms.

References:

- https://github.com/chewing/libchewing/blob/3c4a93aa03d574c7f011ff84e8a2437c2f79b2cf/Package.swift
- https://github.com/chewing/libchewing/blob/3c4a93aa03d574c7f011ff84e8a2437c2f79b2cf/capi/include/chewing.h
- https://developer.apple.com/documentation/inputmethodkit/imkinputcontroller
- https://developer.apple.com/documentation/inputmethodkit/imkcandidates
- https://github.com/vChewing/vChewing-macOS/tree/977a05fe353bcc43cffbc03ea8b6d815a072fd65/Packages/vChewing_MainAssembly4Darwin
- https://github.com/vChewing/vChewing-macOS/blob/977a05fe353bcc43cffbc03ea8b6d815a072fd65/LICENSE.txt
