import AppKit

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, NSImage>()

    func image(for url: URL, disabled: Bool, limitMB: Int) -> NSImage? {
        if disabled {
            return NSImage(contentsOf: url)
        }
        cache.totalCostLimit = max(1, limitMB) * 1024 * 1024
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        guard let image = NSImage(contentsOf: url) else { return nil }
        let size = image.size
        let cost = Int(size.width * size.height * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
        return image
    }
}
