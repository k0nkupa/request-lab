import SwiftUI

struct InspectorView: View {
    @Bindable var store: AppStore

    var body: some View {
        ContextInspectorView(store: store)
    }
}
