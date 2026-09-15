import AppKit
import SwiftUI

@main
struct QingquApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        AppFonts.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(appDelegate.model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 440, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("选取下载文件夹…") {
                    appDelegate.model.chooseFolder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppFonts.registerBundledFonts()
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Dock click: reuse visible window, or let SwiftUI create exactly one if none remain.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let windows = mainWindows(in: sender)
        if flag || windows.contains(where: \.isVisible) {
            windows.filter(\.isVisible).forEach { $0.makeKeyAndOrderFront(nil) }
            collapseDuplicateWindows()
            sender.activate(ignoringOtherApps: true)
            return false
        }
        // No window left — allow WindowGroup to open a single new one.
        sender.activate(ignoringOtherApps: true)
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        collapseDuplicateWindows()
        model.adoptClipboardIfEmpty()
    }

    private func collapseDuplicateWindows() {
        let windows = mainWindows(in: NSApp).filter(\.isVisible)
        guard windows.count > 1 else { return }
        let keep = windows[0]
        keep.makeKeyAndOrderFront(nil)
        for duplicate in windows.dropFirst() {
            duplicate.close()
        }
    }

    private func mainWindows(in app: NSApplication) -> [NSWindow] {
        app.windows.filter { window in
            !(window is NSPanel)
                && window.contentView != nil
                && (window.styleMask.contains(.titled) || window.styleMask.contains(.fullSizeContentView))
        }
    }
}

/// Styles the SwiftUI window without replacing its close behavior.
struct WindowConfigurator: NSViewRepresentable {
    final class Coordinator {
        var didConfigure = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { apply(view, coordinator: context.coordinator) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(nsView, coordinator: context.coordinator) }
    }

    private func apply(_ view: NSView, coordinator: Coordinator) {
        guard let window = view.window else { return }
        guard !coordinator.didConfigure else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .windowBackgroundColor
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.minSize = NSSize(width: 440, height: 660)
        window.collectionBehavior.insert([.fullScreenPrimary, .managed])
        if !window.styleMask.contains(.resizable) {
            window.styleMask.insert(.resizable)
        }
        if !window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.insert(.fullSizeContentView)
        }
        window.standardWindowButton(.zoomButton)?.isEnabled = true
        if let screen = NSScreen.main {
            let size = NSSize(width: 440, height: 680)
            let origin = NSPoint(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.midY - size.height / 2
            )
            window.setFrame(NSRect(origin: origin, size: size), display: true)
        }
        coordinator.didConfigure = true
    }
}
