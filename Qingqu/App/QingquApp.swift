import AppKit
import SwiftUI

@main
struct QingquApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Single window — avoids Dock reopen creating a second WindowGroup instance.
        Window("轻取", id: "main") {
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
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Dock / app-icon click. Always reuse the existing window; never open another.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow(in: sender)
        return false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        collapseDuplicateWindows()
        model.adoptClipboardIfEmpty()
    }

    private func showMainWindow(in app: NSApplication) {
        let windows = mainWindows(in: app)
        if let main = windows.first {
            main.makeKeyAndOrderFront(nil)
            destroyDuplicates(windows.dropFirst())
        }
        app.activate(ignoringOtherApps: true)
    }

    private func collapseDuplicateWindows() {
        let windows = mainWindows(in: NSApp)
        guard windows.count > 1 else { return }
        if let visible = windows.first(where: \.isVisible) ?? windows.first {
            visible.makeKeyAndOrderFront(nil)
            destroyDuplicates(windows.filter { $0 !== visible })
        }
    }

    private func mainWindows(in app: NSApplication) -> [NSWindow] {
        app.windows.filter { window in
            !(window is NSPanel)
                && window.contentView != nil
                && (window.styleMask.contains(.titled) || window.styleMask.contains(.fullSizeContentView))
        }
    }

    private func destroyDuplicates<S: Sequence>(_ windows: S) where S.Element == NSWindow {
        for window in windows {
            WindowCloser.shared.allowDestroy = true
            window.delegate = nil
            window.close()
            WindowCloser.shared.allowDestroy = false
        }
    }
}

final class WindowCloser: NSObject, NSWindowDelegate {
    static let shared = WindowCloser()
    var allowDestroy = false

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if allowDestroy { return true }
        if sender.styleMask.contains(.fullScreen) {
            sender.toggleFullScreen(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                sender.orderOut(nil)
            }
            return false
        }
        // Hide instead of destroy so Dock reopen can reuse this window.
        sender.orderOut(nil)
        return false
    }
}

struct WindowConfigurator: NSViewRepresentable {
    var closer: WindowCloser

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
        if !coordinator.didConfigure {
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
        if window.delegate !== closer {
            window.delegate = closer
        }
    }
}
