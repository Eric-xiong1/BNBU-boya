import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            GridBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .top) {
                        BrandMark()
                        Spacer()
                        Text("STUDENT APP")
                            .font(.caption.weight(.black))
                            .foregroundStyle(BNBUTheme.muted)
                            .padding(.top, 8)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("BNBU")
                            .font(.system(size: 58, weight: .black))
                            .foregroundStyle(BNBUTheme.ink)
                        Text("体育打卡与成绩进度")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(BNBUTheme.ink)
                        Text("课程相关 10 小时 + 其他运动 10 小时，进度、缺口、审核反馈一次看清。")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(BNBUTheme.muted)
                            .lineSpacing(4)
                    }

                    SwissPanel {
                        VStack(alignment: .leading, spacing: 18) {
                            SectionTitle(eyebrow: "Demo Login", title: "学生演示登录")

                            VStack(alignment: .leading, spacing: 10) {
                                Label("陈雨晴 · 22301142", systemImage: "person.text.rectangle")
                                Label("GEPE101 / Section 1004", systemImage: "book.closed")
                                Label("BNBU 体育打卡 MVP", systemImage: "checkmark.seal")
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(BNBUTheme.ink)

                            PrimaryActionButton(title: "进入学生端", systemImage: "arrow.right") {
                                appState.demoLogin()
                            }
                            .accessibilityIdentifier("login.demo.button")
                        }
                    }

                    Text("第一阶段仅包含学生端体育打卡与成绩透明化；老师端和管理端由 Web 承担。")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BNBUTheme.muted)
                }
                .padding(24)
            }
        }
        .accessibilityIdentifier("screen.login")
    }
}
