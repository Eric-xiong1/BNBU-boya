import Foundation

struct StudentProfile: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let email: String
    let college: String
    let className: String
    let status: String
}

struct StudentWorkspace: Codable {
    var student: StudentProfile
    var courses: [Course]
    var progress: StudentProgress
    var tasks: [CourseTask]
    var records: [CheckInRecord]
    var grades: GradeRow
    var memberships: [Membership]
    var notices: [StudentNotice]
    var teachers: [TeacherInfo]
    var syncOperations: [SyncOperation]

    init(
        student: StudentProfile,
        courses: [Course],
        progress: StudentProgress,
        tasks: [CourseTask],
        records: [CheckInRecord],
        grades: GradeRow,
        memberships: [Membership],
        notices: [StudentNotice],
        teachers: [TeacherInfo] = [],
        syncOperations: [SyncOperation] = []
    ) {
        self.student = student
        self.courses = courses
        self.progress = progress
        self.tasks = tasks
        self.records = records
        self.grades = grades
        self.memberships = memberships
        self.notices = notices
        self.teachers = teachers
        self.syncOperations = syncOperations
    }

    enum CodingKeys: String, CodingKey {
        case student
        case courses
        case progress
        case tasks
        case records
        case grades
        case memberships
        case notices
        case teachers
        case syncOperations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        student = try container.decode(StudentProfile.self, forKey: .student)
        courses = try container.decode([Course].self, forKey: .courses)
        progress = try container.decode(StudentProgress.self, forKey: .progress)
        tasks = try container.decode([CourseTask].self, forKey: .tasks)
        records = try container.decode([CheckInRecord].self, forKey: .records)
        grades = try container.decode(GradeRow.self, forKey: .grades)
        memberships = try container.decode([Membership].self, forKey: .memberships)
        notices = try container.decode([StudentNotice].self, forKey: .notices)
        teachers = try container.decodeIfPresent([TeacherInfo].self, forKey: .teachers) ?? []
        syncOperations = try container.decodeIfPresent([SyncOperation].self, forKey: .syncOperations) ?? []
    }
}

enum SyncOperationType: String, CaseIterable, Identifiable, Hashable, Codable {
    case submitRecord = "提交打卡"
    case supplementRecord = "补交材料"
    case markNoticeRead = "通知已读"
    case resetLocalData = "重置数据"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .submitRecord:
            return "paperplane.fill"
        case .supplementRecord:
            return "arrow.up.doc.fill"
        case .markNoticeRead:
            return "checkmark.circle"
        case .resetLocalData:
            return "arrow.counterclockwise"
        }
    }
}

enum SyncOperationStatus: String, CaseIterable, Identifiable, Hashable, Codable {
    case queued = "待同步"
    case localOnly = "本地完成"
    case synced = "已同步"

    var id: String { rawValue }
}

struct SyncOperation: Identifiable, Hashable, Codable {
    let id: String
    let type: SyncOperationType
    let title: String
    let detail: String
    let createdAt: String
    var status: SyncOperationStatus
}

struct Course: Identifiable, Hashable, Codable {
    let id: String
    let code: String
    let section: String
    let name: String
    let semester: String
    let students: Int
    let pending: Int
    let completion: Int
    let missing: Int
    let deadline: String
    let teacher: String
    let teacherId: String

    var displayTitle: String {
        "\(code) / Section \(section)"
    }
}

struct TeacherInfo: Identifiable, Hashable, Codable {
    let teacherId: String
    let teacherName: String

    var id: String { teacherId }
}

struct StudentProgress: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let college: String
    let className: String
    var course: Double
    var general: Double
    var rawGeneral: Double
    let exam: Int
    let attendance: Int
    let physical: Int
    var status: String
    let source: String
    var organizationCredit: Membership?
}

enum CreditType: String, CaseIterable, Identifiable, Hashable, Codable {
    case courseRelated = "课程相关"
    case general = "其他运动"
    case organizationOffset = "系统抵扣"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .courseRelated: return "book.closed"
        case .general: return "figure.run"
        case .organizationOffset: return "checkmark.seal"
        }
    }
}

enum TaskStatus: String, CaseIterable, Identifiable, Hashable, Codable {
    case draft = "草稿"
    case active = "进行中"
    case closed = "已关闭"

    var id: String { rawValue }
}

struct CourseTask: Identifiable, Hashable, Codable {
    let id: String
    let courseId: String
    let creditType: CreditType
    let title: String
    let hours: Double
    let deadline: String
    let proof: String
    let status: TaskStatus
    let updatedAt: String
}

enum ReviewStatus: String, CaseIterable, Identifiable, Hashable, Codable {
    case pending = "待审核"
    case approved = "已通过"
    case rejected = "被驳回"
    case supplement = "需补材料"
    case offset = "系统抵扣"

    var id: String { rawValue }
}

