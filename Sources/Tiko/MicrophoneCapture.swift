import AVFoundation
import Combine

enum MicrophoneCaptureError: LocalizedError {
    case noInputDevice
    case couldNotStart(String)

    var errorDescription: String? {
        switch self {
        case .noInputDevice:
            return "koi mic nahi mila"
        case .couldNotStart(let reason):
            return "mic start nahi hua: \(reason)"
        }
    }
}

/// Records from the default microphone while push-to-talk is held. Publishes
/// how loud the audio is (for the waveform) and hands every audio buffer to a
/// consumer — speech recognition, from Phase 5.
@MainActor
final class MicrophoneCapture: ObservableObject {
    /// Root-mean-square loudness of the latest audio chunk. Speech is roughly 0.01–0.2.
    @Published private(set) var audioLevel: CGFloat = 0

    private(set) var isCapturing = false
    private var audioEngine: AVAudioEngine?

    func start(onAudioBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void = { _ in }) throws {
        guard !isCapturing else { return }

        // A fresh engine per question picks up whatever the default input is
        // right now, so switching to AirPods between questions just works.
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw MicrophoneCaptureError.noInputDevice
        }

        let audioTapBlock = Self.makeAudioTapBlock(
            onAudioBuffer: onAudioBuffer,
            onAudioLevel: { [weak self] measuredAudioLevel in
                Task { @MainActor [weak self] in
                    guard let self, self.isCapturing else { return }
                    self.audioLevel = measuredAudioLevel
                }
            }
        )
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat, block: audioTapBlock)

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw MicrophoneCaptureError.couldNotStart(error.localizedDescription)
        }

        self.audioEngine = audioEngine
        isCapturing = true
    }

    func stop() {
        guard let audioEngine else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        self.audioEngine = nil
        isCapturing = false
        audioLevel = 0
    }

    /// Built outside the main actor on purpose: Core Audio calls the tap on its
    /// own real-time audio thread, many times a second.
    nonisolated private static func makeAudioTapBlock(
        onAudioBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void,
        onAudioLevel: @escaping @Sendable (CGFloat) -> Void
    ) -> AVAudioNodeTapBlock {
        return { audioBuffer, _ in
            onAudioBuffer(audioBuffer)

            guard let firstChannelSamples = audioBuffer.floatChannelData?[0] else { return }
            let frameCount = Int(audioBuffer.frameLength)
            guard frameCount > 0 else { return }

            var sumOfSquaredSamples: Float = 0
            for frameIndex in 0..<frameCount {
                let sample = firstChannelSamples[frameIndex]
                sumOfSquaredSamples += sample * sample
            }
            // Root-mean-square is the standard measure of how loud a chunk of audio is.
            let rootMeanSquareLevel = sqrt(sumOfSquaredSamples / Float(frameCount))
            onAudioLevel(CGFloat(rootMeanSquareLevel))
        }
    }
}
