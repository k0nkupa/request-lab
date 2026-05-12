import RequestLabCore
@preconcurrency import SwiftUI

struct RequestCommandStrip: View {
    @Bindable var store: AppStore

    private var request: APIRequest? {
        store.selectedRequest
    }

    var body: some View {
        HStack(spacing: 10) {
            Picker("Type", selection: requestKindBinding) {
                ForEach(APIRequestKind.allCases, id: \.self) { kind in
                    Label(kind.displayName, systemImage: kind.systemImage)
                        .tag(kind)
                }
            }
            .labelsHidden()
            .labelStyle(.titleAndIcon)
            .frame(width: 138)

            Picker("Method", selection: requestMethodBinding) {
                ForEach(HTTPMethod.allCases, id: \.self) { method in
                    methodBadge(method)
                        .tag(method)
                }
            }
            .labelsHidden()
            .frame(width: 110)

            VariableTokenTextField("Request URL", text: requestURLBinding, unresolvedNames: store.unresolvedVariableNames)
                .controlSize(.large)

            Button("Send", systemImage: "paperplane.fill") {
                Task {
                    await store.sendSelectedRequest()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(RequestLabTheme.primaryAction)
            .controlSize(.large)
            .disabled(request == nil || store.isSending)
        }
        .padding(10)
        .workbenchSurface(.chrome, cornerRadius: 12)
    }

    private func methodBadge(_ method: HTTPMethod) -> some View {
        let color = RequestLabTheme.methodColor(method)

        return Text(method.rawValue)
            .font(.caption.bold())
            .monospaced()
            .foregroundStyle(RequestLabTheme.badgeForeground(for: color))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(RequestLabTheme.softFill(color))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(RequestLabTheme.softStroke(color), lineWidth: 1)
            }
    }

    private var requestKindBinding: Binding<APIRequestKind> {
        binding(
            get: { request?.kind ?? .rest },
            set: { kind in
                store.updateSelectedRequest { request in
                    request.kind = kind

                    if kind == .graphQL {
                        request.method = .post
                        request.graphQL = request.graphQL ?? APIGraphQLPayload(query: "", variables: "{}")
                        request.body = .none
                    } else {
                        request.graphQL = nil
                    }
                }
            }
        )
    }

    private var requestMethodBinding: Binding<HTTPMethod> {
        binding(
            get: { request?.method ?? .get },
            set: { method in
                store.updateSelectedRequest { $0.method = method }
            }
        )
    }

    private var requestURLBinding: Binding<String> {
        binding(
            get: { request?.url ?? "" },
            set: { url in
                store.updateSelectedRequest { $0.url = url }
            }
        )
    }

    @preconcurrency private func binding<Value>(
        get: @escaping () -> Value,
        set: @escaping (Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: { @MainActor in
                get()
            },
            set: { @MainActor value in
                set(value)
            }
        )
    }
}

private extension APIRequestKind {
    var displayName: String {
        switch self {
        case .rest:
            "REST"
        case .graphQL:
            "GraphQL"
        }
    }

    var systemImage: String {
        switch self {
        case .rest:
            "arrow.left.arrow.right"
        case .graphQL:
            "curlybraces"
        }
    }
}
