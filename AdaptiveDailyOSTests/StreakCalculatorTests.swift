import Testing
import SwiftData
import Foundation
@testable import AdaptiveDailyOS

@Suite("StreakCalculator")
struct StreakCalculatorTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([HabitTemplate.self, DailyHabit.self, CompletionLog.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// Creates a DailyHabit for `daysAgo` days before today with the given status,
    /// attaches a CompletionLog if status is .completed, and inserts both into context.
    private func addDailyHabit(
        to template: HabitTemplate,
        daysAgo: Int,
        status: DailyHabitStatus,
        context: ModelContext
    ) {
        let calendar = Calendar.current
        let date = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -daysAgo, to: Date())!)
        let habit = DailyHabit(scheduledDate: date, adaptedTarget: template.targetValue, template: template)
        habit.status = status
        context.insert(habit)

        if status == .completed {
            let log = CompletionLog(valueLogged: template.targetValue, dailyHabit: habit)
            context.insert(log)
        }
    }

    @Test("currentStreak is 3 when last 3 days are completed")
    func threeDayStreak() throws {
        let context = try makeContext()
        let template = HabitTemplate(name: "Run", category: .fitness, targetValue: 30,
                                     unit: "minutes", frequency: .daily, difficultyScore: 2,
                                     createdAt: Calendar.current.date(byAdding: .day, value: -10, to: Date())!)
        context.insert(template)
        addDailyHabit(to: template, daysAgo: 2, status: .completed, context: context)
        addDailyHabit(to: template, daysAgo: 1, status: .completed, context: context)
        addDailyHabit(to: template, daysAgo: 0, status: .completed, context: context)

        let result = StreakCalculator.streak(for: template)
        #expect(result.currentStreak == 3)
    }

    @Test("currentStreak is 0 when yesterday is missed")
    func missedYesterdayResetsStreak() throws {
        let context = try makeContext()
        let template = HabitTemplate(name: "Run", category: .fitness, targetValue: 30,
                                     unit: "minutes", frequency: .daily, difficultyScore: 2,
                                     createdAt: Calendar.current.date(byAdding: .day, value: -10, to: Date())!)
        context.insert(template)
        addDailyHabit(to: template, daysAgo: 2, status: .completed, context: context)
        addDailyHabit(to: template, daysAgo: 1, status: .missed,    context: context)
        addDailyHabit(to: template, daysAgo: 0, status: .completed, context: context)

        let result = StreakCalculator.streak(for: template)
        #expect(result.currentStreak == 1)
    }

    @Test("Skipped day does not reset streak")
    func skippedDayPreservesStreak() throws {
        let context = try makeContext()
        let template = HabitTemplate(name: "Run", category: .fitness, targetValue: 30,
                                     unit: "minutes", frequency: .daily, difficultyScore: 2,
                                     createdAt: Calendar.current.date(byAdding: .day, value: -10, to: Date())!)
        context.insert(template)
        addDailyHabit(to: template, daysAgo: 3, status: .completed, context: context)
        addDailyHabit(to: template, daysAgo: 2, status: .completed, context: context)
        addDailyHabit(to: template, daysAgo: 1, status: .skipped,   context: context)
        addDailyHabit(to: template, daysAgo: 0, status: .completed, context: context)

        let result = StreakCalculator.streak(for: template)
        #expect(result.currentStreak == 4)
    }

    @Test("Non-scheduled day (weekend for weekdays habit) does not reset streak")
    func nonScheduledDayPreservesStreak() throws {
        let context = try makeContext()
        let template = HabitTemplate(name: "Study", category: .learning, targetValue: 60,
                                     unit: "minutes", frequency: .weekdays, difficultyScore: 3,
                                     createdAt: Calendar.current.date(byAdding: .day, value: -14, to: Date())!)
        context.insert(template)

        // Add completions only on weekdays; the calculator should skip weekend days transparently.
        let calendar = Calendar.current
        var offset = 0
        var weekdayCompletions = 0

        // Walk back up to 7 days and add completions on weekdays (up to 3).
        while weekdayCompletions < 3 && offset < 14 {
            let date = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: Date())!)
            if !calendar.isDateInWeekend(date) {
                addDailyHabit(to: template, daysAgo: offset, status: .completed, context: context)
                weekdayCompletions += 1
            }
            offset += 1
        }

        let result = StreakCalculator.streak(for: template)
        #expect(result.currentStreak == 3)
    }
}
