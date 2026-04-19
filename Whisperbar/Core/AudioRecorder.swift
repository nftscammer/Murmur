import AVFoundation
import Combine

@MainActor
final class AudioRecorder: ObservableObject {
    static let shared = AudioRecorder()

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                              sampleRate: 16000,
                                              channels: 1,
                                              interleaved: false)!

    private(set) var audioBuffer: [Float] = []

    // Called on main thread with each 16kHz chunk — wire up to backends
    var onAudioChunk: (([Float]) -> Void)?

    private var levelThrottle = ThrottledPublisher<Float>(interval: 1.0 / 30.0)
    private var cancelBag = Set<AnyCancellable>()

    let maxBufferSeconds: Double = 300

    private init() {
        levelThrottle.subject
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                guard let self else { return }
                AppState.shared.audioLevel = level
            }
            .store(in: &cancelBag)
    }

    func startRecording() throws {
        audioBuffer = []

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processTap(buffer: buffer)
        }

        try engine.start()
    }

    func stopRecording() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        onAudioChunk = nil
        let result = audioBuffer
        audioBuffer = []
        return result
    }

    private func processTap(buffer: AVAudioPCMBuffer) {
        guard let converter = converter else { return }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1)
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else { return }

        var error: NSError?
        var inputConsumed = false
        converter.convert(to: converted, error: &error) { _, status in
            if inputConsumed {
                status.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            status.pointee = .haveData
            return buffer
        }
        if error != nil { return }

        guard let channelData = converted.floatChannelData?[0] else { return }
        let frameCount = Int(converted.frameLength)
        guard frameCount > 0 else { return }
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))

        // RMS level
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
        let db = 20 * log10(max(rms, 1e-9))
        let normalised = Float(max(0, min(1, (db + 60) / 60)))

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.levelThrottle.send(normalised)
            self.audioBuffer.append(contentsOf: samples)
            self.onAudioChunk?(samples)

            if Double(self.audioBuffer.count) / 16000 >= self.maxBufferSeconds {
                Task { @MainActor in
                    await DictationController.shared.endRecording()
                }
            }
        }
    }
}

final class ThrottledPublisher<T> {
    let subject = PassthroughSubject<T, Never>()
    private let interval: TimeInterval
    private var lastSent = Date.distantPast

    init(interval: TimeInterval) { self.interval = interval }

    func send(_ value: T) {
        let now = Date()
        if now.timeIntervalSince(lastSent) >= interval {
            lastSent = now
            subject.send(value)
        }
    }
}
