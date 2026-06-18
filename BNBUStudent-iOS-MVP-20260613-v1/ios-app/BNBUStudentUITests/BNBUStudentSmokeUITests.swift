import XCTest

final class BNBUStudentSmokeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testStudentShellSmokeFlow() throws {
        XCTAssertTrue(app.otherElements["screen.login"].waitForExistence(timeout: 5))

        app.buttons["login.demo.button"].tap()

        XCTAssertTrue(app.otherElements["screen.dashboard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["体育学时进度"].exists)

        openTab(label: "课程", screenIdentifier: "screen.courses")
        XCTAssertTrue(app.staticTexts["我的课程"].waitForExistence(timeout: 3))

        openTab(label: "打卡", screenIdentifier: "screen.checkin")
        XCTAssertTrue(app.staticTexts["打卡任务列表"].waitForExistence(timeout: 3))

        openTab(label: "成绩", screenIdentifier: "screen.grades")
        XCTAssertTrue(app.staticTexts["成绩进度"].waitForExistence(timeout: 3))

        openTab(label: "我的", screenIdentifier: "screen.profile")
        XCTAssertTrue(app.staticTexts["本地调试"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["数据完整性"].exists)
        XCTAssertTrue(app.staticTexts["正常"].exists)
    }

    func testSubmitDraftAndPendingRecordFlow() throws {
        login()
        openTab(label: "打卡", screenIdentifier: "screen.checkin")

        app.segmentedControls.buttons["提交"].tap()
        scrollToAndTap(app.buttons["proof.demo.add"])
        scrollToAndTap(app.buttons["保存草稿"])
        XCTAssertTrue(app.buttons["草稿已保存"].waitForExistence(timeout: 2))

        scrollToAndTap(app.buttons["checkin.submit.button"])
        XCTAssertTrue(app.staticTexts["确认提交打卡"].waitForExistence(timeout: 3))
        app.buttons["提交并进入待审核"].tap()
        XCTAssertTrue(app.staticTexts["提交成功"].waitForExistence(timeout: 3))
        app.buttons["查看记录"].tap()

        XCTAssertTrue(app.staticTexts["课外跑步训练 Week 08"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["待审核"].exists)
        XCTAssertTrue(app.staticTexts["凭证：1 张图片"].exists)
    }

    func testSupplementNoticeReadAndLogoutFlow() throws {
        login()
        openTab(label: "打卡", screenIdentifier: "screen.checkin")

        app.segmentedControls.buttons["记录"].tap()
        scrollToAndTap(app.buttons["补交材料"])
        scrollToAndTap(app.buttons["proof.demo.add"])
        scrollToAndTap(app.buttons["checkin.submit.button"])
        XCTAssertTrue(app.staticTexts["确认提交补充材料"].waitForExistence(timeout: 3))
        app.buttons["提交补充材料"].tap()
        XCTAssertTrue(app.staticTexts["提交成功"].waitForExistence(timeout: 3))
        app.buttons["查看记录"].tap()
        XCTAssertTrue(app.staticTexts["刚刚补交"].waitForExistence(timeout: 3))

        openTab(label: "我的", screenIdentifier: "screen.profile")
        scrollToAndTap(app.buttons["全部已读"])
        scrollToAndTap(app.buttons["退出登录"])
        XCTAssertTrue(app.otherElements["screen.login"].waitForExistence(timeout: 3))
    }

    func testEmptyStateSmokeFlow() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-empty-state"]
        app.launch()

        login()

        openTab(label: "课程", screenIdentifier: "screen.courses")
        XCTAssertTrue(app.staticTexts["暂无课程"].waitForExistence(timeout: 3))

        openTab(label: "打卡", screenIdentifier: "screen.checkin")
        XCTAssertTrue(app.staticTexts["暂无打卡任务"].waitForExistence(timeout: 3))
        app.segmentedControls.buttons["提交"].tap()
        XCTAssertTrue(app.staticTexts["暂无可提交任务"].waitForExistence(timeout: 3))

        openTab(label: "我的", screenIdentifier: "screen.profile")
        XCTAssertTrue(app.staticTexts["暂无认证记录"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["暂无通知"].exists)
    }

    private func openTab(label: String, screenIdentifier: String) {
        app.tabBars.buttons[label].tap()
        XCTAssertTrue(app.otherElements[screenIdentifier].waitForExistence(timeout: 3))
    }

    private func login() {
        XCTAssertTrue(app.otherElements["screen.login"].waitForExistence(timeout: 5))
        app.buttons["login.demo.button"].tap()
        XCTAssertTrue(app.otherElements["screen.dashboard"].waitForExistence(timeout: 5))
    }

    private func scrollToAndTap(_ element: XCUIElement, maxSwipes: Int = 6) {
        for _ in 0..<maxSwipes {
            if element.waitForExistence(timeout: 0.5), element.isHittable {
                element.tap()
                return
            }
            app.swipeUp()
        }

        XCTAssertTrue(element.waitForExistence(timeout: 2))
        element.tap()
    }
}
