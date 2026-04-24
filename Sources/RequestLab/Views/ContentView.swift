import RequestLabCore
import SwiftUI

struct ContentView: View {
    @Bindable var store: AppStore

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
        } detail: {
            HSplitView {
                RequestEditorView(store: store)
                    .frame(minWidth: 560)

                if store.isInspectorVisible {
                    InspectorView(
                        request: store.selectedRequest,
                        environment: store.selectedEnvironment,
                        response: store.latestResponse,
                        errorMessage: store.executionErrorMessage
                    )
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Send", systemImage: "paperplane") {
                    Task {
                        await store.sendSelectedRequest()
                    }
                }
                .disabled(store.selectedRequest == nil || store.isSending)
                .help("Send request")

                Button("Save", systemImage: "square.and.arrow.down") {}
                    .help("Save workspace")
            }

            ToolbarItem(placement: .principal) {
                Picker("Environment", selection: $store.selectedEnvironmentID) {
                    ForEach(store.workspace.environments) { environment in
                        Text(environment.name)
                            .tag(Optional(environment.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 180)
            }

            ToolbarItem {
                Button(
                    "Inspector",
                    systemImage: store.isInspectorVisible ? "sidebar.trailing" : "sidebar.right"
                ) {
                    store.isInspectorVisible.toggle()
                }
                .help(store.isInspectorVisible ? "Hide inspector" : "Show inspector")
            }
        }
    }
}
