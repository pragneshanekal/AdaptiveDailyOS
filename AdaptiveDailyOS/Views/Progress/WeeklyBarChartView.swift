import SwiftUI
import SwiftData
import Charts

struct WeeklyBarChartView: View {
    @Query private var recentHabits: [DailyHabit]

    init() {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday)!
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        _recentHabits = Query(
            filter: #Predicate<DailyHabit> { habit in
                habit.scheduledDate >= sevenDaysAgo && habit.scheduledDate < startOfTomorrow
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week")
                .font(.headline)

            if dailyData.allSatisfy({ $0.total == 0 }) {
                Text("No habits logged this week yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
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
                .frame(height: 180)
                .accessibilityLabel("Weekly completion bar chart")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
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

    private var dailyData: [DayData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: -(6 - offset), to: today)!
            let habitsOnDay = recentHabits.filter { calendar.isDate($0.scheduledDate, inSameDayAs: date) }
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

#Preview {
    WeeklyBarChartView()
        .padding()
        .modelContainer(for: [HabitTemplate.self, DailyHabit.self, CompletionLog.self], inMemory: true)
}
