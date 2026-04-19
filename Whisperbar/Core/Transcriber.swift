import Foundation

protocol Transcriber {
    var identifier: String { get }
    func transcribe(audio: [Float]) async throws -> String
    func startStreaming(audioCallback: @escaping ([Float]) -> Void,
                        partialResultCallback: @escaping (String) -> Void) async throws
    func stopStreaming() async throws -> String
}

enum TranscriberError: LocalizedError {
    case modelNotLoaded
    case recognitionFailed(String)
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "Whisper model not loaded"
        case .recognitionFailed(let msg): return "Recognition failed: \(msg)"
        case .permissionDenied: return "Speech recognition permission denied"
        }
    }
}
