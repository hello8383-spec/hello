import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @AppStorage("rpcEnabled") private var rpcEnabled = true
    @AppStorage("activityType") private var activityType = 3
    @AppStorage("showProgress") private var showProgress = true
    @AppStorage("showSmallIcon") private var showSmallIcon = true
    @AppStorage("clearOnPause") private var clearOnPause = false
    @AppStorage("showButton") private var showButton = true
    @AppStorage("customDetails") private var customDetails = "{title}"
    @AppStorage("customState") private var customState = "{channel}"
    @AppStorage("customLargeText") private var customLargeText = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Status") {
                    row("Discord", state.discordStatus)
                    row("Server", state.serverStatus)
                    row("Address", "http://\(state.localIP):\(MediaServer.port)")
                    row("Now playing", state.media.map { "\($0.state == "playing" ? "▶" : "⏸") \($0.title)" } ?? "Nothing playing")
                    if !state.sdkAvailable {
                        Text("Discord Social SDK is not linked in this build. See README.").font(.footnote).foregroundColor(.orange)
                    }
                    if let e = state.authError { Text(e).font(.footnote).foregroundColor(.red) }
                    Button("Sign in with Discord") { state.signIn() }
                    Button("Sign out", role: .destructive) { state.signOut() }
                }
                Section("Display") {
                    Toggle("Display in profile", isOn: $rpcEnabled)
                    Picker("Activity type", selection: $activityType) {
                        Text("Playing").tag(0); Text("Listening").tag(2); Text("Watching").tag(3); Text("Competing").tag(5)
                    }
                    Toggle("Show progress bar", isOn: $showProgress)
                    Toggle("Show play/pause icon", isOn: $showSmallIcon)
                    Toggle("Clear when paused", isOn: $clearOnPause)
                    Toggle("\"Watch on YouTube\" button", isOn: $showButton)
                }
                Section(header: Text("Text"), footer: Text("Placeholders: {title}, {channel}")) {
                    TextField("Details", text: $customDetails)
                    TextField("State", text: $customState)
                    TextField("Large image text", text: $customLargeText)
                }
            }
            .navigationTitle("YouTube Plus RPC")
            .onChange(of: rpcEnabled) { _ in state.settingsChanged() }
            .onChange(of: activityType) { _ in state.settingsChanged() }
            .onChange(of: showProgress) { _ in state.settingsChanged() }
            .onChange(of: showSmallIcon) { _ in state.settingsChanged() }
            .onChange(of: clearOnPause) { _ in state.settingsChanged() }
            .onChange(of: showButton) { _ in state.settingsChanged() }
            .onChange(of: customDetails) { _ in state.settingsChanged() }
            .onChange(of: customState) { _ in state.settingsChanged() }
            .onChange(of: customLargeText) { _ in state.settingsChanged() }
        }
        .navigationViewStyle(.stack)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k); Spacer(); Text(v).foregroundColor(.secondary).multilineTextAlignment(.trailing) }
    }
}
