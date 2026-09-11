import Foundation
import AppKit

enum WindowPlacement: String, CaseIterable, Identifiable {
    case cascade, center, inBackground
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cascade: return "Cascade"
        case .center: return "Center"
        case .inBackground: return "In background"
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var initialFolder: String {
        didSet { defaults.set(initialFolder, forKey: "initialFolder") }
    }
    @Published var warnBeforeTrash: Bool {
        didSet { defaults.set(warnBeforeTrash, forKey: "warnBeforeTrash") }
    }
    @Published var hideWhenLastImageClosed: Bool {
        didSet { defaults.set(hideWhenLastImageClosed, forKey: "hideWhenLastImageClosed") }
    }
    @Published var zoomPercent: Int {
        didSet { defaults.set(zoomPercent, forKey: "zoomPercent") }
    }
    @Published var resizeToFit: Bool {
        didSet { defaults.set(resizeToFit, forKey: "resizeToFit") }
    }
    @Published var allowExpand: Bool {
        didSet { defaults.set(allowExpand, forKey: "allowExpand") }
    }
    @Published var windowPlacement: WindowPlacement {
        didSet { defaults.set(windowPlacement.rawValue, forKey: "windowPlacement") }
    }
    @Published var nextImageKey: String {
        didSet { defaults.set(nextImageKey, forKey: "nextImageKey") }
    }
    @Published var previousImageKey: String {
        didSet { defaults.set(previousImageKey, forKey: "previousImageKey") }
    }
    @Published var randomNextKey: String {
        didSet { defaults.set(randomNextKey, forKey: "randomNextKey") }
    }
    @Published var randomPreviousKey: String {
        didSet { defaults.set(randomPreviousKey, forKey: "randomPreviousKey") }
    }
    @Published var folderSearchDepth: Int {
        didSet { defaults.set(folderSearchDepth, forKey: "folderSearchDepth") }
    }
    @Published var autoBrowseInterval: Double {
        didSet { defaults.set(autoBrowseInterval, forKey: "autoBrowseInterval") }
    }
    @Published var disableCache: Bool {
        didSet { defaults.set(disableCache, forKey: "disableCache") }
    }
    @Published var cacheSizeMB: Int {
        didSet { defaults.set(cacheSizeMB, forKey: "cacheSizeMB") }
    }

    private init() {
        initialFolder = defaults.string(forKey: "initialFolder") ?? NSHomeDirectory()
        warnBeforeTrash = defaults.object(forKey: "warnBeforeTrash") as? Bool ?? true
        hideWhenLastImageClosed = defaults.object(forKey: "hideWhenLastImageClosed") as? Bool ?? false
        zoomPercent = defaults.object(forKey: "zoomPercent") as? Int ?? 100
        resizeToFit = defaults.object(forKey: "resizeToFit") as? Bool ?? true
        allowExpand = defaults.object(forKey: "allowExpand") as? Bool ?? false
        windowPlacement = WindowPlacement(rawValue: defaults.string(forKey: "windowPlacement") ?? "") ?? .center
        nextImageKey = defaults.string(forKey: "nextImageKey") ?? ":"
        previousImageKey = defaults.string(forKey: "previousImageKey") ?? ";"
        randomNextKey = defaults.string(forKey: "randomNextKey") ?? ","
        randomPreviousKey = defaults.string(forKey: "randomPreviousKey") ?? "0"
        folderSearchDepth = defaults.object(forKey: "folderSearchDepth") as? Int ?? 2
        autoBrowseInterval = defaults.object(forKey: "autoBrowseInterval") as? Double ?? 3.0
        disableCache = defaults.object(forKey: "disableCache") as? Bool ?? false
        cacheSizeMB = defaults.object(forKey: "cacheSizeMB") as? Int ?? 2000
    }
}
