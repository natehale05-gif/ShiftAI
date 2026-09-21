import SwiftUI
import WidgetKit

private struct PodiumSpot: View {
    let name: String
    let earnings: String
    let lead: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.system(size: lead ? 13 : 12, weight: lead ? .bold : .regular))
                .foregroundColor(lead ? WidgetTheme.accent : WidgetTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(earnings.isEmpty ? "" : "$\(earnings)")
                .font(.system(size: lead ? 12 : 11, weight: lead ? .bold : .regular))
                .foregroundColor(lead ? WidgetTheme.text : WidgetTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PodiumWidgetView: View {
    var entry: LeaderboardEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LEADERBOARD")
                .font(.system(size: 10))
                .tracking(1.2)
                .foregroundColor(WidgetTheme.textMuted)
            HStack(alignment: .bottom, spacing: 8) {
                PodiumSpot(name: entry.podium[1]?.name ?? "—", earnings: entry.podium[1]?.earnings ?? "", lead: false)
                PodiumSpot(name: entry.podium[0]?.name ?? "—", earnings: entry.podium[0]?.earnings ?? "", lead: true)
                PodiumSpot(name: entry.podium[2]?.name ?? "—", earnings: entry.podium[2]?.earnings ?? "", lead: false)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackground(WidgetTheme.background)
    }
}

struct PodiumWidget: Widget {
    let kind: String = "PodiumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LeaderboardProvider()) { entry in
            PodiumWidgetView(entry: entry)
        }
        .configurationDisplayName("This week's top 3")
        .description("Who's leading the board this week.")
        .supportedFamilies([.systemMedium])
    }
}
