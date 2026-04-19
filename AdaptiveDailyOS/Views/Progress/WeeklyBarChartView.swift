import SwiftUI
import SwiftData
import Charts

struct WeeklyBarChartView: View {
    @Query private var allHabits: [DailyHabit]

    // Offset in weeks from the current week: 0 = this week, -1 = last week.
    @State private var weekOffset: Int = 0
    @State private var dayDetail: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if dailyData.allSatisfy({ $0.total == 0 }) {
                Text(weekOffset == 0 ? "No habits logged this week yet." : "No habits logged this week.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                chart
                weekSummary
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .sheet(item: Binding(
            get: { dayDetail.map { IdentifiableDate(date: $0) } },
            set: { dayDetail = $0?.date }
        )) { wrapper in
            DayDetailSheet(date: wrapper.date)
        }
    }

    private var header: some View {
        HStack {
            Button {
                weekOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .font(.footnote.weight(.semibold))
                    .padding(6)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Previous week")

            Spacer()

            VStack(spacing: 2) {
                Text(weekTitle)
                    .font(.headline)
                Text(weekRangeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if weekOffset < 0 { weekOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .padding(6)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(weekOffset >= 0)
            .accessibilityLabel("Next week")
        }
    }

    private var chart: some View {
        Chart {
            ForEach(dailyData) { day in
                BarMark(
                    x: .value("Day", day.label),
                    y: .value("Completion", day.rate)
                )
                .foregroundStyle(
                    day.isToday
                        ? Color.accentColor
                        : Color.accentColor.opacity(0.45)
                )
                .cornerRadius(6)
            }

            if weeklyAverage > 0 {
                RuleMark(y: .value("Weekly average", weeklyAverage))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color(.secondaryLabel))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("avg \(Int(weeklyAverage * 100))%")
                            .font(.caption2)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
            }
        }
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(values: [0, 0.5, 1]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let rate = value.as(Double.self) {
                        Text("\(Int(rate * 100))%")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let xInPlot = value.location.x - geo[plotFrame].origin.x
                                guard let label: String = proxy.value(atX: xInPlot) else { return }
                                if let day = dailyData.first(where: { $0.label == label }),
                                   day.total > 0 {
                                    dayDetail = day.id
                                }
                            }
                    )
            }
        }
        .frame(height: 180)
        .accessibilityLabel("Weekly completion bar chart. Tap a day to see details.")
    }

    private var weekSummary: some View {
        let totalCompleted = dailyData.reduce(0) { $0 + $1.completed }
        let totalScheduled = dailyData.reduce(0) { $0 + $1.total }
        let rate = totalScheduled == 0 ? 0 : Double(totalCompleted) / Double(totalScheduled)
        return HStack {
            Text("\(totalCompleted) of \(totalScheduled) completed")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(Int(rate * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Data model

    private struct DayData: Identifiable {
        let id: Date
        let label: String
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

    private var weekStart: Date {
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        let thisWeekMonday = calendar.date(from: components) ?? today
        return calendar.date(byAdding: .day, value: weekOffset * 7, to: thisWeekMonday) ?? thisWeekMonday
    }

    private var weekTitle: String {
        switch weekOffset {
        case 0: return "This Week"
        case -1: return "Last Week"
        default: return "Week of \(weekStart.formatted(.dateTime.month().day()))"
        }
    }

    private var weekRangeLabel: String {
        let end = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let startStr = weekStart.formatted(.dateTime.month(.abbreviated).day())
        let endStr = end.formatted(.dateTime.month(.abbreviated).day())
        return "\(startStr) – \(endStr)"
    }

    private var dailyData: [DayData] {
        let start = weekStart
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            let habitsOnDay = allHabits.filter { calendar.isDate($0.scheduledDate, inSameDayAs: date) }
            let completed = habitsOnDay.filter { $0.status == .completed }.count
            return DayData(
                id: date,
                label: date.formatted(.dateTime.weekday(.narrow)),
                completed: completed,
                total: habitsOnDay.count,
                isToday: calendar.isDateInToday(date)
            )
        }
    }

    private var weeklyAverage: Double {
        let days = dailyData.filter { $0.total > 0 }
        guard !days.isEmpty else { return 0 }
        return days.map(\.rate).reduce(0, +) / Double(days.count)
    }
}

private struct IdentifiableDate: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

#Preview {
    WeeklyBarChartView()
        .padding()
        .modelContainer(for: [HabitTemplate.self, DailyHabit.self, CompletionLog.self], inMemory: true)
}