struct CheckInRecord: Identifiable, Hashable, Codable {
    let id: String
    let courseId: String?
    let taskTitle: String
    let creditType: CreditType
    var hours: Double
    var submittedAt: String
    var status: ReviewStatus
    var proofSummary: String
    var proofPhotoCount: Int
    var proofVideoCount: Int
    var proofFiles: [ProofAttachment]
    var teacherFeedback: String
    var note: String
}

enum ProofMediaType: String, CaseIterable, Identifiable, Hashable, Codable {
    case image = "图片"
    case video = "视频"

    var id: String { rawValue }
}

enum ProofUploadRule {
    static let maxAttachmentCount = 8
    static let maxImageBytes = 10_000_000
    static let maxVideoBytes = 80_000_000
    static let maxVideoDurationSeconds = 30

    static var summaryText: String {
        "最多 \(maxAttachmentCount) 个；图片不超过 10MB；视频不超过 80MB，视频不超过 \(maxVideoDurationSeconds) 秒。"
    }
}

struct ProofAttachment: Identifiable, Hashable, Codable {
    let id: String
    let type: ProofMediaType
    let fileName: String
    let byteCount: Int?
    var durationSeconds: Double? = nil
    var thumbnailData: Data? = nil
    let source: String

    var displaySize: String {
        guard let byteCount else { return "本地占位" }
        if byteCount >= 1_000_000 {
            return String(format: "%.1f MB", Double(byteCount) / 1_000_000)
        }
        return "\(max(byteCount / 1_000, 1)) KB"
    }

    var displayDuration: String? {
        guard let durationSeconds else { return nil }
        let totalSeconds = max(Int(durationSeconds.rounded()), 0)
        if totalSeconds >= 60 {
            return "\(totalSeconds / 60)分\(totalSeconds % 60)秒"
        }
        return "\(totalSeconds)秒"
    }

    var validationMessage: String? {
        if let byteCount {
            switch type {
            case .image where byteCount > ProofUploadRule.maxImageBytes:
                return "图片超过 10MB"
            case .video where byteCount > ProofUploadRule.maxVideoBytes:
                return "视频超过 80MB"
            default:
                break
            }
        }

        if type == .video,
           let durationSeconds,
           durationSeconds > Double(ProofUploadRule.maxVideoDurationSeconds) {
            return "视频超过 \(ProofUploadRule.maxVideoDurationSeconds) 秒"
        }

        return nil
    }

    var isValidForUpload: Bool {
        validationMessage == nil
    }
}

struct CheckInDraft: Identifiable, Hashable, Codable {
    let id: String
    var taskId: String
    var hours: Double
    var note: String
    var proofAttachments: [ProofAttachment]
    var updatedAt: String
}

struct Membership: Identifiable, Hashable, Codable {
    let id: String
    let type: String
    let organization: String
    let studentId: String
    let studentName: String
    let status: String
    let validUntil: String
    let offset: String
    let comment: String
    let updatedBy: String
    let updatedAt: String

    var typeTitle: String {
        type == "team" ? "校队" : "社团"
    }
}

struct GradeRow: Identifiable, Hashable, Codable {
    var id: String { studentId }
    let studentId: String
    let studentName: String
    let checkinScore: Int
    let exam: Int
    let attendance: Int
    let physical: Int
    let total: Int
    let sourceTrace: String
    let missingItems: [String]
}

enum NoticeCategory: String, CaseIterable, Identifiable, Hashable, Codable {
    case deadline = "截止提醒"
    case review = "审核反馈"
    case organization = "组织认证"
    case system = "系统通知"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .deadline:
            return "calendar.badge.clock"
        case .review:
            return "doc.text.magnifyingglass"
        case .organization:
            return "person.3.sequence"
        case .system:
            return "bell"
        }
    }
}

struct StudentNotice: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let message: String
    let time: String
    let category: NoticeCategory
    var isUnread: Bool

    init(
        id: String,
        title: String,
        message: String,
        time: String,
        category: NoticeCategory = .system,
        isUnread: Bool
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.time = time
        self.category = category
        self.isUnread = isUnread
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case message
        case time
        case category
        case isUnread
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        message = try container.decode(String.self, forKey: .message)
        time = try container.decode(String.self, forKey: .time)
        category = try container.decodeIfPresent(NoticeCategory.self, forKey: .category) ?? Self.inferCategory(title: title, message: message)
        isUnread = try container.decode(Bool.self, forKey: .isUnread)
    }

    private static func inferCategory(title: String, message: String) -> NoticeCategory {
        let text = title + message
        if text.contains("截止") {
            return .deadline
        }
        if text.contains("补材料") || text.contains("补充材料") || text.contains("审核") || text.contains("驳回") {
            return .review
        }
        if text.contains("校队") || text.contains("社团") || text.contains("组织") || text.contains("认证") {
            return .organization
        }
        return .system
    }
}

struct SportHourRule: Hashable, Codable {
    let total: Double
    let courseRequired: Double
    let generalRequired: Double
    let dailyLimit: Double

    static let standard = SportHourRule(total: 20, courseRequired: 10, generalRequired: 10, dailyLimit: 2)
}
