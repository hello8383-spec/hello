import SwiftUI

@main
struct YTPlusRPCApp: App {
    @StateObject private var state = AppState()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(state) }
    }
}
