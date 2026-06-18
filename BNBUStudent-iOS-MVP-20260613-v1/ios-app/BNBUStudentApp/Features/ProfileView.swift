import SwiftUI

enum NoticeFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case unread = "未读"
    case deadline = "截止"
    case review = "审核"

    var id: String { rawValue }
}

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedNoticeFilter: NoticeFilter = .all
    @State private var resetDone = false

    var body: some View {
        ZStack {
            GridBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    profileHeader
                    teacherPanel
                    identityPanel
                    notificationPanel
                    syncPanel
                    settingsPanel
                    debugPanel
                }
                .padding(18)
            }
        }
        .accessibilityIdentifier("screen.profile")
        .alert("已重置", isPresented: $resetDone) {
            Button("好") {}
        } message: {
            Text("本地演示数据已恢复到初始 mock 状态。")
        }
    }

    private var profileHeader: some View {
        SwissPanel {
            HStack(alignment: .center, spacing: 14) {
                BrandMark(compact: true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(appState.workspace.student.name)
                        .font(.title2.weight(.black))
                    Text("\(appState.workspace.student.id) · \(appState.workspace.student.college)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(BNBUTheme.muted)
                    Text(appState.workspace.student.email)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BNBUTheme.muted)
                }
                Spacer()
                StatusBadge(text: appState.workspace.student.status, filled: true)
            }
        }
    }

    private var teacherPanel: some View {
        let teachers = appState.workspace.teachers
        if teachers.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(eyebrow: "My Teacher", title: "我的老师")

                ForEach(teachers) { teacher in
                    SwissPanel {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title2)
                                .foregroundStyle(BNBUTheme.blue)
                                .frame(width: 32, height: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(teacher.teacherName)
                                    .font(.headline.weight(.black))
                                Text("教师ID: \(teacher.teacherId)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(BNBUTheme.muted)
                            }
                        }
                    }
                }
            }
        )
    }

    private var identityPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(eyebrow: "Identity", title: "校队 / 社团抵扣状态")

            if appState.workspace.memberships.isEmpty {
                EmptyPlaceholder(
                    title: "暂无认证记录",
                    message: "当前没有校队或社团抵扣认证。认证生效后，只能抵扣其他运动小时，不能替代课程相关小时。"
                )
            } else {
                ForEach(appState.workspace.memberships) { membership in
                    SwissPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(membership.typeTitle) · \(membership.organization)")
                                        .font(.headline.weight(.black))
                                    Text("有效期至 \(membership.validUntil)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(BNBUTheme.muted)
                                }
                                Spacer()
                                StatusBadge(text: membership.status, filled: membership.status == "认证有效")
                            }

                            HStack {
                                StatusBadge(text: membership.offset)
                                Text(membership.comment)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(BNBUTheme.muted)
                            }
                        }
                    }
                }
            }
        }
    }

    private var notificationPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                SectionTitle(eyebrow: "Notifications", title: "通知 / 截止提醒")
                Button {
                    appState.markAllNoticesRead()
                } label: {
                    Label("全部已读", systemImage: "checkmark.circle")
                        .font(.caption.weight(.black))
                        .foregroundStyle(appState.unreadNoticeCount == 0 ? BNBUTheme.muted : BNBUTheme.blue)
                }
                .buttonStyle(.plain)
                .disabled(appState.unreadNoticeCount == 0)
            }

            Picker("通知筛选", selection: $selectedNoticeFilter) {
                ForEach(NoticeFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if filteredNotices.isEmpty {
                EmptyPlaceholder(title: "暂无通知", message: "当前筛选条件下没有通知或截止提醒。")
            }

            ForEach(filteredNotices) { notice in
                NavigationLink {
                    NoticeDetailView(notice: notice)
                } label: {
                    NoticeRow(notice: notice)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filteredNotices: [StudentNotice] {
        appState.workspace.notices.filter { notice in
            switch selectedNoticeFilter {
            case .all:
                return true
            case .unread:
                return notice.isUnread
            case .deadline:
                return notice.category == .deadline
            case .review:
                return notice.category == .review
            }
        }
    }

    private var syncPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(eyebrow: "Sync", title: "本地同步准备")

            SwissPanel {
                VStack(alignment: .leading, spacing: 14) {
                    SettingLine(label: "当前数据源", value: "本地 Mock")
                    SettingLine(label: "API Base", value: appState.apiBaseURLDescription)
                    SettingLine(label: "待同步操作", value: "\(appState.queuedSyncCount)")
                    SettingLine(label: "最近操作", value: appState.latestSyncOperation?.title ?? "暂无")

                    Divider()

                    ForEach(appState.workspace.syncOperations.prefix(4)) { operation in
                        SyncOperationRow(operation: operation)
                    }

                    if appState.workspace.syncOperations.isEmpty {
                        Text("暂无本地操作记录。")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BNBUTheme.muted)
                    }
                }
            }
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(eyebrow: "Settings", title: "设置")

            SwissPanel {
                VStack(alignment: .leading, spacing: 18) {
                    SettingLine(label: "当前学生", value: "\(appState.workspace.student.name) / \(appState.workspace.student.id)")
                    SettingLine(label: "未读通知", value: "\(appState.unreadNoticeCount)")
                    SettingLine(label: "打卡草稿", value: appState.draft == nil ? "无" : "有未提交草稿")
                    SettingLine(label: "版本", value: "0.1.0 MVP")
                    SettingLine(label: "数据源", value: "本地 Mock + UserDefaults")

                    PrimaryActionButton(title: "退出登录", systemImage: "rectangle.portrait.and.arrow.right") {
                        appState.logout()
                    }

                    Button {
                        appState.resetLocalDemoData()
                        resetDone = true
                    } label: {
                        Label("重置本地演示数据", systemImage: "arrow.counterclockwise")
                            .font(.headline.weight(.black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(BNBUTheme.ink)
                            .background(BNBUTheme.surface)
                            .overlay(Rectangle().stroke(BNBUTheme.line, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(eyebrow: "Debug", title: "本地调试")

            SwissPanel {
                VStack(alignment: .leading, spacing: 14) {
                    SettingLine(label: "活跃任务", value: "\(appState.activeTasks.count)")
                    SettingLine(label: "本地记录", value: "\(appState.workspace.records.count)")
                    SettingLine(label: "待审核记录", value: "\(appState.pendingRecordCount)")
                    SettingLine(label: "需补材料", value: "\(appState.supplementRecordCount)")
                    SettingLine(label: "待同步操作", value: "\(appState.queuedSyncCount)")
                    SettingLine(label: "草稿凭证", value: appState.draft.map { "\($0.proofAttachments.count)" } ?? "0")
                    SettingLine(label: "数据完整性", value: appState.dataIntegritySummary)
                    SettingLine(label: "工作台存储", value: appState.storeHealth.workspaceReadStatus.rawValue)
                    SettingLine(label: "草稿存储", value: appState.storeHealth.draftReadStatus.rawValue)
                    SettingLine(label: "最近写入", value: appState.storeHealth.lastWriteStatus.rawValue)
                    SettingLine(label: "Bundle ID", value: "edu.bnbu.student.mvp")

                    Text(appState.storeHealth.lastEvent)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BNBUTheme.muted)
                        .lineSpacing(2)
                }
            }
            .accessibilityIdentifier("panel.profile.debug")
        }
    }
}

private struct SyncOperationRow: View {
    let operation: SyncOperation

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: operation.type.symbolName)
                .font(.headline.weight(.black))
                .foregroundStyle(BNBUTheme.blue)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(operation.title)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(BNBUTheme.ink)
                    Spacer()
                    StatusBadge(text: operation.status.rawValue, filled: operation.status == .queued)
                }

                Text(operation.detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BNBUTheme.muted)
                    .lineSpacing(2)

                Text(operation.createdAt)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(BNBUTheme.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SettingLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline.weight(.black))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BNBUTheme.muted)
                .multilineTextAlignment(.trailing)
        }
    }
}
