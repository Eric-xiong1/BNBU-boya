import SwiftUI

struct CoursesView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            GridBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(eyebrow: "My Courses", title: "我的课程")

                    Text("教学班以课程代码 + Section 区分；同一课程代码的不同 Section 会作为不同教学班展示。")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BNBUTheme.muted)
                        .lineSpacing(3)

                    if appState.workspace.courses.isEmpty {
                        EmptyPlaceholder(
                            title: "暂无课程",
                            message: "当前账号还没有可展示的体育教学班；课程同步后会按课程代码和 Section 显示。"
                        )
                    } else {
                        ForEach(appState.workspace.courses) { course in
                            NavigationLink {
                                CourseDetailView(course: course)
                            } label: {
                                CourseCard(course: course)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(18)
            }
        }
        .accessibilityIdentifier("screen.courses")
    }
}

private struct CourseCard: View {
    let course: Course

    var body: some View {
        SwissPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(course.displayTitle)
                            .font(.title3.weight(.black))
                            .foregroundStyle(BNBUTheme.ink)
                        Text(course.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(BNBUTheme.muted)
                    }
                    Spacer()
                    StatusBadge(text: course.semester)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    CourseFact(label: "任课老师", value: course.teacher)
                    CourseFact(label: "课程学生", value: "\(course.students)")
                    CourseFact(label: "待审核", value: "\(course.pending)")
                    CourseFact(label: "未完成", value: "\(course.missing)")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("班级完成率")
                            .font(.caption.weight(.black))
                            .foregroundStyle(BNBUTheme.muted)
                        Spacer()
                        Text("\(course.completion)%")
                            .font(.caption.weight(.black))
                    }
                    HourProgressBar(value: Double(course.completion), total: 100)
                }

                Text("下一截止：\(course.deadline)")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(BNBUTheme.ink)

                Label("查看教学班详情", systemImage: "chevron.right")
                    .font(.caption.weight(.black))
                    .foregroundStyle(BNBUTheme.blue)
            }
        }
    }
}

private struct CourseFact: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.black))
                .foregroundStyle(BNBUTheme.muted)
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(BNBUTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(BNBUTheme.blueSoft)
        .overlay(Rectangle().stroke(BNBUTheme.line, lineWidth: 1))
    }
}
