import SwiftUI

struct CourseDetailView: View {
    @EnvironmentObject private var appState: AppState
    let course: Course

    var body: some View {
        ZStack {
            GridBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(eyebrow: course.semester, title: course.displayTitle)

                    SwissPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            DetailFactRow(label: "课程名称", value: course.name)
                            DetailFactRow(label: "Section", value: "Section \(course.section)")
                            DetailFactRow(label: "任课老师", value: course.teacher)
                            DetailFactRow(label: "下一截止", value: course.deadline)
                        }
                    }

                    SwissPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("我的课程相关进度")
                                .font(.headline.weight(.black))
                            HourProgressBar(value: appState.workspace.progress.course, total: appState.hourRule.courseRequired)
                            DetailFactRow(label: "已完成", value: appState.workspace.progress.course.hourText)
                            DetailFactRow(label: "仍缺口", value: appState.courseRemaining.hourText)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(eyebrow: "Class Tasks", title: "本教学班任务")
                        ForEach(appState.tasks(for: course)) { task in
                            NavigationLink {
                                TaskDetailView(task: task, course: course)
                            } label: {
                                TaskRow(task: task)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(eyebrow: "Trace", title: "相关记录")
                        ForEach(appState.records(for: course)) { record in
                            NavigationLink {
                                RecordDetailView(record: record)
                            } label: {
                                RecordCard(record: record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("课程详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TaskDetailView: View {
    let task: CourseTask
    let course: Course?

    var body: some View {
        ZStack {
            GridBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(eyebrow: task.creditType.rawValue, title: task.title)

                    SwissPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            DetailFactRow(label: "状态", value: task.status.rawValue)
                            DetailFactRow(label: "可获得小时", value: task.hours.hourText)
                            DetailFactRow(label: "截止时间", value: task.deadline)
                            DetailFactRow(label: "更新时间", value: task.updatedAt)
                            if let course {
                                DetailFactRow(label: "教学班", value: course.displayTitle)
                            }
                        }
                    }

                    SwissPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("证明要求")
                                .font(.headline.weight(.black))
                            Text(task.proof)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BNBUTheme.muted)
                                .lineSpacing(3)
                        }
                    }

                    EmptyPlaceholder(
                        title: task.creditType == .courseRelated ? "计入课程相关学时" : "计入其他运动学时",
                        message: task.creditType == .courseRelated ? "这类任务不能被校队或社团认证完全替代。" : "其他运动不能替代课程相关学时，B 类最多计 10 小时。"
                    )
                }
                .padding(18)
            }
        }
        .navigationTitle("任务详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RecordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let record: CheckInRecord
    var supplementAction: ((CheckInRecord) -> Void)?

    var body: some View {
        ZStack {
            GridBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(eyebrow: record.creditType.rawValue, title: record.taskTitle)

                    SwissPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                StatusBadge(text: record.status.rawValue, filled: record.status == .approved || record.status == .offset)
                                Spacer()
                                Text(record.hours.hourText)
                                    .font(.title2.weight(.black))
                            }
                            DetailFactRow(label: "提交时间", value: record.submittedAt)
                            DetailFactRow(label: "图片凭证", value: "\(record.proofPhotoCount)")
                            DetailFactRow(label: "视频凭证", value: "\(record.proofVideoCount)")
                            DetailFactRow(label: "凭证摘要", value: record.proofSummary)
                        }
                    }

                    ReviewTimelinePanel(record: record)

                    if canSupplement, let supplementAction {
                        DisabledAwareButton(
                            title: record.status == .supplement ? "补交材料" : "重新提交材料",
                            systemImage: "arrow.up.doc.fill",
                            isDisabled: false
                        ) {
                            dismiss()
                            supplementAction(record)
                        }
                    }

                    SwissPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("凭证文件")
                                .font(.headline.weight(.black))

                            if record.proofFiles.isEmpty {
                                Text("该记录暂无可预览凭证文件。")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(BNBUTheme.muted)
                            } else {
                                ForEach(record.proofFiles) { proof in
                                    HStack(spacing: 10) {
                                        Image(systemName: proof.type == .video ? "video.fill" : "photo.fill")
                                            .font(.headline.weight(.black))
                                            .foregroundStyle(BNBUTheme.blue)
                                            .frame(width: 26, height: 26)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(proof.fileName)
                                                .font(.subheadline.weight(.black))
                                                .foregroundStyle(BNBUTheme.ink)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            Text("\(proof.type.rawValue) · \(proof.displaySize) · \(proof.source)")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(BNBUTheme.muted)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                    }

                    SwissPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("老师反馈")
                                .font(.headline.weight(.black))
                            Text(record.teacherFeedback)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BNBUTheme.muted)
                                .lineSpacing(3)
                        }
                    }

                    SwissPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("学生说明")
                                .font(.headline.weight(.black))
                            Text(record.note)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BNBUTheme.muted)
                                .lineSpacing(3)
                        }
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("记录详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canSupplement: Bool {
        record.status == .supplement || record.status == .rejected
    }
}

