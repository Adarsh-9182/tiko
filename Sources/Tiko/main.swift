import AppKit

// Tiko has no main window and no Dock icon — it lives in the menu bar — so the
// app is started by hand here instead of through a SwiftUI `App` scene.
//
// Top-level code always runs on the main thread, but the compiler can't prove
// that, so `assumeIsolated` tells it we are on the main actor.
MainActor.assumeIsolated {
    let application = NSApplication.shared
    // `run()` below never returns while the app is alive, so this local keeps
    // the delegate alive for the whole session.
    let appDelegate = TikoAppDelegate()
    application.delegate = appDelegate
    // `.accessory` keeps Tiko out of the Dock and the ⌘-Tab switcher. Info.plist's
    // LSUIElement does the same for the .app; this also covers `swift run`.
    application.setActivationPolicy(.accessory)
    application.run()
}
