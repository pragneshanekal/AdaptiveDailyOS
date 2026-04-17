import Testing
import SwiftData
import Foundation
@testable import AdaptiveDailyOS

@Suite("HabitScheduler")
struct HabitSchedulerTests {

    // Builds an in-memory container and returns its main context.
    private func makeContext() throws -> ModelContext {
        let schema = Schema([HabitTemplate.self, DailyHabit.self, CompletionLog.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test("scheduleHabitsForDate is idempotent — calling twice creates exactly N rows")
    func schedulingIsIdempotent() throws {
        let context = try makeContext()
        let template = HabitTemplate(name: "Run", category: .fitness, targetValue: 30,
                                     unit: "minutes", frequency: .daily, difficultyScore: 2)
        context.insert(template)

        let today = Date()
        HabitScheduler.scheduleHabitsForDate(today, context: context)
        HabitScheduler.scheduleHabitsForDate(today, context: context)

        let habits = try context.fetch(FetchDescriptor<DailyHabit>())
        #expect(habits.count == 1)
    }

    @Test("Weekday-only habit is not scheduled on a Saturday")
    func weekdayHabitSkippedOnWeekend() throws {
        let context = try makeContext()
        let template = HabitTemplate(name: "Study", category: .learning, targetValue: 60,
                                     unit: "minutes", frequency: .weekdays, difficultyScore: 3)
        context.insert(template)

        // Find the next Saturday relative to a known Monday.
        let saturday = nextSaturday()
        HabitScheduler.scheduleHabitsForDate(saturday, context: context)

        let habits = try context.fetch(FetchDescriptor<DailyHabit>())
        #expect(habits.isEmpty)
    }

    // MARK: - Helpers

    private func nextSaturday() -> Date {
        var components = DateComponents()
        components.weekday = 7 // Saturday
        return Calendar.current.nextDate(
            after: Date(),
            matching: components,
            matchingPolicy: .nextTime
        ) ?? Date()
    }
}
