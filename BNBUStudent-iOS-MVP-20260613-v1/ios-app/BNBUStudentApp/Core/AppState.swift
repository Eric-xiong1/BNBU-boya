import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var workspace: StudentWorkspace
    @Published var draft: CheckInDraft?
    @Published var storeHealth: LocalStoreHealth

    private let repository: StudentRepository
    private let localStore: AppLocalStore
    private let apiClient = StudentAPIClient()
    let hourRule = SportHourRule.standard

    init(repository: StudentRepository, localStore: AppLocalStore = AppLocalStore()) {
        self.repository = repository
        self.localStore = localStore
        let workspaceRead = localStore.readWorkspace()
        let draftRead = localStore.readDraft()
        var workspace = workspaceRead.value ?? repository.loadWorkspace()
        if workspace.syncOperations.isEmpty {
            workspace.syncOperations = [Self.localWorkspaceLoadedOperation]
        }
        let savedDraft = draftRead.value
        var draftReadStatus = draftRead.status
        var bootEvent = Self.bootEvent(workspaceStatus: workspaceRead.status, draftStatus: draftRead.status)
        var restoredDraft: CheckInDraft?

        if let savedDraft, workspace.tasks.contains(where: { $0.id == savedDraft.taskId && $0.status == .active }) {
            restoredDraft = savedDraft
        } else if savedDraft != nil {
            draftReadStatus = .discarded
            bootEvent = "草稿任务已失效，已自动清理。"
            localStore.clearDraft()
        }

        self.workspace = workspace
        self.draft = restoredDraft
        self.storeHealth = LocalStoreHealth(
            workspaceReadStatus: workspaceRead.status,
            draftReadStatus: draftReadStatus,
            lastWriteStatus: .idle,
            lastEvent: bootEvent
        )
    }

    var courseRemaining: Double {
        max(hourRule.courseRequired - workspace.progress.course, 0)
    }

    var generalRemaining: Double {
        max(hourRule.generalRequired - workspace.progress.general, 0)
    }

    var totalCompleted: Double {
        min(workspace.progress.course, hourRule.courseRequired) + min(workspace.progress.general, hourRule.generalRequired)
    }

    var totalRemaining: Double {
        max(hourRule.total - totalCompleted, 0)
    }

    var completionRatio: Double {
        guard hourRule.total > 0 else { return 0 }
        return min(totalCompleted / hourRule.total, 1)
    }

    var unreadNoticeCount: Int {
        workspace.notices.filter(\.isUnread).count
    }

    var activeTasks: [CourseTask] {
        workspace.tasks.filter { $0.status == .active }
    }

    var pendingRecordCount: Int {
        workspace.records.filter { $0.status == .pending }.count
    }

    var supplementRecordCount: Int {
        workspace.records.filter { $0.status == .supplement }.count
    }

    var actionableRecordCount: Int {
        pendingRecordCount + supplementRecordCount
    }

    var queuedSyncCount: Int {
        workspace.syncOperations.filter { $0.status == .queued }.count
    }

    var latestSyncOperation: SyncOperation? {
        workspace.syncOperations.first
    }

    var apiBaseURLDescription: String {
        apiClient.baseURL.absoluteString
    }

    var dataIntegritySummary: String {
        let courseIds = Set(workspace.courses.map(\.id))
        var issues: [String] = []

        if containsDuplicates(workspace.courses.map(\.id)) {
            issues.append("课程 ID 重复")
        }
        if containsDuplicates(workspace.tasks.map(\.id)) {
            issues.append("任务 ID 重复")
        }
        if containsDuplicates(workspace.records.map(\.id)) {
            issues.append("记录 ID 重复")
        }

        let invalidTaskCount = workspace.tasks.filter { task in
            task.courseId != "self-general" && !courseIds.contains(task.courseId)
        }.count
        if invalidTaskCount > 0 {
            issues.append("任务课程引用 \(invalidTaskCount)")
        }

        let invalidRecordCount = workspace.records.filter { record in
            guard let courseId = record.courseId else { return false }
            return !courseIds.contains(courseId)
        }.count
        if invalidRecordCount > 0 {
            issues.append("记录课程引用 \(invalidRecordCount)")
        }

        if let draft, !workspace.tasks.contains(where: { $0.id == draft.taskId && $0.status == .active }) {
            issues.append("草稿任务失效")
        }

        return issues.isEmpty ? "正常" : issues.joined(separator: " / ")
    }

    func demoLogin() {
        isAuthenticated = true
    }

    func logout() {
        isAuthenticated = false
    }

    func tasks(for course: Course) -> [CourseTask] {
        workspace.tasks.filter { $0.courseId == course.id }
    }

    func records(for course: Course) -> [CheckInRecord] {
        workspace.records.filter { $0.courseId == course.id }
    }

    func markNoticeRead(id: String) {
        guard let index = workspace.notices.firstIndex(where: { $0.id == id }) else { return }
        let notice = workspace.notices[index]
        guard notice.isUnread else { return }
        workspace.notices[index].isUnread = false
        enqueueSyncOperation(
            .markNoticeRead,
            title: "标记通知已读",
            detail: notice.title
        )
        saveWorkspace(event: "通知已读状态已保存")
    }

    func markAllNoticesRead() {
        guard unreadNoticeCount > 0 else { return }
        let count = unreadNoticeCount
        for index in workspace.notices.indices {
            workspace.notices[index].isUnread = false
        }
        enqueueSyncOperation(
            .markNoticeRead,
            title: "批量标记通知已读",
            detail: "\(count) 条通知已切换为已读"
        )
        saveWorkspace(event: "批量通知已读已保存")
    }

    func submitCheckIn(task: CourseTask, hours: Double, note: String, proofAttachments: [ProofAttachment]) {
        guard task.status == .active else { return }
        let submittedHours = normalizedHours(hours, for: task)
        let photoCount = proofAttachments.filter { $0.type == .image }.count
        let videoCount = proofAttachments.filter { $0.type == .video }.count
        let record = CheckInRecord(
            id: UUID().uuidString,
            courseId: task.courseId == "self-general" ? nil : task.courseId,
            taskTitle: task.title,
            creditType: task.creditType,
            hours: submittedHours,
            submittedAt: "刚刚",
            status: .pending,
            proofSummary: proofSummary(proofAttachments: proofAttachments),
            proofPhotoCount: photoCount,
            proofVideoCount: videoCount,
            proofFiles: proofAttachments,
            teacherFeedback: "已提交，等待老师审核。",
            note: note.isEmpty ? "学生未填写补充说明。" : note
        )
        workspace.records.insert(record, at: 0)
        workspace.notices.insert(
            StudentNotice(
                id: UUID().uuidString,
                title: "打卡已提交",
                message: "\(task.title) 已进入待审核状态，审核通过后才会计入有效小时。",
                time: "刚刚",
                category: .review,
                isUnread: true
            ),
            at: 0
        )
        enqueueSyncOperation(
            .submitRecord,
            title: "提交打卡记录",
            detail: "\(task.title) · \(submittedHours.hourText) · \(proofAttachments.count) 个凭证"
        )
        clearDraft()
        saveWorkspace(event: "打卡提交已保存")
    }

    func submitSupplement(for record: CheckInRecord, hours: Double, note: String, proofAttachments: [ProofAttachment]) {
        guard let index = workspace.records.firstIndex(where: { $0.id == record.id }) else { return }
        guard workspace.records[index].status == .supplement || workspace.records[index].status == .rejected else { return }
        guard !proofAttachments.isEmpty else { return }

        let submittedHours = min(max(hours, 0.5), hourRule.dailyLimit)
        let mergedProofs = workspace.records[index].proofFiles + proofAttachments
        let photoCount = mergedProofs.filter { $0.type == .image }.count
        let videoCount = mergedProofs.filter { $0.type == .video }.count

        workspace.records[index].hours = submittedHours
        workspace.records[index].submittedAt = "刚刚补交"
        workspace.records[index].status = .pending
        workspace.records[index].proofSummary = proofSummary(proofAttachments: mergedProofs)
        workspace.records[index].proofPhotoCount = photoCount
        workspace.records[index].proofVideoCount = videoCount
        workspace.records[index].proofFiles = mergedProofs
        workspace.records[index].teacherFeedback = "补充材料已提交，等待老师复审。"
        workspace.records[index].note = note.isEmpty ? "学生已按反馈补交材料。" : note

        workspace.notices.insert(
            StudentNotice(
                id: UUID().uuidString,
                title: "补充材料已提交",
                message: "\(record.taskTitle) 的补充材料已进入复审队列。",
                time: "刚刚",
                category: .review,
                isUnread: true
            ),
            at: 0
        )
        enqueueSyncOperation(
            .supplementRecord,
            title: "提交补充材料",
            detail: "\(record.taskTitle) · 新增 \(proofAttachments.count) 个凭证"
        )

        saveWorkspace(event: "补充材料已保存")
    }

    func saveDraft(taskId: String, hours: Double, note: String, proofAttachments: [ProofAttachment]) {
        guard let task = workspace.tasks.first(where: { $0.id == taskId && $0.status == .active }) else {
            clearDraft()
            return
        }
        let draft = CheckInDraft(
            id: draft?.id ?? UUID().uuidString,
            taskId: taskId,
            hours: normalizedHours(hours, for: task),
            note: note,
            proofAttachments: proofAttachments,
            updatedAt: "刚刚"
        )
        self.draft = draft
        saveDraft(draft, event: "打卡草稿已保存")
    }

    func hourLimit(for task: CourseTask) -> Double {
        min(task.hours, hourRule.dailyLimit)
    }

    func normalizedHours(_ hours: Double, for task: CourseTask) -> Double {
        min(max(hours, 0.5), hourLimit(for: task))
    }

    func clearDraft() {
        draft = nil
        localStore.clearDraft()
        storeHealth.draftReadStatus = .missing
        storeHealth.lastWriteStatus = .cleared
        storeHealth.lastEvent = "打卡草稿已清理"
    }

    func resetLocalDemoData() {
        localStore.clearAll()
        workspace = repository.loadWorkspace()
        enqueueSyncOperation(
            .resetLocalData,
            title: "重置本地演示数据",
            detail: "已恢复初始 mock 工作台",
            status: .localOnly
        )
        draft = nil
        storeHealth.draftReadStatus = .missing
        storeHealth.lastWriteStatus = .cleared
        storeHealth.lastEvent = "本地演示数据已清理"
        saveWorkspace(event: "本地演示数据已重置")
    }

    private func proofSummary(proofAttachments: [ProofAttachment]) -> String {
        let photoCount = proofAttachments.filter { $0.type == .image }.count
        let videoCount = proofAttachments.filter { $0.type == .video }.count
        var parts: [String] = []
        if photoCount > 0 {
            parts.append("\(photoCount) 张图片")
        }
        if videoCount > 0 {
            parts.append("\(videoCount) 个短视频")
        }
        return parts.isEmpty ? "未添加凭证" : parts.joined(separator: "，")
    }

    private func enqueueSyncOperation(
        _ type: SyncOperationType,
        title: String,
        detail: String,
        status: SyncOperationStatus = .queued
    ) {
        workspace.syncOperations.insert(
            SyncOperation(
                id: UUID().uuidString,
                type: type,
                title: title,
                detail: detail,
                createdAt: "刚刚",
                status: status
            ),
            at: 0
        )
        if workspace.syncOperations.count > 12 {
            workspace.syncOperations = Array(workspace.syncOperations.prefix(12))
        }
    }

    private func saveWorkspace(event: String) {
        let saved = localStore.saveWorkspace(workspace)
        storeHealth.workspaceReadStatus = saved ? .loaded : storeHealth.workspaceReadStatus
        storeHealth.lastWriteStatus = saved ? .saved : .failed
        storeHealth.lastEvent = saved ? event : "\(event)失败"
    }

    private func saveDraft(_ draft: CheckInDraft, event: String) {
        let saved = localStore.saveDraft(draft)
        storeHealth.draftReadStatus = saved ? .loaded : storeHealth.draftReadStatus
        storeHealth.lastWriteStatus = saved ? .saved : .failed
        storeHealth.lastEvent = saved ? event : "\(event)失败"
    }

    private func containsDuplicates(_ ids: [String]) -> Bool {
        Set(ids).count != ids.count
    }

    private static var localWorkspaceLoadedOperation: SyncOperation {
        SyncOperation(
            id: "sync-local-load",
            type: .resetLocalData,
            title: "读取本地工作台",
            detail: "从 UserDefaults 或 mock repository 加载学生端数据。",
            createdAt: "启动时",
            status: .localOnly
        )
    }

    private static func bootEvent(
        workspaceStatus: LocalStoreReadStatus,
        draftStatus: LocalStoreReadStatus
    ) -> String {
        if workspaceStatus == .decodeFailed {
            return "工作台本地数据解码失败，已回退到 mock 数据。"
        }
        if draftStatus == .decodeFailed {
            return "草稿本地数据解码失败，已忽略本地草稿。"
        }
        if workspaceStatus == .loaded || draftStatus == .loaded {
            return "本地数据读取完成。"
        }
        return "未发现本地数据，已使用 mock 初始数据。"
    }
}
