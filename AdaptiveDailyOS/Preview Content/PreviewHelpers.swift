#if DEBUG
import Foundation
import SwiftData

enum PreviewHelpers {

    /// Inserts 3 habit templates and 7 days of realistic completion logs into the given context.
    @discardableResult
    static func insertSampleData(into context: ModelContext) -> [HabitTemplate] {
        let calendar = Calendar.current

        let templates: [(name: String, category: HabitCategory, target: Double, unit: String, frequency: HabitFrequency, difficulty: Int)] = [
            ("Morning Run",   .fitness,      30, "minutes", .daily,    3),
            ("Drink Water",   .health,        8, "glasses",  .daily,    1),
            ("Read",          .learning,     20, "minutes", .daily,    2),
        ]

        var inserted: [HabitTemplate] = []

        for t in templates {
            let template = HabitTemplate(
                name: t.name,
                category: t.category,
                targetValue: t.target,
                unit: t.unit,
                frequency: t.frequency,
                difficultyScore: t.difficulty,
                createdAt: calendar.date(byAdding: .day, value: -7, to: Date())!
            )
            context.insert(template)
            inserted.append(template)

            // Add 7 days of history with a mix of statuses.
            for daysAgo in (0...6).reversed() {
                let date = calendar.startOfDay(
                    for: calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
                )

                let status: DailyHabitStatus
                if daysAgo == 0 {
                    // Today: first template done, others pending
                    status = (t.name == "Morning Run") ? .completed : .pending
                } else if daysAgo == 3 {
                    status = .skipped
                } else {
                    status = .completed
                }

                let habit = DailyHabit(
                    scheduledDate: date,
                    adaptedTarget: t.target,
                    template: template
                )
                habit.status = status
                context.insert(habit)

                if status == .completed {
                    let log = CompletionLog(
                        completedAt: date,
                        valueLogged: t.target,
                        dailyHabit: habit
                    )
                    context.insert(log)
                }
            }
        }

        return inserted
    }
}
#endif
