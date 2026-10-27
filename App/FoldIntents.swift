import AppIntents
import WidgetKit

// iOS only lets an app watch the hinge while it is on screen, so counting is driven by
// Shortcuts: the "When iPhone is Opened / Closed" trigger runs these intents in the
// background on every fold, whether or not the app is open.

struct LogFoldOpenIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Fold Open"
    static let description = IntentDescription(
        "Adds one open to today's count and the all-time total. Run it from the When iPhone is Opened trigger."
    )
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let stats = FoldStore.shared.log(.open)
        return .result(value: stats.count(on: Date()).opens)
    }
}

struct LogFoldCloseIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Fold Close"
    static let description = IntentDescription(
        "Adds one close to today's count and the all-time total. Run it from the When iPhone is Closed trigger."
    )
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let stats = FoldStore.shared.log(.close)
        return .result(value: stats.count(on: Date()).closes)
    }
}

struct FoldCounterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogFoldOpenIntent(),
            phrases: ["Log a fold open in \(.applicationName)"],
            shortTitle: "Log Fold Open",
            systemImageName: "book"
        )
        AppShortcut(
            intent: LogFoldCloseIntent(),
            phrases: ["Log a fold close in \(.applicationName)"],
            shortTitle: "Log Fold Close",
            systemImageName: "book.closed"
        )
    }
}

extension FoldStore {
    /// Records the event and asks WidgetKit to redraw the widget with the new counts.
    @discardableResult
    func log(_ event: FoldEvent) -> FoldStats {
        defer { WidgetCenter.shared.reloadAllTimelines() }
        return record(event)
    }
}
