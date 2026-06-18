import SwiftUI

enum CheckInSegment: String, CaseIterable, Identifiable {
    case tasks = "任务"
    case submit = "提交"
    case records = "记录"

    var id: String { rawValue }
}

enum TaskScopeFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case course = "课程相关"
    case general = "其他运动"

    var id: String { rawValue }
}

enum RecordScopeFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case pending = "待审核"
    case approved = "已通过"
    case rejected = "被驳回"
    case supplement = "需补材料"
    case offset = "系统抵扣"

    var id: String { rawValue }
}

struct CheckInView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedSegment: CheckInSegment = .tasks
    @State private var selectedTaskFilter: TaskScopeFilter = .all
    @State private var selectedRecordFilter: RecordScopeFilter = .all
    @State private var selectedTaskId = "t1"
    @State private var hours = 1.0
    @State private var note = ""
    @State private var proofAttachments: [ProofAttachment] = []
    @State private var submitted = false
    @State private var draftSaved = false
    @State private var draftRestored = false
    @State private var supplementingRecord: CheckInRecord?
    @State private var confirmSubmit = false

    var body: some View {
        ZStack {
            GridBackground()

            VStack(spacing: 0) {
                Picker("打卡", selection: $selectedSegment) {
                    ForEach(CheckInSegment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top], 18)
                .padding(.bottom, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        content
                    }
                    .padding(18)
                }
            }
        }
        .accessibilityIdentifier("screen.checkin")
        .alert("提交成功", isPresented: $submitted) {
            Button("查看记录") {
                selectedSegment = .records
            }
        } message: {
            Text("本次提交已进入待审核状态。")
        }
        .confirmationDialog(
            supplementingRecord == nil ? "确认提交打卡" : "确认提交补充材料",
            isPresented: $confirmSubmit,
            titleVisibility: .visible
        ) {
            Button(supplementingRecord == nil ? "提交并进入待审核" : "提交补充材料") {
                performSubmit()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(submitConfirmationMessage)
        }
        .onAppear {
            restoreDraftIfNeeded()
            ensureValidTaskSelection()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSegment {
        case .tasks:
            taskList
        case .submit:
            submitForm
        case .records:
            recordList
        }
    }

    private var taskList: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(eyebrow: "Check-In Tasks", title: "打卡任务列表")

            Text("课程相关任务由老师发布；其他运动任务用于自主运动或组织活动。审核通过后才计入有效学时。")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BNBUTheme.muted)
                .lineSpacing(3)

            Picker("任务类型", selection: $selectedTaskFilter) {
                ForEach(TaskScopeFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if filteredTasks.isEmpty {
                EmptyPlaceholder(
                    title: selectedTaskFilter == .all ? "暂无打卡任务" : "暂无\(selectedTaskFilter.rawValue)任务",
                    message: "当前没有可展示的任务；若老师后续发布新任务，会出现在这里。"
                )
            } else {
                ForEach(filteredTasks) { task in
                    TaskActionCard(task: task, course: courseForTask(task)) {
                        startSubmission(for: task)
                    }
                }
            }
        }
    }

    private var submitForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(eyebrow: "Submit", title: "提交打卡")

            if let localRecoveryMessage {
                LocalRecoveryBanner(message: localRecoveryMessage)
            }

            if let supplementingRecord {
                SupplementBanner(record: supplementingRecord) {
                    cancelSupplement()
                }
            } else if let draft = appState.draft {
                DraftBanner(draft: draft) {
                    restoreDraft(draft)
                } clearAction: {
                    clearDraftAndForm()
                }
            }

            if supplementingRecord == nil && appState.activeTasks.isEmpty {
                EmptyPlaceholder(
                    title: "暂无可提交任务",
                    message: "当前没有进行中的打卡任务。已关闭任务只能查看，不能提交；请等待老师发布新任务或查看已有记录。"
                )
            } else {
                SwissPanel {
                    VStack(alignment: .leading, spacing: 18) {
                        if let supplementingRecord {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("补交记录")
                                    .font(.headline.weight(.black))
                                DetailFactRow(label: "任务", value: supplementingRecord.taskTitle)
                                DetailFactRow(label: "原状态", value: supplementingRecord.status.rawValue)
                                DetailFactRow(label: "老师反馈", value: supplementingRecord.teacherFeedback)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("选择任务")
                                    .font(.headline.weight(.black))
                                Picker("选择任务", selection: $selectedTaskId) {
                                    ForEach(appState.activeTasks) { task in
                                        Text(task.title).tag(task.id)
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: selectedTaskId) { _, _ in
                                    clampHoursForSelectedTask()
                                    draftSaved = false
                                }
                            }
                        }

                        if let selectedTask, supplementingRecord == nil {
                            HStack {
                                StatusBadge(text: selectedTask.creditType.rawValue, filled: true)
                                StatusBadge(text: "最多 \(selectedTaskHourLimit.hourText)")
                                Spacer()
                            }

                            Text(selectedTask.creditType == .courseRelated ? "本次记录将计入课程相关体育学时。" : "本次记录将计入其他运动学时，不能替代课程相关学时。")
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(BNBUTheme.ink)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("运动时长")
                                    .font(.headline.weight(.black))
                                Spacer()
                                Text(hours.hourText)
                                    .font(.title3.weight(.black))
                                    .foregroundStyle(BNBUTheme.blue)
                            }
                            Stepper("选择运动时长", value: $hours, in: 0.5...selectedTaskHourLimit, step: 0.5)
                                .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("补充说明")
                                .font(.headline.weight(.black))
                            TextEditor(text: $note)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(BNBUTheme.pale)
                                .overlay(Rectangle().stroke(BNBUTheme.line, lineWidth: 1))
                        }

                        ProofAttachmentPanel(attachments: $proofAttachments)

                        if let validationMessage {
                            Text(validationMessage)
                                .font(.caption.weight(.black))
                                .foregroundStyle(BNBUTheme.muted)
                        }

                        if supplementingRecord == nil {
                            HStack(spacing: 10) {
                                SecondaryActionButton(title: draftSaved ? "草稿已保存" : "保存草稿", systemImage: "tray.and.arrow.down") {
                                    saveDraft()
                                }
                                SecondaryActionButton(title: "清空草稿", systemImage: "trash") {
                                    clearDraftAndForm()
                                }
                            }
                        } else {
                            SecondaryActionButton(title: "取消补材料", systemImage: "xmark") {
                                cancelSupplement()
                            }
                        }

                        DisabledAwareButton(title: supplementingRecord == nil ? "提交打卡" : "提交补充材料", systemImage: "paperplane.fill", isDisabled: !canSubmit, accessibilityIdentifier: "checkin.submit.button") {
                            confirmSubmit = true
                        }
                    }
                }
            }
        }
    }

    private var recordList: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(eyebrow: "Records", title: "打卡记录")

            Picker("记录状态", selection: $selectedRecordFilter) {
                ForEach(RecordScopeFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.menu)

            if filteredRecords.isEmpty {
                EmptyPlaceholder(title: "暂无记录", message: "当前筛选条件下没有打卡记录。")
            }

            ForEach(filteredRecords) { record in
                VStack(spacing: 8) {
                    NavigationLink {
                        RecordDetailView(record: record) { record in
                            startSupplement(for: record)
                        }
                    } label: {
                        RecordCard(record: record)
                    }
                    .buttonStyle(.plain)

                    if record.status == .supplement || record.status == .rejected {
                        DisabledAwareButton(title: record.status == .supplement ? "补交材料" : "重新提交材料", systemImage: "arrow.up.doc.fill", isDisabled: false) {
                            startSupplement(for: record)
                        }
                    }
                }
            }
        }
    }

    private var selectedTask: CourseTask? {
        appState.activeTasks.first { $0.id == selectedTaskId }
    }

    private var selectedTaskHourLimit: Double {
        if let supplementingRecord {
            return min(max(supplementingRecord.hours, 0.5), appState.hourRule.dailyLimit)
        }
        guard let selectedTask else { return appState.hourRule.dailyLimit }
        return appState.hourLimit(for: selectedTask)
    }

    private var filteredTasks: [CourseTask] {
        appState.workspace.tasks.filter { task in
            switch selectedTaskFilter {
            case .all:
                return true
            case .course:
                return task.creditType == .courseRelated
            case .general:
                return task.creditType == .general
            }
        }
    }

    private var filteredRecords: [CheckInRecord] {
        appState.workspace.records.filter { record in
            switch selectedRecordFilter {
            case .all:
                return true
            case .pending:
                return record.status == .pending
            case .approved:
                return record.status == .approved
            case .rejected:
                return record.status == .rejected
            case .supplement:
                return record.status == .supplement
            case .offset:
                return record.status == .offset
            }
        }
    }

    private var canSubmit: Bool {
        let hasTarget = supplementingRecord != nil || selectedTask != nil
        return hasTarget &&
            hours > 0 &&
            hours <= selectedTaskHourLimit &&
            !proofAttachments.isEmpty &&
            proofAttachments.count <= ProofUploadRule.maxAttachmentCount &&
            proofAttachments.allSatisfy(\.isValidForUpload)
    }

    private var validationMessage: String? {
        if supplementingRecord == nil && selectedTask == nil {
            return "请选择一个有效任务。"
        }
        if hours > selectedTaskHourLimit {
            return "当前任务最多可提交 \(selectedTaskHourLimit.hourText)。"
        }
        if proofAttachments.isEmpty {
            return "请至少添加 1 个图片或视频凭证。"
        }
        if proofAttachments.count > ProofUploadRule.maxAttachmentCount {
            return "最多只能添加 \(ProofUploadRule.maxAttachmentCount) 个凭证。"
        }
        if let invalidProof = proofAttachments.first(where: { !$0.isValidForUpload }) {
            return "\(invalidProof.fileName) 不符合要求：\(invalidProof.validationMessage ?? "凭证无效")。"
        }
        return nil
    }

    private var submitConfirmationMessage: String {
        let targetTitle = supplementingRecord?.taskTitle ?? selectedTask?.title ?? "当前任务"
        return "\(targetTitle) · \(hours.hourText) · \(proofAttachments.count) 个凭证。提交后将进入老师审核队列。"
    }

    private var localRecoveryMessage: String? {
        if appState.storeHealth.workspaceReadStatus == .decodeFailed {
            return "本地工作台数据异常，已自动回退到可用的 Mock 工作台。"
        }
        switch appState.storeHealth.draftReadStatus {
        case .decodeFailed:
            return "本地草稿损坏，已自动忽略；可以重新选择任务并保存草稿。"
        case .discarded:
            return "本地草稿关联的任务已失效，已自动清理。"
        default:
            return nil
        }
    }

    private func courseForTask(_ task: CourseTask) -> Course? {
        appState.workspace.courses.first { $0.id == task.courseId }
    }

    private func restoreDraftIfNeeded() {
        guard !draftRestored else { return }
        draftRestored = true
        guard let draft = appState.draft else { return }
        restoreDraft(draft)
    }

    private func restoreDraft(_ draft: CheckInDraft) {
        guard supplementingRecord == nil else { return }
        guard appState.activeTasks.contains(where: { $0.id == draft.taskId }) else {
            clearDraftAndForm()
            ensureValidTaskSelection()
            return
        }
        selectedTaskId = draft.taskId
        hours = draft.hours
        note = draft.note
        proofAttachments = draft.proofAttachments
        selectedSegment = .submit
        draftSaved = false
        clampHoursForSelectedTask()
    }

    private func saveDraft() {
        appState.saveDraft(
            taskId: selectedTaskId,
            hours: hours,
            note: note,
            proofAttachments: proofAttachments
        )
        draftSaved = true
    }

    private func clearDraftAndForm() {
        appState.clearDraft()
        supplementingRecord = nil
        note = ""
        proofAttachments = []
        draftSaved = false
    }

    private func resetFormAfterSubmit() {
        note = ""
        proofAttachments = []
        supplementingRecord = nil
        draftSaved = false
    }

    private func startSubmission(for task: CourseTask) {
        guard task.status == .active else { return }
        selectedTaskId = task.id
        hours = appState.hourLimit(for: task)
        note = ""
        proofAttachments = []
        supplementingRecord = nil
        draftSaved = false
        selectedSegment = .submit
    }

    private func startSupplement(for record: CheckInRecord) {
        supplementingRecord = record
        hours = min(max(record.hours, 0.5), appState.hourRule.dailyLimit)
        note = "按老师反馈补充材料："
        proofAttachments = []
        draftSaved = false
        selectedSegment = .submit
    }

    private func performSubmit() {
        guard canSubmit else { return }
        if let supplementingRecord {
            appState.submitSupplement(
                for: supplementingRecord,
                hours: hours,
                note: note,
                proofAttachments: proofAttachments
            )
        } else {
            guard let selectedTask else { return }
            appState.submitCheckIn(
                task: selectedTask,
                hours: hours,
                note: note,
                proofAttachments: proofAttachments
            )
        }
        resetFormAfterSubmit()
        submitted = true
    }

    private func cancelSupplement() {
        supplementingRecord = nil
        note = ""
        proofAttachments = []
        selectedSegment = .records
    }

    private func ensureValidTaskSelection() {
        guard selectedTask == nil, let firstTask = appState.activeTasks.first else {
            clampHoursForSelectedTask()
            return
        }
        selectedTaskId = firstTask.id
        hours = appState.hourLimit(for: firstTask)
    }

    private func clampHoursForSelectedTask() {
        guard let selectedTask else { return }
        hours = appState.normalizedHours(hours, for: selectedTask)
    }
}

