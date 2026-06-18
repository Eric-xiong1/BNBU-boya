import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    var openCheckIn: () -> Void = {}
    var openGrades: () -> Void = {}
    var openProfile: () -> Void = {}

    var body: some View {
        ZStack {
            GridBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    progressPanel
                    metricsGrid
                    riskPanel
                    actionPanel
                    focusPlan
                    nextTasks
                    notices
                }
                .padding(18)
            }
        }
        .accessibilityIdentifier("screen.dashboard")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            BrandMark(compact: true)
            VStack(alignment: .leading, spacing: 5) {
                Text("你好，\(appState.workspace.student.name)")
                    .font(.title.weight(.black))
                    .foregroundStyle(BNBUTheme.ink)
                Text("\(appState.workspace.student.college) · \(appState.workspace.student.id)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BNBUTheme.muted)
            }
            Spacer()
            StatusBadge(text: appState.workspace.progress.status, filled: true)
        }
    }

    private var progressPanel: some View {
        SwissPanel {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle(eyebrow: "Sports Credit", title: "体育学时进度")

                HStack(alignment: .firstTextBaseline) {
                    Text(appState.totalCompleted.hourText)
                        .font(.system(size: 46, weight: .black))
                    Text("/ \(appState.hourRule.total.hourText)")
                        .font(.title3.weight(.black))
                        .foregroundStyle(BNBUTheme.muted)
                    Spacer()
                    Text("\(Int(appState.completionRatio * 100))%")
                        .font(.title2.weight(.black))
                        .foregroundStyle(BNBUTheme.blue)
                }

                HourProgressBar(value: appState.totalCompleted, total: appState.hourRule.total)

                VStack(spacing: 14) {
                    ProgressLine(
                        title: "课程相关",
                        value: appState.workspace.progress.course,
                        total: appState.hourRule.courseRequired,
                        detail: "还差 \(appState.courseRemaining.hourText)"
                    )
                    ProgressLine(
                        title: "其他运动",
                        value: appState.workspace.progress.general,
                        total: appState.hourRule.generalRequired,
                        detail: appState.generalRemaining == 0 ? "已完成" : "还差 \(appState.generalRemaining.hourText)"
                    )
                }
            }
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCell(label: "Total", value: "20h", footnote: "本学期总要求")
            MetricCell(label: "Course", value: "10h", footnote: "老师任务与课程相关")
            MetricCell(label: "General", value: "10h", footnote: "自主运动 / 组织抵扣")
            MetricCell(label: "Pending", value: "\(pendingCount)", footnote: "当前待审核记录")
        }
    }

    private var riskPanel: some View {
        SwissPanel {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: hasHourRisk ? "exclamationmark.triangle" : "checkmark.seal")
                    .font(.title2.weight(.black))
                    .foregroundStyle(hasHourRisk ? BNBUTheme.blue : BNBUTheme.ink)
                VStack(alignment: .leading, spacing: 8) {
                    Text(hasHourRisk ? "当前风险提示" : "当前状态稳定")
                        .font(.headline.weight(.black))
                    Text(riskText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BNBUTheme.muted)
                        .lineSpacing(3)
                }
            }
        }
    }

    private var nextTasks: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(eyebrow: "Deadline", title: "近期任务")
            if appState.activeTasks.isEmpty {
                EmptyPlaceholder(title: "暂无近期任务", message: "当前没有进行中的打卡任务；新任务发布后会在这里显示。")
            } else {
                ForEach(appState.activeTasks.prefix(2)) { task in
                    TaskRow(task: task)
                }
            }
        }
    }

    private var actionPanel: some View {
        SwissPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("待处理", systemImage: appState.supplementRecordCount > 0 ? "exclamationmark.circle.fill" : "checkmark.circle")
                        .font(.headline.weight(.black))
                        .foregroundStyle(BNBUTheme.ink)
                    Spacer()
                    StatusBadge(text: "\(appState.actionableRecordCount + appState.unreadNoticeCount)")
                }

                HStack(spacing: 10) {
                    ActionMiniMetric(label: "需补材料", value: "\(appState.supplementRecordCount)")
                    ActionMiniMetric(label: "待审核", value: "\(appState.pendingRecordCount)")
                    ActionMiniMetric(label: "未读通知", value: "\(appState.unreadNoticeCount)")
                }

                Text(actionText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BNBUTheme.muted)
                    .lineSpacing(3)

                HStack(spacing: 10) {
                    DashboardShortcutButton(title: "处理打卡", systemImage: "plus.app", action: openCheckIn)
                    DashboardShortcutButton(title: "看通知", systemImage: "bell", action: openProfile)
                    DashboardShortcutButton(title: "看成绩", systemImage: "chart.bar.xaxis", action: openGrades)
                }
            }
        }
    }

    private var focusPlan: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(eyebrow: "Plan", title: "本周行动计划")

            SwissPanel {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(focusPlanItems) { item in
                        FocusPlanRow(item: item)
                    }
                }
            }
        }
    }

    private var notices: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(eyebrow: "Notice", title: "通知 / 截止提醒")
            if appState.workspace.notices.isEmpty {
                EmptyPlaceholder(title: "暂无通知", message: "当前没有截止提醒或审核反馈。")
            } else {
                ForEach(appState.workspace.notices.prefix(2)) { notice in
                    NoticeRow(notice: notice)
                }
            }
        }
    }

    private var focusPlanItems: [FocusPlanItem] {
        var items: [FocusPlanItem] = []
        if appState.courseRemaining > 0 {
            items.append(
                FocusPlanItem(
                    title: "优先补齐课程相关 \(appState.courseRemaining.hourText)",
                    detail: appState.activeTasks.isEmpty ? "课程相关不能被组织抵扣替代；当前暂无可提交任务，请等待老师发布。" : "课程相关不能被组织抵扣替代，建议先完成 GEPE101 相关任务。",
                    systemImage: "target",
                    status: "高优先级"
                )
            )
        }
        if appState.supplementRecordCount > 0 {
            items.append(
                FocusPlanItem(
                    title: "处理 \(appState.supplementRecordCount) 条补材料记录",
                    detail: "按老师反馈补充图片或视频后，会重新进入待审核队列。",
                    systemImage: "arrow.up.doc.fill",
                    status: "需动作"
                )
            )
        }
        if appState.pendingRecordCount > 0 {
            items.append(
                FocusPlanItem(
                    title: "等待 \(appState.pendingRecordCount) 条审核结果",
                    detail: "待审核记录暂不计入有效小时，请留意审核反馈。",
                    systemImage: "hourglass",
                    status: "跟进"
                )
            )
        }
        if appState.unreadNoticeCount > 0 {
            items.append(
                FocusPlanItem(
                    title: "查看 \(appState.unreadNoticeCount) 条未读提醒",
                    detail: "优先确认截止时间和补材料通知。",
                    systemImage: "bell.badge",
                    status: "提醒"
                )
            )
        }
        if items.isEmpty {
            items.append(
                FocusPlanItem(
                    title: "当前没有阻塞事项",
                    detail: "保持运动记录连续性，关注下一次课程任务发布。",
                    systemImage: "checkmark.seal",
                    status: "稳定"
                )
            )
        }
        return Array(items.prefix(4))
    }

    private var pendingCount: Int {
        appState.workspace.records.filter { $0.status == .pending || $0.status == .supplement }.count
    }

    private var hasHourRisk: Bool {
        appState.courseRemaining > 0 || appState.generalRemaining > 0
    }

    private var riskText: String {
        if appState.courseRemaining > 0 && appState.generalRemaining > 0 {
            return "课程相关还差 \(appState.courseRemaining.hourText)，其他运动还差 \(appState.generalRemaining.hourText)。请优先关注课程任务和可计入的自主运动。"
        }
        if appState.courseRemaining > 0 {
            return "课程相关还差 \(appState.courseRemaining.hourText)。其他运动已由组织认证完成，但不能替代课程相关学时。"
        }
        if appState.generalRemaining > 0 {
            return "其他运动还差 \(appState.generalRemaining.hourText)。可通过自主运动打卡或有效组织认证完成。"
        }
        return "课程相关与其他运动均达到本学期要求，请继续关注审核反馈和成绩缺失项。"
    }

    private var actionText: String {
        if appState.supplementRecordCount > 0 {
            return "有 \(appState.supplementRecordCount) 条记录需要补充材料，请进入打卡记录处理。"
        }
        if appState.pendingRecordCount > 0 {
            return "已有记录进入审核队列，审核通过后才会计入有效小时。"
        }
        return "暂无需要补交的材料，继续关注截止提醒与课程任务。"
    }
}

