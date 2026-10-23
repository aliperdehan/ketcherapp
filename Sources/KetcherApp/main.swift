import AppKit
import WebKit

let appVersion = "0.1.1"

final class AppDelegate: NSObject, NSApplicationDelegate {
    let host: WebHost
    let window: NSWindow
    let selfTest: Bool
    private var runner: SelfTest?

    init(selfTest: Bool) {
        self.selfTest = selfTest
        let resources = Bundle.main.resourceURL ?? URL(fileURLWithPath: "web/..")
        host = WebHost(resources: resources)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 820),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        super.init()
        window.title = "Ketcher"
        window.contentView = host.webView
        window.contentMinSize = NSSize(width: 800, height: 520)
        host.window = window
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        host.load()
        if selfTest {
            runner = SelfTest(host: host)
            runner?.run()
            return
        }
        NSApp.mainMenu = Self.makeMenu()
        if !window.setFrameUsingName("main") { window.center() }
        window.setFrameAutosaveName("main")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // The Edit items are needed: WKWebView only gets ⌘X/⌘C/⌘V through the menu. Select All and Undo/Redo are left
    // out on purpose, so ⌘A and ⌘Z reach Ketcher's own key handling instead of selecting page text.
    static func makeMenu() -> NSMenu {
        let main = NSMenu()
        func add(_ menu: NSMenu, to title: String) {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = menu
            main.addItem(item)
        }

        let app = NSMenu(title: "Ketcher")
        app.addItem(withTitle: "About Ketcher", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                    keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Hide Ketcher", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = app.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)),
                                 keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        app.addItem(.separator())
        app.addItem(withTitle: "Quit Ketcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        add(app, to: "Ketcher")

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        add(edit, to: "Edit")

        let view = NSMenu(title: "View")
        let full = view.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)),
                                keyEquivalent: "f")
        full.keyEquivalentModifierMask = [.command, .control]
        add(view, to: "View")

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        add(windowMenu, to: "Window")
        NSApp.windowsMenu = windowMenu
        return main
    }
}

let args = CommandLine.arguments
if args.contains("--version") {
    print("KetcherApp \(appVersion)")
    exit(0)
}
let app = NSApplication.shared
let delegate = AppDelegate(selfTest: args.contains("--selftest"))
app.setActivationPolicy(delegate.selfTest ? .accessory : .regular)
app.delegate = delegate
app.run()
