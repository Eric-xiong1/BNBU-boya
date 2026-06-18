import Foundation

enum LocalStoreReadStatus: String, Hashable {
    case missing = "未保存"
    case loaded = "已读取"
    case decodeFailed = "解码失败"
    case discarded = "已丢弃"
}

enum LocalStoreWriteStatus: String, Hashable {
    case idle = "未写入"
    case saved = "写入成功"
    case failed = "写入失败"
    case cleared = "已清理"
}

struct LocalStoreReadResult<Value> {
    let value: Value?
    let status: LocalStoreReadStatus
}

struct LocalStoreHealth: Hashable {
    var workspaceReadStatus: LocalStoreReadStatus
    var draftReadStatus: LocalStoreReadStatus
    var lastWriteStatus: LocalStoreWriteStatus
    var lastEvent: String

    static let fresh = LocalStoreHealth(
        workspaceReadStatus: .missing,
        draftReadStatus: .missing,
        lastWriteStatus: .idle,
        lastEvent: "尚未读取本地数据"
    )
}

struct AppLocalStore {
    static let workspaceStorageKey = "bnbu.student.workspace.v1"
    static let draftStorageKey = "bnbu.student.checkin.draft.v1"

    private let workspaceKey = Self.workspaceStorageKey
    private let draftKey = Self.draftStorageKey
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadWorkspace() -> StudentWorkspace? {
        readWorkspace().value
    }

    func readWorkspace() -> LocalStoreReadResult<StudentWorkspace> {
        read(StudentWorkspace.self, forKey: workspaceKey)
    }

    @discardableResult
    func saveWorkspace(_ workspace: StudentWorkspace) -> Bool {
        save(workspace, forKey: workspaceKey)
    }

    func loadDraft() -> CheckInDraft? {
        readDraft().value
    }

    func readDraft() -> LocalStoreReadResult<CheckInDraft> {
        read(CheckInDraft.self, forKey: draftKey)
    }

    @discardableResult
    func saveDraft(_ draft: CheckInDraft) -> Bool {
        save(draft, forKey: draftKey)
    }

    func clearDraft() {
        defaults.removeObject(forKey: draftKey)
    }

    func clearAll() {
        defaults.removeObject(forKey: workspaceKey)
        defaults.removeObject(forKey: draftKey)
    }

    private func read<T: Decodable>(_ type: T.Type, forKey key: String) -> LocalStoreReadResult<T> {
        guard let data = defaults.data(forKey: key) else {
            return LocalStoreReadResult(value: nil, status: .missing)
        }

        do {
            return LocalStoreReadResult(
                value: try JSONDecoder().decode(type, from: data),
                status: .loaded
            )
        } catch {
            return LocalStoreReadResult(value: nil, status: .decodeFailed)
        }
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        defaults.set(data, forKey: key)
        return true
    }
}