private struct FocusPlanItem: Identifiable, Hashable {
    var id: String { title }
    let title: String
    let detail: String
    let systemImage: String
    let status: String
}

private struct FocusPlanRow: View {
    let item: FocusPlanItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.headline.weight(.black))
                .foregroundStyle(BNBUTheme.blue)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(BNBUTheme.ink)
                    Spacer()
                    StatusBadge(text: item.status)
                }
                Text(item.detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BNBUTheme.muted)
                    .lineSpacing(2)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct ActionMiniMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption2.weight(.black))
                .foregroundStyle(BNBUTheme.muted)
            Text(value)
                .font(.title3.weight(.black))
                .foregroundStyle(BNBUTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(BNBUTheme.blueSoft)
        .overlay(Rectangle().stroke(BNBUTheme.line, lineWidth: 1))
    }
}

private struct DashboardShortcutButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(BNBUTheme.surface)
                .background(BNBUTheme.ink)
        }
        .buttonStyle(.plain)
    }
}

private struct ProgressLine: View {
    let title: String
    let value: Double
    let total: Double
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.black))
                Spacer()
                Text("\(value.hourText) / \(total.hourText)")
                    .font(.subheadline.weight(.black))
                StatusBadge(text: detail)
            }
            HourProgressBar(value: value, total: total)
        }
    }
}

struct TaskRow: View {
    let task: CourseTask

    var body: some View {
        SwissPanel {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: task.creditType.symbolName)
                    .font(.title2.weight(.black))
                    .frame(width: 32)
                    .foregroundStyle(BNBUTheme.blue)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(task.title)
                            .font(.headline.weight(.black))
                        Spacer()
                        StatusBadge(text: task.creditType.rawValue)
                    }
                    Text("截止：\(task.deadline)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(BNBUTheme.ink)
                    Text("证明：\(task.proof)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BNBUTheme.muted)
                }
            }
        }
    }
}

struct NoticeRow: View {
    let notice: StudentNotice

    var body: some View {
        SwissPanel {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(notice.category.rawValue, systemImage: notice.category.symbolName)
                        .font(.caption.weight(.black))
                        .foregroundStyle(BNBUTheme.blue)
                    Spacer()
                    if notice.isUnread {
                        Circle()
                            .fill(BNBUTheme.blue)
                            .frame(width: 9, height: 9)
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(notice.title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(BNBUTheme.ink)
                    Spacer()
                    StatusBadge(text: notice.time)
                }
                Text(notice.message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BNBUTheme.muted)
            }
        }
    }
}
