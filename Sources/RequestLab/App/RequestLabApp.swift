import AppKit
import SwiftUI

@main
struct RequestLabApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup("RequestLab") {
            ContentView(store: store)
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            CommandMenu("Request") {
                Button("Send") {}
                    .keyboardShortcut(.return, modifiers: [.command])

                Button("Save") {}
                    .keyboardShortcut("s", modifiers: [.command])
            }

            CommandGroup(after: .toolbar) {
                Button(store.isInspectorVisible ? "Hide Inspector" : "Show Inspector") {
                    store.isInspectorVisible.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }
        }

        Settings {
            Form {
                Section("Workspace") {
                    LabeledContent("Default storage", value: "Local workspace files")
                    Toggle("Show inspector on launch", isOn: .constant(true))
                }
            }
            .formStyle(.grouped)
            .padding()
            .frame(width: 420)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
