import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard = "首页"
    case courses = "课程"
    case checkin = "打卡"
    case grades = "成绩"
    case profile = "我的"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard: return "rectangle.grid.2x2"
        case .courses: return "book.closed"
        case .checkin: return "plus.app"
        case .grades: return "chart.bar.xaxis"
        case .profile: return "person.crop.circle"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .dashboard: return "tab.dashboard"
        case .courses: return "tab.courses"
        case .checkin: return "tab.checkin"
        case .grades: return "tab.grades"
        case .profile: return "tab.profile"
        }
    }
}

struct AppRootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    tabContent(for: tab)
                        .navigationTitle(tab.rawValue)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem {
                    Label(tab.rawValue, systemImage: tab.systemImage)
                        .accessibilityIdentifier(tab.accessibilityIdentifier)
                }
                .accessibilityIdentifier(tab.accessibilityIdentifier)
                .badge(badgeCount(for: tab))
                .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .dashboard:
            DashboardView(
                openCheckIn: { selectedTab = .checkin },
                openGrades: { selectedTab = .grades },
                openProfile: { selectedTab = .profile }
            )
        case .courses:
            CoursesView()
        case .checkin:
            CheckInView()
        case .grades:
            GradesView()
        case .profile:
            ProfileView()
        }
    }

    private func badgeCount(for tab: AppTab) -> Int {
        switch tab {
        case .dashboard, .courses, .grades:
            return 0
        case .checkin:
            return appState.actionableRecordCount
        case .profile:
            return appState.unreadNoticeCount
        }
    }
}
