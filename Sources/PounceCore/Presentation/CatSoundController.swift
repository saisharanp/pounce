import AVFoundation
import Foundation

public enum CatSoundKind: String, CaseIterable, Sendable {
    case purr
    case meow
    case chirp
    case play
    case eat
}

public struct CatSoundPlaybackPlan: Equatable, Sendable {
    public let data: Data
    public let volume: Float

    public init(data: Data, volume: Float) {
        self.data = data
        self.volume = volume
    }
}

/// Plays short, locally synthesized responses. Audio is optional: construction
/// and playback failures are intentionally ignored so controls never fail.
@MainActor
public final class CatSoundController {
    private var player: AVAudioPlayer?

    public init() {}

    public func play(_ sound: CatSoundKind, isMuted: Bool, volume: Double) {
        guard let plan = Self.playbackPlan(
            for: sound,
            isMuted: isMuted,
            volume: volume
        ) else {
            stop()
            return
        }

        do {
            let player = try AVAudioPlayer(data: plan.data)
            player.volume = plan.volume
            player.prepareToPlay()
            guard player.play() else { return }
            self.player = player
        } catch {
            // Sound is an optional enhancement; UI and reactions stay usable.
        }
    }

    public func stop() {
        player?.stop()
        player = nil
    }

    public static func playbackPlan(
        for sound: CatSoundKind,
        isMuted: Bool,
        volume: Double
    ) -> CatSoundPlaybackPlan? {
        guard !isMuted else { return nil }
        return CatSoundPlaybackPlan(
            data: toneData(for: sound),
            volume: Float(PetState.clampedVolume(volume))
        )
    }

    public static func sound(
        for interaction: CatInteraction,
        reaction: CatReaction
    ) -> CatSoundKind? {
        switch interaction {
        case .treat:
            return .eat
        case .feather:
            return .chirp
        case .laser, .yarn, .paperBall:
            return .play
        case .click, .gentlePet, .hurriedAttention:
            switch reaction.expression {
            case .purr, .slowBlink:
                return .purr
            case .meow:
                return .meow
            case .chirp:
                return .chirp
            case .neutral, .blink, .sideEye, .startled:
                return nil
            }
        }
    }

    public static func toneData(for sound: CatSoundKind) -> Data {
        let sampleRate = 22_050
        let characteristics: (duration: Double, start: Double, end: Double, wobble: Double)
        switch sound {
        case .purr:
            characteristics = (0.24, 76, 70, 18)
        case .meow:
            characteristics = (0.20, 510, 330, 22)
        case .chirp:
            characteristics = (0.11, 860, 1_220, 35)
        case .play:
            characteristics = (0.14, 660, 920, 45)
        case .eat:
            characteristics = (0.18, 250, 180, 12)
        }

        let sampleCount = max(1, Int(Double(sampleRate) * characteristics.duration))
        var samples = [Int16]()
        samples.reserveCapacity(sampleCount)
        var phase = 0.0

        for index in 0..<sampleCount {
            let progress = Double(index) / Double(max(1, sampleCount - 1))
            let frequency = characteristics.start
                + (characteristics.end - characteristics.start) * progress
                + sin(progress * .pi * 4) * characteristics.wobble
            phase += 2 * .pi * frequency / Double(sampleRate)
            let envelope = sin(.pi * progress)
            let harmonic = sin(phase) * 0.82 + sin(phase * 2) * 0.18
            samples.append(Int16(clamping: Int(harmonic * envelope * 12_000)))
        }

        return wavData(samples: samples, sampleRate: sampleRate)
    }

    private static func wavData(samples: [Int16], sampleRate: Int) -> Data {
        let bytesPerSample = 2
        let payloadSize = samples.count * bytesPerSample
        var data = Data()
        data.reserveCapacity(44 + payloadSize)
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // RIFF
        appendLittleEndian(UInt32(36 + payloadSize), to: &data)
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // WAVE
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // fmt
        appendLittleEndian(UInt32(16), to: &data)
        appendLittleEndian(UInt16(1), to: &data)
        appendLittleEndian(UInt16(1), to: &data)
        appendLittleEndian(UInt32(sampleRate), to: &data)
        appendLittleEndian(UInt32(sampleRate * bytesPerSample), to: &data)
        appendLittleEndian(UInt16(bytesPerSample), to: &data)
        appendLittleEndian(UInt16(16), to: &data)
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // data
        appendLittleEndian(UInt32(payloadSize), to: &data)
        for sample in samples {
            appendLittleEndian(sample, to: &data)
        }
        return data
    }

    private static func appendLittleEndian<Integer: FixedWidthInteger>(
        _ value: Integer,
        to data: inout Data
    ) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            data.append(contentsOf: bytes)
        }
    }
}
