import SwiftUI
import SwiftData

struct DayDetailSheet: View {
    let date: Date

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var habits: [DailyHabit]

    init(date: Date) {
        self.date = date
        let startOfDay = Calendar.current.startOfDay(for: date)
        let startOfNextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        _habits = Query(
            filter: #Predicate<DailyHabit> { habit in
                habit.scheduledDate >= startOfDay && habit.scheduledDate < startOfNextDay
            },
            sort: \DailyHabit.scheduledDate
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if habits.isEmpty {
                    ContentUnavailableView(
                        "No habits",
                        systemImage: "calendar",
                        description: Text("Nothing was scheduled on this day.")
                    )
                } else {
                    List {
                        Section {
                            summaryRow
                        }
                        Section("Habits") {
                            ForEach(habits) { habit in
                                DayHabitRow(habit: habit)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var title: String {
        date.formatted(.dateTime.weekday(.wide).month().day())
    }

    private var summaryRow: some View {
        let completed = habits.filter { $0.status == .completed }.count
        let total = habits.count
        let rate = total == 0 ? 0 : Int(Double(completed) / Double(total) * 100)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(completed) of \(total) completed")
                    .font(.body)
                    .fontWeight(.medium)
                Text("\(rate)% completion")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct DayHabitRow: View {
    let habit: DailyHabit

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.template?.name ?? "Habit")
                    .font(.body)
                Text(valueLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var statusIcon: some View {
        Group {
            switch habit.status {
            case .completed:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
            case .skipped:
                Image(systemName: "arrow.uturn.right.circle.fill").foregroundStyle(.secondary)
            case .missed:
                Image(systemName: "xmark.circle.fill").foregroundStyle(Color(.systemRed))
            case .pending:
                Image(systemName: "circle").foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .font(.title3)
    }

    private var valueLabel: String {
        let unit = habit.template?.unit ?? ""
        let target = habit.adaptedTarget
        if habit.status == .completed, let logged = latestLoggedValue {
            if logged == target { return "\(format(logged)) \(unit)" }
            return "\(format(logged)) \(unit) · target \(format(target))"
        }
        return "target \(format(target)) \(unit) · \(habit.status.rawValue)"
    }

    private var latestLoggedValue: Double? {
        habit.completionLogs.sorted { $0.completedAt > $1.completedAt }.first?.valueLogged
    }

    private func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}
