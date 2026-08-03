import AVFoundation
import Foundation

enum PokerSoundEffect: CaseIterable {
    case deal
    case win
    case fold
    case chip

    fileprivate var frequency: Double {
        switch self {
        case .deal: return 220
        case .win: return 523.25
        case .fold: return 140
        case .chip: return 330
        }
    }

    fileprivate var usesSineWave: Bool {
        self == .win
    }

    fileprivate var duration: Double {
        self == .win ? 0.24 : 0.12
    }
}

final class PokerSoundPlayer {
    static let shared = PokerSoundPlayer()

    private var players: [PokerSoundEffect: AVAudioPlayer] = [:]

    private init() {
        for effect in PokerSoundEffect.allCases {
            guard let player = try? AVAudioPlayer(data: Self.waveData(for: effect)) else {
                continue
            }
            player.volume = 0.7
            player.prepareToPlay()
            players[effect] = player
        }
    }

    func play(_ effect: PokerSoundEffect) {
        guard let player = players[effect] else { return }
        if player.isPlaying {
            player.stop()
        }
        player.currentTime = 0
        player.play()
    }

    static func waveData(for effect: PokerSoundEffect) -> Data {
        let sampleRate: Double = 44_100
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let bytesPerSample = Int(bitsPerSample / 8)
        let frames = Int(sampleRate * effect.duration)
        let dataSize = frames * Int(channels) * bytesPerSample

        var output = Data()
        func appendUInt32(_ value: UInt32) {
            output.append(withUnsafeBytes(of: value.littleEndian) { Data($0) })
        }
        func appendUInt16(_ value: UInt16) {
            output.append(withUnsafeBytes(of: value.littleEndian) { Data($0) })
        }

        output.append(contentsOf: "RIFF".utf8)
        appendUInt32(UInt32(36 + dataSize))
        output.append(contentsOf: "WAVE".utf8)
        output.append(contentsOf: "fmt ".utf8)
        appendUInt32(16)
        appendUInt16(1)
        appendUInt16(channels)
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(sampleRate) * UInt32(channels) * UInt32(bytesPerSample))
        appendUInt16(channels * UInt16(bytesPerSample))
        appendUInt16(bitsPerSample)
        output.append(contentsOf: "data".utf8)
        appendUInt32(UInt32(dataSize))

        let angularFrequency = 2 * Double.pi * effect.frequency
        for frame in 0..<frames {
            let time = Double(frame) / sampleRate
            let envelope = 0.9 * exp(-time / (effect.duration * 0.4))
            let rawSample: Double
            if effect.usesSineWave {
                rawSample = sin(angularFrequency * time)
            } else {
                let phase = (effect.frequency * time).truncatingRemainder(dividingBy: 1)
                rawSample = 4 * abs(phase - 0.5) - 1
            }
            let sample = max(-1, min(1, rawSample * envelope))
            let pcmValue = Int16(sample * 32_767)
            output.append(withUnsafeBytes(of: pcmValue.littleEndian) { Data($0) })
        }

        return output
    }
}
