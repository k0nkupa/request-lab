import SwiftUI

struct RequestEditorView: View {
    @Bindable var store: AppStore

    var body: some View {
        RequestWorkbenchView(store: store)
    }
}
