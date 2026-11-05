import AVFoundation

/// Plays inaudible audio (mixed with other apps) so iOS keeps the app, and the port-5001 server, alive.
final class BackgroundKeeper {
    private var player: AVAudioPlayer?

    func start() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, options: [.mixWithOthers])
        try? s.setActive(true)
        player = try? AVAudioPlayer(data: Self.silentWAV())
        player?.numberOfLoops = -1
        player?.volume = 0
        player?.play()
    }

    private static func silentWAV() -> Data {
        let rate: UInt32 = 8000, samples = Int(rate), bytes = samples * 2
        var d = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
        d.append(Data("RIFF".utf8)); u32(UInt32(36 + bytes)); d.append(Data("WAVEfmt ".utf8))
        u32(16); u16(1); u16(1); u32(rate); u32(rate * 2); u16(2); u16(16)
        d.append(Data("data".utf8)); u32(UInt32(bytes)); d.append(Data(count: bytes))
        return d
    }
}
