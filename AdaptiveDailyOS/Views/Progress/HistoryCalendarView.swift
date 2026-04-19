import SwiftUI
import SwiftData

struct HistoryCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allHabits: [DailyHabit]

    @State private var monthAnchor: Date = Calendar.current.startOfDay(for: Date())
    @State private var dayDetail: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    monthHeader
                    weekdayHeader
                    monthGrid
                    legend
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { dayDetail.map { IdentifiableDate(date: $0) } },
                set: { dayDetail = $0?.date }
            )) { wrapper in
                DayDetailSheet(date: wrapper.date)
            }
        }
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.footnote.weight(.semibold))
                    .padding(6)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            Text(monthTitle)
                .font(.headline)

            Spacer()

            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .padding(6)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isCurrentMonthOrLater)
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Grid

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(monthCells) { cell in
                DayCell(
                    cell: cell,
                    onTap: {
                        if cell.date != nil, cell.total > 0 {
                            dayDetail = cell.date
                        }
                    }
                )
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            Text("Less")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { rate in
                RoundedRectangle(cornerRadius: 4)
                    .fill(HistoryCalendarView.color(for: rate, hasData: true))
                    .frame(width: 14, height: 14)
            }
            Text("More")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Data

    struct DayEntry: Identifiable {
        let id = UUID()
        let date: Date?
        let dayNumber: Int?
        let completed: Int
        let total: Int
        let isToday: Bool

        var rate: Double { total == 0 ? 0 : Double(completed) / Double(total) }
    }

    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2 // Monday
        return c
    }

    private var weekdaySymbols: [String] {
        // Start from Monday to match firstWeekday
        let base = calendar.shortStandaloneWeekdaySymbols
        let reordered = Array(base[1...]) + [base[0]]
        return reordered
    }

    private var monthTitle: String {
        monthAnchor.formatted(.dateTime.month(.wide).year())
    }

    private var isCurrentMonthOrLater: Bool {
        let today = calendar.startOfDay(for: Date())
        let anchorComps = calendar.dateComponents([.year, .month], from: monthAnchor)
        let todayComps = calendar.dateComponents([.year, .month], from: today)
        if anchorComps.year == todayComps.year {
            return (anchorComps.month ?? 0) >= (todayComps.month ?? 0)
        }
        return (anchorComps.year ?? 0) > (todayComps.year ?? 0)
    }

    private func shiftMonth(_ delta: Int) {
        if delta > 0 && isCurrentMonthOrLater { return }
        if let next = calendar.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = next
        }
    }

    private var monthCells: [DayEntry] {
        let comps = calendar.dateComponents([.year, .month], from: monthAnchor)
        guard let firstOfMonth = calendar.date(from: comps),
              let monthRange = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        // Weekday of the 1st, adjusted so Monday = 0.
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        let today = calendar.startOfDay(for: Date())
        var cells: [DayEntry] = []

        for _ in 0..<leadingBlanks {
            cells.append(DayEntry(date: nil, dayNumber: nil, completed: 0, total: 0, isToday: false))
        }

        for day in monthRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) else { continue }
            let habitsOnDay = allHabits.filter { calendar.isDate($0.scheduledDate, inSameDayAs: date) }
            let completed = habitsOnDay.filter { $0.status == .completed }.count
            cells.append(DayEntry(
                date: date,
                dayNumber: day,
                completed: completed,
                total: habitsOnDay.count,
                isToday: calendar.isDate(date, inSameDayAs: today)
            ))
        }

        // Trailing blanks to complete the final row.
        let remainder = cells.count % 7
        if remainder != 0 {
            for _ in 0..<(7 - remainder) {
                cells.append(DayEntry(date: nil, dayNumber: nil, completed: 0, total: 0, isToday: false))
            }
        }
        return cells
    }

    static func color(for rate: Double, hasData: Bool) -> Color {
        guard hasData else { return Color(.tertiarySystemFill) }
        let opacity = 0.15 + 0.75 * rate
        return Color.accentColor.opacity(opacity)
    }
}

private struct DayCell: View {
    let cell: HistoryCalendarView.DayEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(HistoryCalendarView.color(for: cell.rate, hasData: cell.total > 0))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(cell.isToday ? Color.accentColor : .clear, lineWidth: 2)
                    )
                if let number = cell.dayNumber {
                    Text("\(number)")
                        .font(.caption2)
                        .fontWeight(cell.isToday ? .bold : .regular)
                        .foregroundStyle(cell.total > 0 && cell.rate > 0.5 ? .white : .primary)
                }
            }
            .frame(height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(cell.date == nil || cell.total == 0)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let date = cell.date else { return "Empty" }
        let dateLabel = date.formatted(.dateTime.month().day())
        if cell.total == 0 { return "\(dateLabel), no habits" }
        return "\(dateLabel), \(cell.completed) of \(cell.total) completed"
    }
}

private struct IdentifiableDate: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

#Preview {
    HistoryCalendarView()
        .modelContainer(for: [HabitTemplate.self, DailyHabit.self, CompletionLog.self], inMemory: true)
}
