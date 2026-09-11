import SwiftUI
import AppKit

struct PreferencesView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Initial folder") {
                HStack {
                    TextField("Initial folder", text: $settings.initialFolder)
                    Button("Select\u{2026}") { pickFolder() }
                }
            }

            Toggle("Warn before trashing the image", isOn: $settings.warnBeforeTrash)
            Toggle("Hide app when last window is closed", isOn: $settings.hideWhenLastImageClosed)

            Section("Open image") {
                HStack {
                    Text("Zoom:")
                    TextField("", value: $settings.zoomPercent, formatter: NumberFormatter())
                        .frame(width: 50)
                        .disabled(settings.resizeToFit)
                    Text("%")
                }
                Toggle("Resize to fit screen", isOn: $settings.resizeToFit)
                Toggle("Allow to expand", isOn: $settings.allowExpand)

                Picker("Window placement", selection: $settings.windowPlacement) {
                    ForEach(WindowPlacement.allCases) { placement in
                        Text(placement.label).tag(placement)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Image navigation") {
                HStack {
                    Text("Next image key:")
                    TextField("", text: $settings.nextImageKey).frame(width: 36)
                }
                HStack {
                    Text("Previous image key:")
                    TextField("", text: $settings.previousImageKey).frame(width: 36)
                }
                HStack {
                    Text("Random next key:")
                    TextField("", text: $settings.randomNextKey).frame(width: 36)
                }
                HStack {
                    Text("Random previous key:")
                    TextField("", text: $settings.randomPreviousKey).frame(width: 36)
                }
                Stepper("Folder search depth: \(settings.folderSearchDepth)", value: $settings.folderSearchDepth, in: 0...10)
                HStack {
                    Text("Auto browse interval:")
                    TextField("", value: $settings.autoBrowseInterval, formatter: NumberFormatter())
                        .frame(width: 60)
                    Text("second")
                }
            }

            Section("Image cache") {
                Toggle("Disable cache", isOn: $settings.disableCache)
                HStack {
                    Text("Cache size:")
                    TextField("", value: $settings.cacheSizeMB, formatter: NumberFormatter())
                        .frame(width: 80)
                        .disabled(settings.disableCache)
                    Text("mbytes")
                }
            }
        }
        .toggleStyle(.checkbox)
        .padding(20)
        .frame(minWidth: 420, alignment: .leading)
        .fixedSize()
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            settings.initialFolder = url.path
        }
    }
}
