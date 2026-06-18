import SwiftUI

@main
struct BNBUStudentApp: App {
    @StateObject private var appState: AppState

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing-reset") {
            AppLocalStore().clearAll()
        }
        let repository: StudentRepository = arguments.contains("-ui-testing-empty-state") ? EmptyStudentRepository() : MockStudentRepository()
        _appState = StateObject(wrappedValue: AppState(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAuthenticated {
                    AppRootView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(appState)
            .tint(BNBUTheme.blue)
        }
    }
}
