import SwiftUI

@main
struct ModernJViewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About ModernJView") { AppDelegate.shared?.menuShowAbout() }
            }
            CommandGroup(replacing: .newItem) {
                Button("Open Folder\u{2026}") { AppDelegate.shared?.menuOpenFolder() }
                    .keyboardShortcut("o", modifiers: [.command])
            }
            CommandGroup(after: .newItem) {
                Button("Close All") { AppDelegate.shared?.menuCloseAll() }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                Divider()
                Button("Delete") { AppDelegate.shared?.menuDelete() }
                    .keyboardShortcut(.delete, modifiers: [])
                    .disabled(!appDelegate.isBrowserWindowFocused)
                Button("Delete Immediately") { AppDelegate.shared?.menuDeleteImmediately() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                Button("Reveal in Finder") { AppDelegate.shared?.menuRevealInFinder() }
                    .keyboardShortcut("r", modifiers: [.command])
                Button("Reload") { AppDelegate.shared?.menuReload() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            CommandMenu("Edit") {
                Button("Copy Prompt") { AppDelegate.shared?.menuCopyPrompt() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            CommandMenu("Navigation") {
                Button("Next Image") { AppDelegate.shared?.menuNextImage() }
                    .keyboardShortcut(.rightArrow, modifiers: [.command])
                Button("Previous Image") { AppDelegate.shared?.menuPreviousImage() }
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
                Divider()
                Button("Up 1 Level") { AppDelegate.shared?.menuUpOneLevel() }
                    .keyboardShortcut("u", modifiers: [])
                    .disabled(!appDelegate.isBrowserWindowFocused)
                Button("Random") { AppDelegate.shared?.menuRandomNext() }
                    .keyboardShortcut("r", modifiers: [])
                    .disabled(!appDelegate.isBrowserWindowFocused)
            }
            CommandMenu("Zoom") {
                Button("Zoom In") { AppDelegate.shared?.menuZoomIn() }
                    .keyboardShortcut("+", modifiers: [])
                    .disabled(!appDelegate.isBrowserWindowFocused)
                Button("Zoom Out") { AppDelegate.shared?.menuZoomOut() }
                    .keyboardShortcut("-", modifiers: [])
                    .disabled(!appDelegate.isBrowserWindowFocused)
                Divider()
                Button("25% (3)") { AppDelegate.shared?.menuZoom25() }
                    .keyboardShortcut("3", modifiers: [])
                    .disabled(!appDelegate.isBrowserWindowFocused)
                Button("50% (5)") { AppDelegate.shared?.menuZoom50() }
                    .keyboardShortcut("5", modifiers: [])
                    .disabled(!appDelegate.isBrowserWindowFocused)
                Button("75% (7)") { AppDelegate.shared?.menuZoom75() }
                    .keyboardShortcut("7", modifiers: [])
                    .disabled(!appDelegate.isBrowserWindowFocused)
                Button("100% (1)") { AppDelegate.shared?.menuZoom100() }
                    .keyboardShortcut("1", modifiers: [])
                    .disabled(!appDelegate.isBrowserWindowFocused)
                Button("200% (2)") { AppDelegate.shared?.menuZoom200() }
                    .keyboardShortcut("2", modifiers: [])
                    .disabled(!appDelegate.isBrowserWindowFocused)
                Divider()
                Button("Resize to Fit") { AppDelegate.shared?.menuResizeToFit() }
                    .keyboardShortcut("w", modifiers: [])
                    .disabled(!appDelegate.isBrowserWindowFocused)
                Button("Expand to Fit") { AppDelegate.shared?.menuExpandToFit() }
                    .keyboardShortcut("e", modifiers: [])
                    .disabled(!appDelegate.isBrowserWindowFocused)
                Divider()
                Button("Full Screen") { AppDelegate.shared?.menuFullScreen() }
                    .keyboardShortcut("f", modifiers: [.command])
                Button("Auto Browse") { AppDelegate.shared?.menuAutoBrowse() }
                    .keyboardShortcut("x", modifiers: [.command])
            }
            CommandMenu("Image") {
                Button("Rotate Left") { AppDelegate.shared?.menuRotateLeft() }
                    .keyboardShortcut("l", modifiers: [.option])
                Button("Rotate Right") { AppDelegate.shared?.menuRotateRight() }
                    .keyboardShortcut("r", modifiers: [.option])
                Button("Flip Horizontal") { AppDelegate.shared?.menuFlipHorizontal() }
                    .keyboardShortcut("h", modifiers: [.option])
                Button("Flip Vertical") { AppDelegate.shared?.menuFlipVertical() }
                    .keyboardShortcut("v", modifiers: [.option])
                Divider()
                Button("Original") { AppDelegate.shared?.menuOriginal() }
                    .keyboardShortcut("o", modifiers: [.option])
            }
        }
    }
}
