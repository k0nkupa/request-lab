import RequestLabCore
import Testing

@Suite("JSON formatting")
struct JSONFormattingServiceTests {
    @Test("pretty prints JSON objects")
    func prettyPrintsJSONObjects() throws {
        let output = try JSONFormattingService().prettyPrinted(#"{"b":2,"a":1}"#)

        #expect(output.contains(#""a" : 1"#))
        #expect(output.contains(#""b" : 2"#))
    }

    @Test("keeps non JSON values when formatting opportunistically")
    func keepsNonJSONValuesWhenOpportunistic() {
        let output = JSONFormattingService().prettyPrintedIfJSON("plain text")

        #expect(output == "plain text")
    }

    @Test("throws for invalid JSON")
    func throwsForInvalidJSON() {
        #expect(throws: RequestLabError.invalidWorkspace("JSON is invalid")) {
            try JSONFormattingService().prettyPrinted("{")
        }
    }
}
