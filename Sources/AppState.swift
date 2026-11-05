import Foundation
import SwiftUI

final class AppState: ObservableObject {
    @Published var media: Media?
    @Published var discordStatus = "Not connected"
    @Published var serverStatus = "Starting…"
    @Published var authError: String?
    @Published var localIP = MediaServer.localIP()

    let clientId = Bundle.main.object(forInfoDictionaryKey: "DiscordClientID") as? String ?? ""
    var sdkAvailable: Bool { DiscordBridge.sdkAvailable }

    private let server = MediaServer()
    private let keeper = BackgroundKeeper()
    private var bridge: DiscordBridge?
    private var timer: Timer?
    private var lastSent: (videoId: String, state: String, start: Int)?

    init() {
        Prefs.register()
        guard !clientId.isEmpty, !clientId.hasPrefix("$") else {
            discordStatus = "Missing DISCORD_CLIENT_ID (set it as a repo variable and rebuild)"
            startServer(); return
        }
        let b = DiscordBridge(clientId: clientId)
        b.onStatus = { [weak self] s in self?.discordStatus = s }
        bridge = b
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.bridge?.runCallbacks() }
        startServer()
        restoreSession()
    }

    private func startServer() {
        server.onStatus = { [weak self] s in DispatchQueue.main.async { self?.serverStatus = s } }
        server.onMedia = { [weak self] m in self?.handle(m) }
        server.healthProvider = { [weak self] in
            ["ok": true, "rpc": self?.discordStatus.lowercased().contains("ready") ?? false,
             "enabled": Prefs.bool("rpcEnabled")]
        }
        server.start()
        keeper.start()
    }

    // MARK: Discord auth (OAuth via Discord, no password ever enters this app)

    func signIn() {
        authError = nil
        bridge?.authorize { [weak self] access, refresh, error in
            guard let self else { return }
            if let access, let refresh {
                Keychain.set(access, for: "access"); Keychain.set(refresh, for: "refresh")
                self.bridge?.connectWithAccessToken(access)
            } else { self.authError = error ?? "Sign-in failed" }
        }
    }

    func signOut() {
        Keychain.delete("access"); Keychain.delete("refresh")
        bridge?.clearActivity()
        discordStatus = "Signed out"
    }

    private func restoreSession() {
        guard let refresh = Keychain.get("refresh") else { return }
        bridge?.refreshWithToken(refresh) { [weak self] access, newRefresh, error in
            guard let self else { return }
            if let access, let newRefresh {
                Keychain.set(access, for: "access"); Keychain.set(newRefresh, for: "refresh")
                self.bridge?.connectWithAccessToken(access)
            } else { self.authError = error }
        }
    }

    // MARK: Presence (port of updatePresence from index.js)

    private func template(_ t: String, _ m: Media) -> String {
        String(t.replacingOccurrences(of: "{title}", with: m.title)
                .replacingOccurrences(of: "{channel}", with: m.channel).prefix(128))
    }

    func handle(_ m: Media) {
        media = m
        pushPresence()
    }

    func pushPresence() {
        guard let m = media, Prefs.bool("rpcEnabled") else { return }
        let playing = m.state == "playing"

        if m.state == "stopped" || (Prefs.bool("clearOnPause") && !playing) {
            bridge?.clearActivity(); lastSent = nil; return
        }

        let start = Int(Date().timeIntervalSince1970) - Int(m.currentTime)
        // Discord rate-limits presence updates, so skip ticks that change nothing visible.
        if let l = lastSent, l.videoId == m.videoId, l.state == m.state, abs(l.start - start) < 3 { return }
        lastSent = (m.videoId, m.state, start)

        var a: [String: Any] = ["type": Prefs.int("activityType")]
        let details = template(Prefs.string("customDetails"), m)
        let state = template(Prefs.string("customState"), m)
        let largeText = template(Prefs.string("customLargeText").isEmpty ? "{title}" : Prefs.string("customLargeText"), m)
        if !details.isEmpty { a["details"] = details }
        if !state.isEmpty { a["state"] = state }
        a["largeImage"] = m.thumbnailUrl.isEmpty ? "youtube_logo" : m.thumbnailUrl
        a["largeText"] = largeText
        if Prefs.bool("showSmallIcon") {
            a["smallImage"] = playing ? "play" : "pause"
            a["smallText"] = playing ? "Playing" : "Paused"
        }
        if playing, Prefs.bool("showProgress"), m.totalTime > 0 {
            a["start"] = start
            a["end"] = start + Int(m.totalTime)
        }
        if Prefs.bool("showButton"), !m.videoId.isEmpty {
            a["buttonLabel"] = "Watch on YouTube"
            a["buttonUrl"] = "https://youtu.be/\(m.videoId)"
        }
        bridge?.setActivity(a)
    }

    func settingsChanged() { lastSent = nil; if Prefs.bool("rpcEnabled") { pushPresence() } else { bridge?.clearActivity() } }
}
