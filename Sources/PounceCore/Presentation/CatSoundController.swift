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
        case .doubleClick, .scrollUp:
            return .chirp
        case .scrollDown, .secondaryClick, .click, .gentlePet, .hurriedAttention:
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
        let sampleRate = 44_100.0
        let samples: [Double]
        switch sound {
        case .meow:
            samples = meowVoice(sampleRate: sampleRate)
        case .purr:
            samples = purrVoice(sampleRate: sampleRate)
        case .chirp:
            samples = chirpVoice(sampleRate: sampleRate)
        case .play:
            samples = playVoice(sampleRate: sampleRate)
        case .eat:
            samples = eatVoice(sampleRate: sampleRate)
        }
        return wavData(samples: pcm16(samples), sampleRate: Int(sampleRate))
    }

    /// Source-filter miaow: glottal pulses through moving formants, not a sine beep.
    private static func meowVoice(sampleRate: Double) -> [Double] {
        renderVoice(duration: 0.62, sampleRate: sampleRate, seed: 0x4D30) { t, seconds in
            let vibrato = sin(seconds * 2 * .pi * 11) * 16 * max(0, min(1, (t - 0.28) / 0.12))
            let f0 = contour(t, [
                (0.00, 380), (0.10, 430), (0.28, 790), (0.40, 870),
                (0.58, 560), (0.80, 330), (1.00, 240)
            ]) + vibrato
            return VoiceFrame(
                f0: f0,
                f1: contour(t, [(0.00, 340), (0.18, 430), (0.40, 520), (0.70, 680), (1.00, 740)]),
                f2: contour(t, [
                    (0.00, 920), (0.12, 1_350), (0.30, 2_480), (0.46, 2_280),
                    (0.72, 1_180), (1.00, 960)
                ]),
                f3: contour(t, [(0.00, 2_200), (0.32, 3_250), (1.00, 2_480)]),
                amp: contour(t, [
                    (0.00, 0), (0.05, 0.55), (0.14, 0.95), (0.36, 1),
                    (0.68, 0.78), (1.00, 0)
                ]),
                noise: contour(t, [(0.00, 0.04), (0.2, 0.07), (0.7, 0.10), (1.00, 0.16)]),
                roll: 0
            )
        }
    }

    /// 26 Hz inhale/exhale glottal slaps — the rumble cats actually make.
    private static func purrVoice(sampleRate: Double) -> [Double] {
        let duration = 0.92
        let count = max(1, Int(duration * sampleRate))
        var noise = Noise(state: 0x5055)
        var samples = [Double](repeating: 0, count: count)
        var low = 0.0
        let rate = 26.0
        let alpha = 1 - exp(-2 * .pi * 240 / sampleRate)
        for index in 0..<count {
            let seconds = Double(index) / sampleRate
            let progress = Double(index) / Double(max(1, count - 1))
            let cycle = seconds * rate
            let pulse = Int(cycle)
            let phase = cycle - Double(pulse)
            let burst = exp(-phase * 4.2)
            let body = pulse.isMultiple(of: 2) ? 1.0 : 0.82
            let rumble = sin(phase * 2 * .pi) * 0.95
                + sin(phase * 2 * .pi * 2) * 0.48
                + sin(phase * 2 * .pi * 3) * 0.20
                + sin(phase * 2 * .pi * 4) * 0.08
            let air = noise.next() * burst * 0.06
            let fade = min(progress / 0.08, 1) * min((1 - progress) / 0.14, 1)
            let raw = (rumble * burst + air) * body * fade
            low += alpha * (raw - low)
            samples[index] = low
        }
        return samples
    }

    /// Greeting trill: rolled, rising, then a little fall.
    private static func chirpVoice(sampleRate: Double) -> [Double] {
        renderVoice(duration: 0.28, sampleRate: sampleRate, seed: 0xC412) { t, _ in
            VoiceFrame(
                f0: contour(t, [(0.00, 520), (0.45, 1_520), (0.72, 1_280), (1.00, 780)]),
                f1: contour(t, [(0.00, 480), (0.5, 560), (1.00, 620)]),
                f2: contour(t, [(0.00, 1_700), (0.45, 2_600), (1.00, 1_800)]),
                f3: 3_100,
                amp: contour(t, [(0.00, 0), (0.08, 1), (0.75, 0.7), (1.00, 0)]),
                noise: 0.08,
                roll: 28
            )
        }
    }

    /// Two short excited mews.
    private static func playVoice(sampleRate: Double) -> [Double] {
        let first = renderVoice(duration: 0.16, sampleRate: sampleRate, seed: 0x5043) { t, _ in
            VoiceFrame(
                f0: contour(t, [(0.00, 720), (0.35, 1_180), (1.00, 620)]),
                f1: 520,
                f2: contour(t, [(0.00, 1_800), (0.4, 2_500), (1.00, 1_500)]),
                f3: 3_200,
                amp: contour(t, [(0.00, 0), (0.08, 1), (1.00, 0)]),
                noise: 0.06,
                roll: 0
            )
        }
        let gap = [Double](repeating: 0, count: Int(0.07 * sampleRate))
        let second = renderVoice(duration: 0.18, sampleRate: sampleRate, seed: 0x5044) { t, _ in
            VoiceFrame(
                f0: contour(t, [(0.00, 780), (0.32, 1_260), (1.00, 500)]),
                f1: 540,
                f2: contour(t, [(0.00, 1_900), (0.35, 2_600), (1.00, 1_400)]),
                f3: 3_300,
                amp: contour(t, [(0.00, 0), (0.07, 1), (1.00, 0)]),
                noise: 0.07,
                roll: 0
            )
        }
        return first + gap + second
    }

    /// Closed-mouth mrrp plus two chew ticks.
    private static func eatVoice(sampleRate: Double) -> [Double] {
        var samples = renderVoice(duration: 0.40, sampleRate: sampleRate, seed: 0xEA5) { t, _ in
            VoiceFrame(
                f0: contour(t, [(0.00, 260), (0.35, 360), (0.7, 300), (1.00, 220)]),
                f1: 380,
                f2: 780,
                f3: 1_800,
                amp: contour(t, [(0.00, 0), (0.08, 0.55), (0.55, 0.4), (1.00, 0)]),
                noise: 0.05,
                roll: 22
            )
        }
        var noise = Noise(state: 0xEA6)
        let ticks = [0.18, 0.30]
        for tick in ticks {
            let start = Int(tick * sampleRate)
            let length = Int(0.014 * sampleRate)
            for offset in 0..<length where start + offset < samples.count {
                let env = 1 - Double(offset) / Double(length)
                let crunch = sin(Double(offset) * 2 * .pi * 170 / sampleRate) * env
                    + noise.next() * env * env * 0.08
                samples[start + offset] += crunch * 0.55
            }
        }
        return samples
    }

    private struct VoiceFrame {
        var f0: Double
        var f1: Double
        var f2: Double
        var f3: Double
        var amp: Double
        var noise: Double
        var roll: Double
    }

    private struct Formant {
        var y1 = 0.0
        var y2 = 0.0

        mutating func tick(
            _ input: Double,
            frequency: Double,
            bandwidth: Double,
            sampleRate: Double
        ) -> Double {
            let radius = exp(-.pi * bandwidth / sampleRate)
            let b = 2 * radius * cos(2 * .pi * frequency / sampleRate)
            let c = -radius * radius
            let y = (1 - radius) * input + b * y1 + c * y2
            y2 = y1
            y1 = y
            return y
        }
    }

    private struct Noise {
        var state: UInt32

        mutating func next() -> Double {
            state = state &* 1_664_525 &+ 1_013_904_223
            let signed = Int32(bitPattern: state)
            return Double(signed) / Double(Int32.max)
        }
    }

    private static func renderVoice(
        duration: Double,
        sampleRate: Double,
        seed: UInt32,
        frame: (Double, Double) -> VoiceFrame
    ) -> [Double] {
        let count = max(1, Int(duration * sampleRate))
        var samples = [Double](repeating: 0, count: count)
        var phase = 0.0
        var f1 = Formant()
        var f2 = Formant()
        var f3 = Formant()
        var noise = Noise(state: seed)
        var previous = 0.0
        var highpass = 0.0

        for index in 0..<count {
            let seconds = Double(index) / sampleRate
            let progress = Double(index) / Double(max(1, count - 1))
            var voice = frame(progress, seconds)
            voice.f0 += noise.next() * 6
            phase += voice.f0 / sampleRate
            if phase >= 1 { phase -= 1.0 }
            let open = phase < 0.62
            let source = glottal(phase) + (open ? noise.next() * voice.noise : noise.next() * voice.noise * 0.15)
            let filtered = 0.50 * f1.tick(source, frequency: voice.f1, bandwidth: 130, sampleRate: sampleRate)
                + 0.40 * f2.tick(source, frequency: voice.f2, bandwidth: 220, sampleRate: sampleRate)
                + 0.12 * f3.tick(source, frequency: voice.f3, bandwidth: 300, sampleRate: sampleRate)
            highpass = filtered - previous + 0.995 * highpass
            previous = filtered
            let roll = voice.roll > 0
                ? 0.62 + 0.38 * (0.5 + 0.5 * sin(seconds * 2 * .pi * voice.roll))
                : 1
            samples[index] = tanh(highpass * 2.4) * voice.amp * roll
        }
        return samples
    }

    private static func glottal(_ phase: Double) -> Double {
        let open = 0.42
        let close = 0.62
        if phase < open {
            return 0.5 * (1 - cos(.pi * phase / open))
        }
        if phase < close {
            return cos(.pi * (phase - open) / (2 * (close - open)))
        }
        return 0
    }

    private static func contour(_ t: Double, _ keys: [(Double, Double)]) -> Double {
        guard let first = keys.first, let last = keys.last else { return 0 }
        if t <= first.0 { return first.1 }
        if t >= last.0 { return last.1 }
        for index in 1..<keys.count where t <= keys[index].0 {
            let start = keys[index - 1]
            let end = keys[index]
            let span = end.0 - start.0
            let unit = span == 0 ? 0 : (t - start.0) / span
            let smooth = unit * unit * (3 - 2 * unit)
            return start.1 + (end.1 - start.1) * smooth
        }
        return last.1
    }

    private static func pcm16(_ samples: [Double], peak: Double = 0.52) -> [Int16] {
        let loudest = samples.map { abs($0) }.max() ?? 0
        let scale = loudest > 0 ? peak * 32_767 / loudest : 0
        return samples.map { Int16(clamping: Int(($0 * scale).rounded())) }
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
