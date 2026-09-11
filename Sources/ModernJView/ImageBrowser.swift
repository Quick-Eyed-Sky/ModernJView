import Foundation
import AppKit
import Combine
import ImageIO

enum ZoomMode: Equatable {
    case fitShrinkOnly
    case fitExpand
    case fixed(Int)
}

let zoomLadder = [10, 25, 50, 75, 100, 150, 200, 300, 400, 600, 800]

final class ImageBrowser: ObservableObject {
    @Published var imageURLs: [URL] = []
    @Published var currentIndex: Int? = nil
    @Published var currentImage: NSImage? = nil
    @Published var currentError: String? = nil
    @Published var currentFolder: URL? = nil

    @Published var zoomMode: ZoomMode = .fitShrinkOnly
    @Published var currentZoomPercent: Int = 100
    @Published var rotationDegrees: Int = 0
    @Published var isFlippedHorizontally: Bool = false
    @Published var isFlippedVertically: Bool = false
    @Published var isSlideshowRunning: Bool = false

    private var randomHistory: [Int] = []
    private let settings = AppSettings.shared
    private var slideshowTimer: Timer?

    static let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "bmp", "tif", "tiff", "heic"]

    init() {
        zoomMode = settings.resizeToFit ? (settings.allowExpand ? .fitExpand : .fitShrinkOnly) : .fixed(settings.zoomPercent)
        currentZoomPercent = settings.zoomPercent
    }

    func load(folder: URL, selecting fileToSelect: URL? = nil) {
        currentFolder = folder
        let depth = max(0, settings.folderSearchDepth)
        var found: [URL] = []
        scan(folder: folder, remainingDepth: depth, into: &found)
        found.sort { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        imageURLs = found
        randomHistory.removeAll()
        if let target = fileToSelect?.standardizedFileURL,
           let idx = found.firstIndex(where: { $0.standardizedFileURL == target }) {
            currentIndex = idx
        } else {
            currentIndex = found.isEmpty ? nil : 0
        }
        loadCurrent()
    }

    func loadFiles(_ urls: [URL]) {
        currentFolder = nil
        let files = urls
            .filter { Self.supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        imageURLs = files
        randomHistory.removeAll()
        currentIndex = files.isEmpty ? nil : 0
        loadCurrent()
    }

    func reload() {
        guard let folder = currentFolder else { return }
        let keep = currentIndex.flatMap { imageURLs.indices.contains($0) ? imageURLs[$0] : nil }
        load(folder: folder, selecting: keep)
    }

    private func scan(folder: URL, remainingDepth: Int, into result: inout [URL]) {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return }
        for entry in entries {
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                if remainingDepth > 0 {
                    scan(folder: entry, remainingDepth: remainingDepth - 1, into: &result)
                }
            } else if Self.supportedExtensions.contains(entry.pathExtension.lowercased()) {
                result.append(entry)
            }
        }
    }

    private func loadCurrent() {
        rotationDegrees = 0
        isFlippedHorizontally = false
        isFlippedVertically = false
        guard let idx = currentIndex, idx >= 0, idx < imageURLs.count else {
            currentImage = nil
            currentError = nil
            return
        }
        let url = imageURLs[idx]
        currentImage = ImageCache.shared.image(for: url, disabled: settings.disableCache, limitMB: settings.cacheSizeMB)
        currentError = currentImage == nil ? "Could not open \(url.lastPathComponent)" : nil
    }

    func next() {
        guard !imageURLs.isEmpty, let idx = currentIndex else { return }
        currentIndex = (idx + 1) % imageURLs.count
        loadCurrent()
    }

    func previous() {
        guard !imageURLs.isEmpty, let idx = currentIndex else { return }
        currentIndex = (idx - 1 + imageURLs.count) % imageURLs.count
        loadCurrent()
    }

    func randomNext() {
        guard imageURLs.count > 1, let idx = currentIndex else { return }
        randomHistory.append(idx)
        var newIndex = idx
        while newIndex == idx {
            newIndex = Int.random(in: 0..<imageURLs.count)
        }
        currentIndex = newIndex
        loadCurrent()
    }

    func randomPrevious() {
        guard let last = randomHistory.popLast() else { return }
        currentIndex = last
        loadCurrent()
    }

    func trashCurrent() {
        guard let idx = currentIndex, idx < imageURLs.count else { return }
        let url = imageURLs[idx]
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            imageURLs.remove(at: idx)
            randomHistory.removeAll { $0 >= imageURLs.count }
            if imageURLs.isEmpty {
                currentIndex = nil
            } else {
                currentIndex = min(idx, imageURLs.count - 1)
            }
            loadCurrent()
        } catch {
            currentError = "Could not move to Trash: \(error.localizedDescription)"
        }
    }

    func requestTrashCurrent() {
        guard currentIndex != nil else { return }
        if settings.warnBeforeTrash {
            let alert = NSAlert()
            alert.messageText = "Move this image to the Trash?"
            alert.addButton(withTitle: "Move to Trash")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                trashCurrent()
            }
        } else {
            trashCurrent()
        }
    }

    func goUpOneLevel() {
        guard let folder = currentFolder else { return }
        let parent = folder.deletingLastPathComponent()
        guard parent.path != folder.path else { return }
        load(folder: parent)
    }

    func revealCurrentInFinder() {
        guard let idx = currentIndex, imageURLs.indices.contains(idx) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([imageURLs[idx]])
    }

    func copyPromptToClipboard() {
        guard let idx = currentIndex, imageURLs.indices.contains(idx) else { return }
        guard let prompt = Self.extractPrompt(from: imageURLs[idx]) else {
            NSSound.beep()
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(prompt, forType: .string)
    }

    // Draw Things (and similar Stable Diffusion tools) embed the prompt plus
    // generation parameters as the image's "Description" metadata, e.g.
    // "<prompt text> Steps: 14, Sampler: ..., Model: ...". We only want the
    // prompt, so we cut everything from "Steps:" onward.
    static func extractPrompt(from url: URL) -> String? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }

        var description: String?
        if let png = properties[kCGImagePropertyPNGDictionary] as? [CFString: Any],
           let desc = png[kCGImagePropertyPNGDescription] as? String {
            description = desc
        } else if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
                  let comment = exif[kCGImagePropertyExifUserComment] as? String {
            description = comment
        } else if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
                  let desc = tiff[kCGImagePropertyTIFFImageDescription] as? String {
            description = desc
        } else if let iptc = properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any],
                  let caption = iptc[kCGImagePropertyIPTCCaptionAbstract] as? String {
            description = caption
        }

        guard var text = description, !text.isEmpty else { return nil }
        if let range = text.range(of: "Steps:") {
            text = String(text[text.startIndex..<range.lowerBound])
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    func rotateLeft() { rotationDegrees = (rotationDegrees - 90 + 360) % 360 }
    func rotateRight() { rotationDegrees = (rotationDegrees + 90) % 360 }
    func toggleFlipHorizontal() { isFlippedHorizontally.toggle() }
    func toggleFlipVertical() { isFlippedVertically.toggle() }

    func resetView() {
        rotationDegrees = 0
        isFlippedHorizontally = false
        isFlippedVertically = false
        zoomMode = settings.resizeToFit ? (settings.allowExpand ? .fitExpand : .fitShrinkOnly) : .fixed(settings.zoomPercent)
        currentZoomPercent = settings.zoomPercent
    }

    func setZoomFixed(_ percent: Int) {
        currentZoomPercent = percent
        zoomMode = .fixed(percent)
    }

    func setZoomFitShrink() { zoomMode = .fitShrinkOnly }
    func setZoomFitExpand() { zoomMode = .fitExpand }

    func stepZoom(increasing: Bool) {
        let base: Int
        if case .fixed(let p) = zoomMode { base = p } else { base = currentZoomPercent }
        let candidates = increasing ? zoomLadder.filter { $0 > base } : zoomLadder.filter { $0 < base }
        let newPercent = (increasing ? candidates.min() : candidates.max()) ?? base
        currentZoomPercent = newPercent
        zoomMode = .fixed(newPercent)
    }

    func toggleSlideshow() {
        if isSlideshowRunning {
            slideshowTimer?.invalidate()
            slideshowTimer = nil
            isSlideshowRunning = false
        } else {
            isSlideshowRunning = true
            let interval = max(0.1, settings.autoBrowseInterval)
            slideshowTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.next()
            }
        }
    }
}
