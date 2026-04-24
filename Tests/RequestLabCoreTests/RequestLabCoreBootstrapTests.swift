import RequestLabCore
import Testing

@Test("RequestLabCore bootstrap type exists")
func requestLabCoreBootstrapTypeExists() {
    let bootstrapType: Any.Type = RequestLabCoreBootstrap.self

    #expect(String(describing: bootstrapType) == "RequestLabCoreBootstrap")
}
