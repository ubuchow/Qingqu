import AppKit
import SwiftUI

@main
struct QingquApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let window = sender.windows.first(where: { $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        } else if let window = sender.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model.adoptClipboardIfEmpty()
    }
}

final class WindowCloser: NSObject, NSWindowDelegate {
    static let shared = WindowCloser()

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender.styleMask.contains(.fullScreen) {
            sender.toggleFullScreen(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                sender.orderOut(nil)
            }
            return false
        }
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
            // Ensure the window lands on a visible display.
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
