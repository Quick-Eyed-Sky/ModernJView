import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var browser: ImageBrowser
    @State private var hostWindow: NSWindow?

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if let image = browser.currentImage {
                GeometryReader { geo in
                    let boxes = displayBoxSize(for: image, in: geo.size)
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: boxes.unrotated.width, height: boxes.unrotated.height)
                        .rotationEffect(.degrees(Double(browser.rotationDegrees)))
                        .scaleEffect(x: browser.isFlippedHorizontally ? -1 : 1, y: browser.isFlippedVertically ? -1 : 1)
                        .frame(width: boxes.rotated.width, height: boxes.rotated.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                infoBar(for: image)
            } else if let error = browser.currentError {
                Text(error).foregroundColor(.white)
            } else {
                VStack(spacing: 8) {
                    Text("No folder loaded")
                        .foregroundColor(.white)
                    Text("Use the folder button above, or drag a folder or pictures onto this window")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            KeyCatcherView(onKey: handleKey, onWindowAvailable: { window in
                hostWindow = window
                if browser.currentImage != nil {
                    resizeWindowToFitImage()
                }
            })
            .allowsHitTesting(false)
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: { AppDelegate.shared?.menuOpenFolder() }) {
                    Label("Open Folder", systemImage: "folder")
                }
                Button(action: browser.previous) {
                    Label("Previous", systemImage: "chevron.left")
                }
                Button(action: browser.next) {
                    Label("Next", systemImage: "chevron.right")
                }
                Button(action: browser.randomNext) {
                    Label("Random", systemImage: "shuffle")
                }
                Button(action: browser.toggleSlideshow) {
                    Label(browser.isSlideshowRunning ? "Stop" : "Slideshow", systemImage: browser.isSlideshowRunning ? "pause.fill" : "play.fill")
                }
            }
        }
        .onChange(of: browser.currentIndex) { _ in resizeWindowToFitImage() }
        .onChange(of: browser.zoomMode) { _ in resizeWindowToFitImage() }
        .onChange(of: browser.rotationDegrees) { _ in resizeWindowToFitImage() }
        .onDrop(of: [UTType.fileURL], isTargeted: nil, perform: handleDrop)
        .navigationTitle(windowTitle)
    }

    private var windowTitle: String {
        if let idx = browser.currentIndex, browser.imageURLs.indices.contains(idx) {
            return browser.imageURLs[idx].lastPathComponent
        }
        return "ModernJView"
    }

    @ViewBuilder
    private func infoBar(for image: NSImage) -> some View {
        let pixels = rotatedPixelSize(of: image)
        let percent = currentDisplayPercent(for: image)
        Text("\(windowTitle)  \u{2022}  \(percent)%  \u{2022}  \(Int(pixels.width))\u{00d7}\(Int(pixels.height)) px")
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.55))
            .cornerRadius(6)
            .padding(.top, 8)
    }

    private func pixelSize(of image: NSImage) -> CGSize {
        if let rep = image.representations.first {
            return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        return image.size
    }

    private func rotatedPixelSize(of image: NSImage) -> CGSize {
        let base = pixelSize(of: image)
        return (browser.rotationDegrees == 90 || browser.rotationDegrees == 270)
            ? CGSize(width: base.height, height: base.width) : base
    }

    private func currentDisplayPercent(for image: NSImage) -> Int {
        switch browser.zoomMode {
        case .fixed(let percent):
            return percent
        case .fitShrinkOnly, .fitExpand:
            let pixels = rotatedPixelSize(of: image)
            let screenSize = hostWindow?.screen?.visibleFrame.size ?? NSScreen.main?.visibleFrame.size ?? .zero
            guard pixels.width > 0, screenSize.width > 0 else { return 100 }
            let scale = min(screenSize.width / pixels.width, screenSize.height / pixels.height)
            let effective = browser.zoomMode == .fitShrinkOnly ? min(scale, 1.0) : scale
            return Int((effective * 100).rounded())
        }
    }

    private func baseFittedSize(for size: CGSize, in containerSize: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }
        switch browser.zoomMode {
        case .fitShrinkOnly:
            let scale = min(min(containerSize.width / size.width, containerSize.height / size.height), 1.0)
            return CGSize(width: size.width * scale, height: size.height * scale)
        case .fitExpand:
            let scale = min(containerSize.width / size.width, containerSize.height / size.height)
            return CGSize(width: size.width * scale, height: size.height * scale)
        case .fixed(let percent):
            let zoom = CGFloat(percent) / 100.0
            return CGSize(width: size.width * zoom, height: size.height * zoom)
        }
    }

    private func displayBoxSize(for image: NSImage, in containerSize: CGSize) -> (unrotated: CGSize, rotated: CGSize) {
        let native = pixelSize(of: image)
        let rotated90 = browser.rotationDegrees == 90 || browser.rotationDegrees == 270
        let rotatedNative = rotated90 ? CGSize(width: native.height, height: native.width) : native
        let fittedRotated = baseFittedSize(for: rotatedNative, in: containerSize)
        let fittedUnrotated = rotated90 ? CGSize(width: fittedRotated.height, height: fittedRotated.width) : fittedRotated
        return (unrotated: fittedUnrotated, rotated: fittedRotated)
    }

    private func resizeWindowToFitImage() {
        guard let image = browser.currentImage, let window = hostWindow else { return }
        let rotatedNative = rotatedPixelSize(of: image)
        guard rotatedNative.width > 0, rotatedNative.height > 0 else { return }
        let screenSize = (window.screen ?? NSScreen.main)?.visibleFrame.size ?? CGSize(width: 1280, height: 800)

        var target = baseFittedSize(for: rotatedNative, in: screenSize)
        if case .fixed = browser.zoomMode {
            let clamp = min(1.0, min(screenSize.width / max(target.width, 1), screenSize.height / max(target.height, 1)))
            if clamp < 1.0 {
                target = CGSize(width: target.width * clamp, height: target.height * clamp)
            }
        }
        target.width = max(target.width, 240)
        target.height = max(target.height, 180)

        let oldFrame = window.frame
        let center = CGPoint(x: oldFrame.midX, y: oldFrame.midY)
        window.setContentSize(target)
        var newFrame = window.frame
        newFrame.origin = CGPoint(x: center.x - newFrame.width / 2, y: center.y - newFrame.height / 2)
        window.setFrame(newFrame, display: true, animate: false)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        if event.keyCode == 123 { browser.previous(); return true }
        if event.keyCode == 124 { browser.next(); return true }

        // Everything else (zoom digits, w/e, u, r, delete, +/-) now lives on the
        // real menu bar (Navigation/View/Image/File), so it works consistently
        // and never hijacks typing in the Preferences window's text fields.
        guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty else { return false }

        switch chars {
        case settings.nextImageKey:
            browser.next()
            return true
        case settings.previousImageKey:
            browser.previous()
            return true
        case settings.randomNextKey:
            browser.randomNext()
            return true
        case settings.randomPreviousKey:
            browser.randomPrevious()
            return true
        default:
            return false
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        let group = DispatchGroup()
        var collected: [URL] = []
        let lock = NSLock()
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                var url: URL? = nil
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let directURL = item as? URL {
                    url = directURL
                }
                if let url = url {
                    lock.lock()
                    collected.append(url)
                    lock.unlock()
                }
            }
        }
        group.notify(queue: .main) {
            openDroppedURLs(collected)
        }
        return true
    }

    private func openDroppedURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let directories = urls.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
        let files = urls.filter { !((try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false) }

        if files.count > 1 {
            AppDelegate.shared?.openWindows(forFiles: files)
        } else if let file = files.first {
            browser.load(folder: file.deletingLastPathComponent(), selecting: file)
        } else if let folder = directories.first {
            browser.load(folder: folder)
        }
    }
}