private struct DraftBanner: View {
    let draft: CheckInDraft
    let restoreAction: () -> Void
    let clearAction: () -> Void

    var body: some View {
        SwissPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Label("有未提交草稿", systemImage: "doc.badge.clock")
                        .font(.headline.weight(.black))
                        .foregroundStyle(BNBUTheme.ink)
                    Spacer()
                    StatusBadge(text: draft.updatedAt)
                }

                Text("已保存 \(draft.hours.hourText)，包含 \(draft.proofAttachments.count) 个凭证。")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BNBUTheme.muted)

                HStack(spacing: 10) {
                    SecondaryActionButton(title: "恢复草稿", systemImage: "arrow.clockwise", action: restoreAction)
                    SecondaryActionButton(title: "丢弃", systemImage: "xmark", action: clearAction)
                }
            }
        }
    }
}

private struct SupplementBanner: View {
    let record: CheckInRecord
    let cancelAction: () -> Void

    var body: some View {
        SwissPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Label("补充材料模式", systemImage: "arrow.up.doc")
                        .font(.headline.weight(.black))
                        .foregroundStyle(BNBUTheme.ink)
                    Spacer()
                    StatusBadge(text: record.status.rawValue, filled: true)
                }

                Text(record.taskTitle)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(BNBUTheme.ink)

