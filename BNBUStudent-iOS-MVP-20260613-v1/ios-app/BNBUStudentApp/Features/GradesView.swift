import SwiftUI

struct GradesView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            GridBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(eyebrow: "Grade Progress", title: "成绩进度")

                    totalPanel
                    components
                    formulaPanel
                    missingPanel
                    tracePanel
                }
                .padding(18)
            }
        }
        .accessibilityIdentifier("screen.grades")
    }

    private var totalPanel: some View {
        SwissPanel {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("总分预估")
                        .font(.headline.weight(.black))
                    Text("基于当前已录入四块成绩与权重规则，待审核打卡暂不计入。")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BNBUTheme.muted)
                }
                Spacer()
                Text("\(appState.workspace.grades.total)")
                    .font(.system(size: 54, weight: .black))
                    .foregroundStyle(BNBUTheme.ink)
            }
        }
    }

    private var components: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(gradeComponents) { component in
                GradeComponentCard(component: component)
            }
        }
    }

    private var formulaPanel: some View {
        SwissPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("总分计算")
                        .font(.headline.weight(.black))
                    Spacer()
                    StatusBadge(text: "透明预估")
                }

                ForEach(gradeComponents) { component in
                    GradeContributionRow(component: component)
                }

                Divider()

                DetailFactRow(label: "加权合计", value: String(format: "%.1f", weightedTotal))
                DetailFactRow(label: "四舍五入", value: "\(appState.workspace.grades.total)")
            }
        }
    }

    private var missingPanel: some View {
        SwissPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("缺失项 / 风险")
                        .font(.headline.weight(.black))
                    Spacer()
                    StatusBadge(text: appState.workspace.grades.missingItems.isEmpty ? "无缺失" : "\(appState.workspace.grades.missingItems.count) 项")
                }

                if appState.workspace.grades.missingItems.isEmpty {
                    Text("当前没有阻塞项。")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BNBUTheme.muted)
                } else {
                    ForEach(appState.workspace.grades.missingItems, id: \.self) { item in
                        Label(item, systemImage: "exclamationmark.circle")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(BNBUTheme.ink)
                    }
                }
            }
        }
    }

    private var tracePanel: some View {
        SwissPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("来源追溯")
                    .font(.headline.weight(.black))
                Text(appState.workspace.grades.sourceTrace)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BNBUTheme.muted)
                    .lineSpacing(4)
            }
        }
    }

    private var gradeComponents: [GradeComponentSummary] {
        [
            GradeComponentSummary(title: "体育打卡", score: appState.workspace.grades.checkinScore, weight: 0.25, systemImage: "checklist", note: "仅统计已通过和系统抵扣小时"),
            GradeComponentSummary(title: "专项考试", score: appState.workspace.grades.exam, weight: 0.30, systemImage: "figure.badminton", note: "由任课老师录入专项成绩"),
            GradeComponentSummary(title: "平时表现 / 签到", score: appState.workspace.grades.attendance, weight: 0.20, systemImage: "person.crop.rectangle.stack", note: "课堂签到与平时表现"),
            GradeComponentSummary(title: "体测", score: appState.workspace.grades.physical, weight: 0.25, systemImage: "stopwatch", note: "体测数据录入后参与计算")
        ]
    }

    private var weightedTotal: Double {
        gradeComponents.reduce(0) { partialResult, component in
            partialResult + component.contribution
        }
    }
}

private struct GradeComponentSummary: Identifiable, Hashable {
    var id: String { title }
    let title: String
    let score: Int
    let weight: Double
    let systemImage: String
    let note: String

    var weightText: String {
        "\(Int(weight * 100))%"
    }

    var contribution: Double {
        Double(score) * weight
    }

    var contributionText: String {
        String(format: "%.1f", contribution)
    }
}

private struct GradeComponentCard: View {
    let component: GradeComponentSummary

    var body: some View {
        SwissPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: component.systemImage)
                        .font(.title3.weight(.black))
                        .foregroundStyle(BNBUTheme.blue)
                    Spacer()
                    StatusBadge(text: component.weightText)
                }

                Text(component.title)
                    .font(.headline.weight(.black))
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(component.score)")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(BNBUTheme.ink)

                HourProgressBar(value: Double(component.score), total: 100)

                Text(component.note)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BNBUTheme.muted)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct GradeContributionRow: View {
    let component: GradeComponentSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(component.title)
                    .font(.subheadline.weight(.black))
                Spacer()
                Text("\(component.score) x \(component.weightText) = \(component.contributionText)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BNBUTheme.muted)
            }
            HourProgressBar(value: component.contribution, total: 30)
        }
    }
}
