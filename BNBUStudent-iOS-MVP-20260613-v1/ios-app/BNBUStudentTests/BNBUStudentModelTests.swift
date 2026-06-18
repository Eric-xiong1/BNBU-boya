import XCTest
@testable import BNBUStudent

@MainActor
final class BNBUStudentModelTests: XCTestCase {
    func testProofAttachmentValidationCatchesSizeAndDurationLimits() {
        let oversizedImage = ProofAttachment(
            id: "image-too-large",
            type: .image,
            fileName: "large.jpg",
            byteCount: ProofUploadRule.maxImageBytes + 1,
            source: "test"
        )
        XCTAssertEqual(oversizedImage.validationMessage, "图片超过 10MB")

        let longVideo = ProofAttachment(
            id: "video-too-long",
            type: .video,
            fileName: "long.mov",
            byteCount: 12_000_000,
            durationSeconds: Double(ProofUploadRule.maxVideoDurationSeconds + 1),
            source: "test"
        )
        XCTAssertEqual(longVideo.validationMessage, "视频超过 30 秒")
        XCTAssertFalse(longVideo.isValidForUpload)
    }

    func testAppStateClampsHoursWhenSubmitting() {
        let defaults = isolatedDefaults()
        let appState = AppState(
            repository: MockStudentRepository(),
            localStore: AppLocalStore(defaults: defaults)
        )

        guard let shortTask = appState.workspace.tasks.first(where: { $0.id == "t2" }) else {
            return XCTFail("Expected t2 in mock repository")
        }

        appState.submitCheckIn(
            task: shortTask,
            hours: 4,
            note: "",
            proofAttachments: [
                ProofAttachment(id: "proof", type: .image, fileName: "proof.jpg", byteCount: 400_000, source: "test")
            ]
        )

        XCTAssertEqual(appState.workspace.records.first?.hours, 1.5)
        XCTAssertEqual(appState.workspace.records.first?.status, .pending)
        XCTAssertEqual(appState.workspace.records.first?.proofPhotoCount, 1)
    }

    func testLocalStoreReportsCorruptDraftData() {
        let defaults = isolatedDefaults()
        defaults.set(Data("not-json".utf8), forKey: AppLocalStore.draftStorageKey)

        let result = AppLocalStore(defaults: defaults).readDraft()

        XCTAssertNil(result.value)
        XCTAssertEqual(result.status, .decodeFailed)
    }

    func testAppStateDiscardsDraftForClosedOrMissingTask() {
        let defaults = isolatedDefaults()
        let staleDraft = CheckInDraft(
            id: "stale",
            taskId: "closed-or-missing",
            hours: 2,
            note: "old",
            proofAttachments: [],
            updatedAt: "刚刚"
        )
        XCTAssertTrue(AppLocalStore(defaults: defaults).saveDraft(staleDraft))

        let appState = AppState(
            repository: MockStudentRepository(),
            localStore: AppLocalStore(defaults: defaults)
        )

        XCTAssertNil(appState.draft)
        XCTAssertEqual(appState.storeHealth.draftReadStatus, .discarded)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "BNBUStudentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
