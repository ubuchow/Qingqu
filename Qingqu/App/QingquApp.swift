import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = AppModel()
    private var window: NSWindow?
    private var root: PaperRoot?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppFonts.registerBundledFonts()
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = nil
        installMainMenu()
        showMain()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.suspendPreview()
        model.cancel()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMain()
        return false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model.adoptClipboardIfEmpty()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing === window else { return }
        model.suspendPreview()
        closing.makeFirstResponder(nil)
        closing.contentView = nil
        root = nil
        window = nil
        malloc_zone_pressure_relief(nil, 0)
    }

    private func installMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "轻取")
        let quit = NSMenuItem(title: "退出轻取", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        appMenu.addItem(quit)
        appItem.submenu = appMenu
        main.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "文件")
        let closeAndQuit = NSMenuItem(title: "关闭并退出轻取", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "w")
        closeAndQuit.target = NSApp
        fileMenu.addItem(closeAndQuit)
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        for (title, action, key) in [
            ("剪切", #selector(NSText.cut(_:)), "x"),
            ("复制", #selector(NSText.copy(_:)), "c"),
            ("粘贴", #selector(NSText.paste(_:)), "v"),
            ("全选", #selector(NSText.selectAll(_:)), "a"),
        ] {
            editMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        editItem.submenu = editMenu
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    private func showMain() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 880),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.delegate = self
        window.title = "QINGQU"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = Paper.bg
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenNone, .managed]
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        let root = PaperRoot(model: model)
        if #available(macOS 26.0, *) {
            window.isOpaque = false
            window.backgroundColor = .clear
            window.contentView = GlassShell(content: root)
        } else {
            window.contentView = root
        }
        place(window)
        window.minSize = window.frame.size
        window.maxSize = window.frame.size
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak window] in
            guard let window else { return }
            self.place(window)
        }
        self.window = window
        self.root = root
        model.resumePreview()
    }

    private func place(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        var size = NSSize(width: 500, height: 880)
        let visible = screen.visibleFrame
        size.width = min(size.width, visible.width - 40)
        size.height = min(size.height, visible.height - 24)
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.maxY - size.height - 8
        )
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}

@available(macOS 26.0, *)
private final class GlassShell: NSView {
    private let glass = NSGlassEffectView()

    init(content: NSView) {
        super.init(frame: .zero)
        let radius: CGFloat = 20
        wantsLayer = true
        layer?.cornerRadius = radius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        glass.frame = bounds
        glass.autoresizingMask = [.width, .height]
        glass.cornerRadius = radius
        glass.style = .regular
        if #available(macOS 27.0, *) {
            glass.effectIsInteractive = true
        }
        glass.contentView = content
        addSubview(glass)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var isOpaque: Bool { false }

    override func layout() {
        super.layout()
        glass.frame = bounds
        glass.contentView?.frame = glass.bounds
    }
}

@main
enum QingquMain {
    static func main() {
        let application = NSApplication.shared
        let appDelegate = MainActor.assumeIsolated { AppDelegate() }
        application.setActivationPolicy(.regular)
        application.delegate = appDelegate
        application.run()
    }
}
