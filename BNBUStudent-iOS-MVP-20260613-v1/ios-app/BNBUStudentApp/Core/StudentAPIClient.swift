import Foundation

struct StudentAPIClient {
    let baseURL: URL
    var token: String?

    init(baseURL: URL = URL(string: "http://127.0.0.1:8080/api")!, token: String? = nil) {
        self.baseURL = baseURL
        self.token = token
    }

    func request(for endpoint: StudentEndpoint) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: endpoint.path))
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
}

enum StudentEndpoint {
    case login
    case sportSummary
    case sportRecords
    case sportRecordDetail(id: String)
    case supplementSportRecord(id: String)
    case sportIdentity
    case notifications
    case markNotificationRead(id: String)

    var method: HTTPMethod {
        switch self {
        case .login, .sportRecords, .supplementSportRecord:
            return .post
        case .markNotificationRead:
            return .put
        case .sportSummary, .sportRecordDetail, .sportIdentity, .notifications:
            return .get
        }
    }

    var path: String {
        switch self {
        case .login:
            return "/auth/login"
        case .sportSummary:
            return "/sport/summary"
        case .sportRecords:
            return "/sport/records"
        case .sportRecordDetail(let id):
            return "/sport/records/\(id)"
        case .supplementSportRecord(let id):
            return "/sport/records/\(id)/supplements"
        case .sportIdentity:
            return "/sport/identity"
        case .notifications:
            return "/common/notifications"
        case .markNotificationRead(let id):
            return "/common/notifications/\(id)/read"
        }
    }
}

struct SubmitSportRecordRequest: Encodable {
    let creditType: String
    let courseId: String?
    let taskId: String
    let hours: Double
    let description: String
    let proofFiles: [String]
}

struct SupplementSportRecordRequest: Encodable {
    let hours: Double
    let description: String
    let proofFiles: [String]
}
