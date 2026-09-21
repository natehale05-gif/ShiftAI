import SwiftUI
import WidgetKit

struct RankWidgetView: View {
    var entry: LeaderboardEntry

    var body: some View {
        VStack(spacing: 4) {
            if let rank = entry.youRank {
                Text("#\(rank)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(WidgetTheme.accent)
                Text("RANK")
                    .font(.system(size: 10))
                    .tracking(1.2)
                    .foregroundColor(WidgetTheme.textMuted)
                if let earnings = entry.youEarnings {
                    Text("$\(earnings)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(WidgetTheme.text)
                        .padding(.top, 6)
                }
                if entry.youMovement != 0 {
                    Text(movementLabel(entry.youMovement))
                        .font(.system(size: 11))
                        .foregroundColor(entry.youMovement > 0 ? WidgetTheme.success : WidgetTheme.danger)
                }
            } else {
                Image(systemName: "person")
                    .foregroundColor(WidgetTheme.textMuted)
                Text("OPEN SHIFT AI")
                    .font(.system(size: 10))
                    .tracking(1.2)
                    .foregroundColor(WidgetTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetBackground(WidgetTheme.background)
    }
}

struct RankWidget: Widget {
    let kind: String = "RankWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LeaderboardProvider()) { entry in
            RankWidgetView(entry: entry)
        }
        .configurationDisplayName("Your rank")
        .description("Your rank and this week's earnings.")
        .supportedFamilies([.systemSmall])
    }
}
