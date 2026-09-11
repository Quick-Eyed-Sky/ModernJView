import SwiftUI
import AppKit

struct KeyCatcherView: NSViewRepresentable {
    var onKey: (NSEvent) -> Bool
    var onWindowAvailable: ((NSWindow) -> Void)? = nil

    func makeNSView(context: Context) -> KeyCatcherNSView {
        let view = KeyCatcherNSView()
        view.onKey = onKey
        view.onWindowAvailable = onWindowAvailable
        return view
    }

    func updateNSView(_ nsView: KeyCatcherNSView, context: Context) {
        nsView.onKey = onKey
        nsView.onWindowAvailable = onWindowAvailable
    }
}

final class KeyCatcherNSView: NSView {
    var onKey: ((NSEvent) -> Bool)?
    var onWindowAvailable: ((NSWindow) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window = self.window else { return }
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self = self, let window = window else { return }
            window.makeFirstResponder(self)
            self.onWindowAvailable?(window)
        }
    }

    override func keyDown(with event: NSEvent) {
        if let onKey = onKey, onKey(event) {
            return
        }
        super.keyDown(with: event)
    }
}
