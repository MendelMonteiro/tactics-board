import SwiftUI

@main
struct TacticsBoardApp: App {
    @StateObject private var library = LibraryModel()

    var body: some Scene {
        WindowGroup {
            SequenceListView()
                .environmentObject(library)
        }
    }
}
