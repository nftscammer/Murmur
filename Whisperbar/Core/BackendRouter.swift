import Foundation

@MainActor
final class BackendRouter {
    static let shared = BackendRouter()

    private let apple = AppleBackend()
    private lazy var whisper = ModelDownloader.shared.whisperBackend
    private lazy var hybrid = HybridBackend()

    private(set) var activeBackend: (any Transcriber)?
    private(set) var activeBackendName: String = ""

    private init() {}

    func selectBackend() -> any Transcriber {
        let isABMode = UserDefaults.standard.bool(forKey: "abTestMode")

        if isABMode {
            let options: [any Transcriber] = [apple, whisper, hybrid]
            let chosen = options[Int.random(in: 0..<options.count)]
            activeBackendName = chosen.identifier
            activeBackend = chosen
            return chosen
        } else {
            let name = UserDefaults.standard.string(forKey: "defaultBackend") ?? "apple"
            let backend: any Transcriber
            switch name {
            case "whisper": backend = whisper
            case "hybrid": backend = hybrid
            default: backend = apple
            }
            activeBackendName = backend.identifier
            activeBackend = backend
            return backend
        }
    }
}