private struct ReviewTimelinePanel: View {
    let record: CheckInRecord

    var body: some View {
        SwissPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("审核进度")
                        .font(.headline.weight(.black))
                    Spacer()
                    StatusBadge(text: record.status.rawValue, filled: record.status == .pending)
                }

                ReviewTimelineStep(
                    title: "学生提交",
                    detail: record.submittedAt,
                    systemImage: "paperplane.fill",
                    isActive: true
                )
                ReviewTimelineStep(
                    title: reviewStepTitle,
                    detail: reviewStepDetail,
                    systemImage: reviewStepIcon,
                    isActive: record.status != .pending
                )
                ReviewTimelineStep(
                    title: finalStepTitle,
                    detail: finalStepDetail,
                    systemImage: finalStepIcon,
                    isActive: isFinalState
                )
            }
        }
    }

    private var reviewStepTitle: String {
        record.status == .pending ? "老师审核中" : "老师已反馈"
    }

    private var reviewStepDetail: String {
        record.status == .pending ? "审核通过后才会计入有效小时。" : record.teacherFeedback
    }

    private var reviewStepIcon: String {
        record.status == .pending ? "hourglass" : "text.bubble"
    }

    private var finalStepTitle: String {
        switch record.status {
        case .pending:
            return "等待结果"
        case .approved:
            return "已计入有效学时"
        case .rejected:
            return "未通过"
        case .supplement:
            return "等待补充材料"
        case .offset:
            return "系统抵扣完成"
        }
    }

    private var finalStepDetail: String {
        switch record.status {
        case .pending:
            return "暂无最终结果。"
        case .approved:
            return "\(record.hours.hourText) 已计入对应学时。"
        case .rejected:
            return "该记录不会计入有效小时，可按反馈重新提交材料。"
        case .supplement:
            return "补齐凭证后会重新进入待审核。"
        case .offset:
            return "由校队或社团认证自动抵扣。"
        }
    }

    private var finalStepIcon: String {
        switch record.status {
        case .pending:
            return "clock"
        case .approved, .offset:
            return "checkmark.seal.fill"
        case .rejected:
            return "xmark.seal"
        case .supplement:
            return "arrow.up.doc"
        }
    }

    private var isFinalState: Bool {
        record.status != .pending
    }
}

private struct ReviewTimelineStep: View {
    let title: String
    let detail: String
    let systemImage: String
    let isActive: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline.weight(.black))
                .foregroundStyle(isActive ? BNBUTheme.blue : BNBUTheme.muted)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(BNBUTheme.ink)
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BNBUTheme.muted)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(.vertical, 3)
    }
}

struct NoticeDetailView: View {
    @EnvironmentObject private var appState: AppState
    let notice: StudentNotice

    private var currentNotice: StudentNotice {
        appState.workspace.notices.first { $0.id == notice.id } ?? notice
    }

    var body: some View {
        ZStack {
            GridBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(eyebrow: currentNotice.time, title: currentNotice.title)

                    SwissPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label(currentNotice.category.rawValue, systemImage: currentNotice.category.symbolName)
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(BNBUTheme.blue)
                                Spacer()
                                StatusBadge(text: currentNotice.isUnread ? "未读" : "已读", filled: currentNotice.isUnread)
                            }

                            Text(currentNotice.message)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(BNBUTheme.ink)
                                .lineSpacing(5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    DisabledAwareButton(title: "标记为已读", systemImage: "checkmark.circle", isDisabled: !currentNotice.isUnread) {
                        appState.markNoticeRead(id: currentNotice.id)
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("通知详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RecordCard: View {
    let record: CheckInRecord

    var body: some View {
        SwissPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(record.taskTitle)
                            .font(.headline.weight(.black))
                        Text(record.submittedAt)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BNBUTheme.muted)
                    }
                    Spacer()
                    StatusBadge(text: record.status.rawValue, filled: record.status == .approved || record.status == .offset)
                }

                HStack {
                    StatusBadge(text: record.creditType.rawValue)
                    Text(record.hours.hourText)
                        .font(.headline.weight(.black))
                    Spacer()
                }

                Text("凭证：\(record.proofSummary)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BNBUTheme.muted)

                Text("老师反馈：\(record.teacherFeedback)")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(BNBUTheme.ink)
                    .lineSpacing(3)
            }
        }
    }
}
