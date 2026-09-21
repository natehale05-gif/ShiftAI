import SwiftUI
import WidgetKit

private struct RivalRow: View {
    let label: String
    let labelColor: Color
    let name: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .tracking(1.0)
                .foregroundColor(labelColor)
            Text(name)
                .font(.system(size: 13))
                .foregroundColor(WidgetTheme.text)
                .lineLimit(1)
            Text(detail)
                .font(.system(size: 11))
                .foregroundColor(WidgetTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RivalsWidgetView: View {
    var entry: LeaderboardEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RivalRow(
                label: "CATCHING",
                labelColor: WidgetTheme.success,
                name: entry.targetName ?? "Nobody left to catch",
                detail: entry.targetGap.map { "$\($0) away" } ?? ""
            )
            Divider().background(WidgetTheme.textMuted.opacity(0.3))
            RivalRow(
                label: "ON YOUR TAIL",
                labelColor: WidgetTheme.danger,
                name: entry.chaserName ?? "Nobody behind you",
                detail: entry.chaserGap.map { "$\($0) behind" } ?? ""
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackground(WidgetTheme.background)
    }
}

struct RivalsWidget: Widget {
    let kind: String = "RivalsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LeaderboardProvider()) { entry in
            RivalsWidgetView(entry: entry)
        }
        .configurationDisplayName("Rivals")
        .description("Who you're catching, and who's catching you.")
        .supportedFamilies([.systemMedium])
    }
}
