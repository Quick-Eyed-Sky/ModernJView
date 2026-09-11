import AppKit
import SwiftUI
import Combine

enum LoadRequest {
    case folder(URL)
    case singleFile(URL)
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, ObservableObject {
    static var shared: AppDelegate?

    @Published var isBrowserWindowFocused: Bool = true

    private var windowEntries: [(window: NSWindow, browser: ImageBrowser)] = []
    private var nextCascadePoint = NSPoint.zero
    private var pendingOpenURLs: [URL] = []
    private var pendingOpenWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.regular)
        resetCascadeToScreenTopLeft()
        openNewWindow(loading: nil)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] note in
            guard let self = self, let window = note.object as? NSWindow else { return }
            self.isBrowserWindowFocused = self.windowEntries.contains { $0.window === window }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openNewWindow(loading: nil)
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        pendingOpenURLs.append(contentsOf: urls)
        pendingOpenWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let collected = self.pendingOpenURLs
            self.pendingOpenURLs = []
            self.openItems(collected)
        }
        pendingOpenWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        windowEntries.removeAll { $0.window === window }
        if windowEntries.isEmpty && AppSettings.shared.hideWhenLastImageClosed {
            NSApp.hide(nil)
        }
    }

    // MARK: - Opening

    func openItems(_ urls: [URL]) {
        let directories = urls.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
        let files = urls.filter { !((try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false) }

        if files.count > 1 {
            openFilesAsSeparateWindows(files)
            return
        }

        let request: LoadRequest?
        if let file = files.first {
            request = .singleFile(file)
        } else if let folder = directories.first {
            request = .folder(folder)
        } else {
            request = nil
        }
        guard let request = request else { return }

        if let reusable = windowEntries.first(where: { $0.browser.imageURLs.isEmpty }) {
            apply(request, to: reusable.browser)
            reusable.window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            openNewWindow(loading: request)
        }
    }

    func openWindows(forFiles files: [URL]) {
        openFilesAsSeparateWindows(files)
    }

    private func openFilesAsSeparateWindows(_ files: [URL]) {
        resetCascadeToScreenTopLeft()
        for file in files {
            openNewWindow(loading: .singleFile(file), cascadeBatch: true)
        }
    }

    private func apply(_ request: LoadRequest, to browser: ImageBrowser) {
        switch request {
        case .folder(let url):
            browser.load(folder: url)
        case .singleFile(let url):
            browser.load(folder: url.deletingLastPathComponent(), selecting: url)
        }
    }

    private func resetCascadeToScreenTopLeft() {
        if let screen = NSScreen.main {
            nextCascadePoint = NSPoint(x: screen.visibleFrame.minX + 24, y: screen.visibleFrame.maxY - 24)
        }
    }

    @discardableResult
    private func openNewWindow(loading request: LoadRequest?, cascadeBatch: Bool = false) -> NSWindow {
        let browser = ImageBrowser()
        if let request = request {
            apply(request, to: browser)
        }

        let hosting = NSHostingController(rootView: ContentView(browser: browser))
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = "ModernJView"
        window.delegate = self
        window.setContentSize(NSSize(width: 900, height: 700))
        windowEntries.append((window, browser))

        if cascadeBatch {
            nextCascadePoint = window.cascadeTopLeft(from: nextCascadePoint)
            window.makeKeyAndOrderFront(nil)
        } else {
            switch AppSettings.shared.windowPlacement {
            case .center:
                window.center()
                window.makeKeyAndOrderFront(nil)
            case .cascade:
                nextCascadePoint = window.cascadeTopLeft(from: nextCascadePoint)
                window.makeKeyAndOrderFront(nil)
            case .inBackground:
                window.orderBack(nil)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        return window
    }

    // MARK: - Menu commands (act on the key window)

    private func keyBrowser() -> ImageBrowser? {
        if let key = NSApp.keyWindow, let match = windowEntries.first(where: { $0.window === key }) {
            return match.browser
        }
        return windowEntries.first?.browser
    }

    func menuOpenFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.directoryURL = URL(fileURLWithPath: AppSettings.shared.initialFolder)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let browser = keyBrowser() {
            browser.load(folder: url)
        } else {
            openNewWindow(loading: .folder(url))
        }
    }

    func menuCloseAll() {
        for entry in windowEntries {
            entry.window.close()
        }
    }

    func menuDelete() { keyBrowser()?.requestTrashCurrent() }
    func menuDeleteImmediately() { keyBrowser()?.trashCurrent() }
    func menuRevealInFinder() { keyBrowser()?.revealCurrentInFinder() }
    func menuReload() { keyBrowser()?.reload() }
    func menuRotateLeft() { keyBrowser()?.rotateLeft() }
    func menuRotateRight() { keyBrowser()?.rotateRight() }
    func menuFlipHorizontal() { keyBrowser()?.toggleFlipHorizontal() }
    func menuFlipVertical() { keyBrowser()?.toggleFlipVertical() }
    func menuOriginal() { keyBrowser()?.resetView() }
    func menuAutoBrowse() { keyBrowser()?.toggleSlideshow() }
    func menuFullScreen() { NSApp.keyWindow?.toggleFullScreen(nil) }

    func menuUpOneLevel() { keyBrowser()?.goUpOneLevel() }
    func menuRandomNext() { keyBrowser()?.randomNext() }
    func menuNextImage() { keyBrowser()?.next() }
    func menuPreviousImage() { keyBrowser()?.previous() }

    func menuZoomIn() { keyBrowser()?.stepZoom(increasing: true) }
    func menuZoomOut() { keyBrowser()?.stepZoom(increasing: false) }
    func menuZoom25() { keyBrowser()?.setZoomFixed(25) }
    func menuZoom50() { keyBrowser()?.setZoomFixed(50) }
    func menuZoom75() { keyBrowser()?.setZoomFixed(75) }
    func menuZoom100() { keyBrowser()?.setZoomFixed(100) }
    func menuZoom200() { keyBrowser()?.setZoomFixed(200) }
    func menuResizeToFit() { keyBrowser()?.setZoomFitShrink() }
    func menuExpandToFit() { keyBrowser()?.setZoomFitExpand() }
    func menuCopyPrompt() { keyBrowser()?.copyPromptToClipboard() }

    func menuShowAbout() {
        let credits = NSMutableAttributedString(
            string: "A modern Apple Silicon rebuild of the original JView,\ncreated by Allan Liu."
        )
        if let range = credits.string.range(of: "Allan Liu") {
            let nsRange = NSRange(range, in: credits.string)
            credits.addAttribute(.link, value: URL(string: "http://home.nc.rr.com/jview/jbrowser.html")!, range: nsRange)
        }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let fullRange = NSRange(location: 0, length: credits.length)
        credits.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        credits.addAttribute(.font, value: NSFont.systemFont(ofSize: 11), range: fullRange)

        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}
