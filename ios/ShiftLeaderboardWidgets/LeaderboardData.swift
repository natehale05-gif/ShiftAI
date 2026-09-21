import WidgetKit

/// The App Group this extension shares with Runner. Must match
/// lib/features/widgets/widget_sync.dart's appGroupId exactly, and the
/// value in this file's own entitlements and Runner's.
let appGroupId = "group.club.shiftai.app"

/// One flat read of whatever widget_sync.dart last wrote — the same key
/// names as RankWidgetProvider.kt et al. on Android, since it is the same
/// Flutter code writing both sides.
struct LeaderboardEntry: TimelineEntry {
    let date: Date
    let youRank: String?
    let youEarnings: String?
    let youMovement: Int
    let podium: [(name: String, earnings: String)?]
    let targetName: String?
    let targetGap: String?
    let chaserName: String?
    let chaserGap: String?
}

func readLeaderboardEntry() -> LeaderboardEntry {
    let d = UserDefaults(suiteName: appGroupId)

    func podiumSpot(_ rank: Int) -> (name: String, earnings: String)? {
        guard let name = d?.string(forKey: "podium_\(rank)_name") else { return nil }
        return (name, d?.string(forKey: "podium_\(rank)_earnings") ?? "")
    }

    return LeaderboardEntry(
        date: Date(),
        youRank: d?.string(forKey: "you_rank"),
        youEarnings: d?.string(forKey: "you_earnings"),
        youMovement: Int(d?.string(forKey: "you_movement") ?? "") ?? 0,
        podium: [podiumSpot(1), podiumSpot(2), podiumSpot(3)],
        targetName: d?.string(forKey: "target_name"),
        targetGap: d?.string(forKey: "target_gap"),
        chaserName: d?.string(forKey: "chaser_name"),
        chaserGap: d?.string(forKey: "chaser_gap")
    )
}

/// Shared by all three widgets. There is no periodic OS-driven refresh —
/// widget_sync.dart calls WidgetCenter.reloadTimelines whenever the app
/// has fresh data, so a single entry with policy .never is correct here;
/// it means "wait to be told", not "never update".
struct LeaderboardProvider: TimelineProvider {
    func placeholder(in context: Context) -> LeaderboardEntry {
        LeaderboardEntry(
            date: Date(),
            youRank: "13",
            youEarnings: "767.09",
            youMovement: 1,
            podium: [
                ("Marisol Vega", "11,727.62"),
                ("Tomas Lindqvist", "7,471.62"),
                ("Dee Okonkwo", "6,083.49"),
            ],
            targetName: "Owen Mbeki",
            targetGap: "186.74",
            chaserName: "Lena Duval",
            chaserGap: "27.34"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LeaderboardEntry) -> Void) {
        completion(readLeaderboardEntry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<LeaderboardEntry>) -> Void
    ) {
        completion(Timeline(entries: [readLeaderboardEntry()], policy: .never))
    }
}
