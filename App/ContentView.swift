import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var stats = FoldStore.shared.load()
    @State private var confirmingReset = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Side by side on the inner display, stacked on the outer one.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 48)], spacing: 16) {
                        CountCard(title: "Today", count: stats.count(on: Date()))
                        CountCard(title: "All time", count: stats.total, footnote: sinceText)
                    }
                    recentDays
                    setupSteps
                }
                .padding()
                .animation(.default, value: stats)
            }
            .navigationTitle("Fold Counter")
            .toolbar { moreMenu }
            .confirmationDialog("Reset all counts?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    FoldStore.shared.reset()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            } message: {
                Text("This clears today's and all-time counts and can't be undone.")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: FoldStore.didChange).receive(on: RunLoop.main)) { _ in
            reload()
        }
    }

    private var sinceText: String? {
        stats.firstEvent.map { "Since \($0.formatted(date: .abbreviated, time: .omitted))" }
    }

    private var recentDays: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last 7 days").font(.headline)
            ForEach(stats.recentDays(7, endingOn: Date())) { day in
                HStack {
                    Text(day.date, format: .dateTime.weekday(.wide).month().day())
                    Spacer()
                    Text("\(day.count.opens) opens · \(day.count.closes) closes")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
    }

    private var setupSteps: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Count every fold automatically").font(.headline)
            Text("iOS only lets apps see the hinge while they're on screen, so a Shortcuts automation does the counting on every open and close.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text("1. In Shortcuts, start a new shortcut.")
                Text("2. Add the When iPhone is Opened trigger.")
                Text("3. Leave Automation on and turn Notify off.")
                Text("4. Add the Log Fold Open action from Fold Counter.")
                Text("5. Make a second one for Closed with Log Fold Close.")
            }
            .font(.subheadline)
            Button("Open Shortcuts") {
                openURL(URL(string: "shortcuts://")!)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var moreMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Add an Open", systemImage: "plus") { FoldStore.shared.log(.open) }
                Button("Add a Close", systemImage: "plus") { FoldStore.shared.log(.close) }
                Divider()
                Button("Reset All Counts…", systemImage: "trash", role: .destructive) { confirmingReset = true }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

    private func reload() {
        stats = FoldStore.shared.load()
    }
}

private struct CountCard: View {
    let title: String
    let count: DayCount
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).foregroundStyle(.secondary)
            HStack(spacing: 32) {
                number(count.opens, label: "Opens", symbol: "book")
                number(count.closes, label: "Closes", symbol: "book.closed")
            }
            if let footnote {
                Text(footnote).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func number(_ value: Int, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Label(label, systemImage: symbol)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
