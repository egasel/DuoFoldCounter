import SwiftUI
import WidgetKit

struct FoldEntry: TimelineEntry {
    let date: Date
    let stats: FoldStats

    var today: DayCount { stats.count(on: date) }
}

struct FoldProvider: TimelineProvider {
    func placeholder(in context: Context) -> FoldEntry {
        var stats = FoldStats()
        stats.days[FoldStats.dayKey(for: Date())] = DayCount(opens: 24, closes: 23)
        return FoldEntry(date: Date(), stats: stats)
    }

    func getSnapshot(in context: Context, completion: @escaping (FoldEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : FoldEntry(date: Date(), stats: FoldStore.shared.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FoldEntry>) -> Void) {
        let now = Date()
        let stats = FoldStore.shared.load()
        // A second entry at midnight so "today" goes back to zero even if the phone isn't folded.
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        let entries = [FoldEntry(date: now, stats: stats), FoldEntry(date: midnight, stats: stats)]
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct FoldWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FoldEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(entry.today.opens) opens · \(entry.today.closes) closes")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("Folds today").font(.headline)
                Text("\(entry.today.opens) opens · \(entry.today.closes) closes")
                Text("All time \(entry.stats.total.opens) · \(entry.stats.total.closes)")
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
        case .systemMedium:
            HStack(alignment: .top, spacing: 16) {
                CountColumn(title: "Today", count: entry.today)
                Divider()
                CountColumn(title: "All time", count: entry.stats.total)
            }
        default:
            CountColumn(title: "Today", count: entry.today, total: entry.stats.total)
        }
    }
}

private struct CountColumn: View {
    let title: String
    let count: DayCount
    var total: DayCount?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            row(count.opens, "opens")
            row(count.closes, "closes")
            if let total {
                Spacer(minLength: 0)
                Text("All time \(total.opens) · \(total.closes)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .monospacedDigit()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ value: Int, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value, format: .number)
                .font(.title.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

@main
struct FoldCounterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FoldCounterWidget", provider: FoldProvider()) { entry in
            FoldWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Fold Counter")
        .description("Today's opens and closes, plus the all-time total.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}