                Text(record.teacherFeedback)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BNBUTheme.muted)
                    .lineSpacing(3)

                SecondaryActionButton(title: "返回记录", systemImage: "list.bullet.rectangle", action: cancelAction)
            }
        }
    }
}

private struct LocalRecoveryBanner: View {
    let message: String

    var body: some View {
        SwissPanel {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.headline.weight(.black))
                    .foregroundStyle(BNBUTheme.blue)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 6) {
                    Text("已恢复本地状态")
                        .font(.headline.weight(.black))
                        .foregroundStyle(BNBUTheme.ink)
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BNBUTheme.muted)
                        .lineSpacing(2)
                }
            }
        }
    }
}

private struct SecondaryActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(BNBUTheme.ink)
                .background(BNBUTheme.surface)
                .overlay(Rectangle().stroke(BNBUTheme.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

private struct TaskActionCard: View {
    let task: CourseTask
    let course: Course?
    let submitAction: () -> Void

    var body: some View {
        SwissPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Label(task.creditType.rawValue, systemImage: task.creditType.symbolName)
                        .font(.caption.weight(.black))
                        .foregroundStyle(BNBUTheme.blue)
                    Spacer()
                    StatusBadge(text: task.status.rawValue, filled: task.status == .active)
                }

                Text(task.title)
                    .font(.title3.weight(.black))
                    .foregroundStyle(BNBUTheme.ink)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("可获小时")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(BNBUTheme.muted)
                        Text(task.hours.hourText)
                            .font(.headline.weight(.black))
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("截止时间")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(BNBUTheme.muted)
                        Text(task.deadline)
                            .font(.subheadline.weight(.black))
                            .multilineTextAlignment(.leading)
                    }
                }

                Text("证明要求：\(task.proof)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BNBUTheme.muted)

                DisabledAwareButton(
                    title: task.status == .active ? "提交这个任务" : "任务不可提交",
                    systemImage: task.status == .active ? "square.and.pencil" : "lock",
                    isDisabled: task.status != .active,
                    action: submitAction
                )

                NavigationLink {
                    TaskDetailView(task: task, course: course)
                } label: {
                    Label("查看任务详情", systemImage: "info.circle")
                        .font(.caption.weight(.black))
                        .foregroundStyle(BNBUTheme.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
