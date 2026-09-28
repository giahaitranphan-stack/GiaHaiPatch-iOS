import SwiftUI

@main
struct GiaHaiPatchApp: App {
    @StateObject private var store = PatchStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
