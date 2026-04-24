import RequestLabCore
import SwiftUI

struct InspectorView: View {
    let request: APIRequest?
    let environment: APIEnvironment?
    let response: APIExecutionResult?
    let errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                requestSection
                Divider()
                environmentSection
                Divider()
                responseSection
            }
            .padding()
        }
    }

    private var requestSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Request")
                .font(.headline)

            if let request {
                LabeledContent("Name", value: request.name)
                LabeledContent("Method", value: request.method.rawValue)
                LabeledContent("URL", value: request.url)
                LabeledContent("Headers", value: "\(request.headers.count)")
                LabeledContent("Params", value: "\(request.params.count)")
            } else {
                ContentUnavailableView("No request selected", systemImage: "doc.text")
            }
        }
    }

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Environment")
                .font(.headline)

            if let environment {
                LabeledContent("Name", value: environment.name)

                ForEach(environment.variables) { variable in
                    LabeledContent(variable.name) {
                        Text(variable.isSecret ? "Secret" : (variable.value ?? "Empty"))
                            .foregroundStyle(variable.isSecret ? .secondary : .primary)
                            .textSelection(.enabled)
                    }
                }
            } else {
                ContentUnavailableView("No environment selected", systemImage: "server.rack")
            }
        }
    }

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last Response")
                .font(.headline)

            if let response {
                LabeledContent("Status", value: "\(response.statusCode)")
                LabeledContent("Duration", value: "\(response.durationMilliseconds) ms")
                LabeledContent("URL", value: response.url)
                LabeledContent("Headers", value: "\(response.headers.count)")
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            } else {
                ContentUnavailableView("No response", systemImage: "tray")
            }
        }
    }
}
