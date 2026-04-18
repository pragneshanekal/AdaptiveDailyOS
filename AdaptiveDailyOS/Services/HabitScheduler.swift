import Foundation
import SwiftData

struct SuggestedHabit: Identifiable {
    let id: UUID
    let name: String
    let category: HabitCategory
    let targetValue: Double
    let unit: String
    let frequency: HabitFrequency
    let difficultyScore: Int

    init(
        name: String,
        category: HabitCategory,
        targetValue: Double,
        unit: String,
        frequency: HabitFrequency,
        difficultyScore: Int
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.targetValue = targetValue
        self.unit = unit
        self.frequency = frequency
        self.difficultyScore = difficultyScore
    }
}

struct HabitScheduler {

    static let suggestedHabits: [SuggestedHabit] = [
        SuggestedHabit(name: "Morning Run",        category: .fitness,      targetValue: 30,  unit: "minutes",  frequency: .daily,    difficultyScore: 3),
        SuggestedHabit(name: "Drink Water",         category: .health,       targetValue: 8,   unit: "glasses",  frequency: .daily,    difficultyScore: 1),
        SuggestedHabit(name: "Read",                category: .learning,     targetValue: 20,  unit: "minutes",  frequency: .daily,    difficultyScore: 2),
        SuggestedHabit(name: "Meditate",            category: .mindfulness,  targetValue: 10,  unit: "minutes",  frequency: .daily,    difficultyScore: 2),
        SuggestedHabit(name: "Journal",             category: .mindfulness,  targetValue: 10,  unit: "minutes",  frequency: .daily,    difficultyScore: 1),
        SuggestedHabit(name: "Strength Training",   category: .fitness,      targetValue: 45,  unit: "minutes",  frequency: .weekdays, difficultyScore: 4),
        SuggestedHabit(name: "Walk",                category: .health,       targetValue: 30,  unit: "minutes",  frequency: .daily,    difficultyScore: 1),
        SuggestedHabit(name: "Study",               category: .learning,     targetValue: 60,  unit: "minutes",  frequency: .weekdays, difficultyScore: 3),
        SuggestedHabit(name: "Call a Friend",       category: .social,       targetValue: 1,   unit: "call",     frequency: .weekends, difficultyScore: 1),
        SuggestedHabit(name: "Deep Work",           category: .productivity, targetValue: 90,  unit: "minutes",  frequency: .weekdays, difficultyScore: 4),
    ]

    // Returns templates that should be scheduled on a given date based on their frequency.
    static func templatesScheduled(for date: Date, templates: [HabitTemplate]) -> [HabitTemplate] {
        templates.filter { template in
            guard template.active else { return false }
            switch template.frequency {
            case .daily:    return true
            case .weekdays: return !Calendar.current.isDateInWeekend(date)
            case .weekends: return Calendar.current.isDateInWeekend(date)
            case .custom:   return true
            }
        }
    }

    // Inserts DailyHabit rows for today's active templates. Idempotent — skips
    // any template that already has a row for `date`.
    static func scheduleHabitsForDate(_ date: Date, context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: date)

        let allTemplates = (try? context.fetch(FetchDescriptor<HabitTemplate>())) ?? []
        let scheduled = templatesScheduled(for: startOfDay, templates: allTemplates)

        let existingHabits = (try? context.fetch(FetchDescriptor<DailyHabit>())) ?? []
        let alreadyScheduledTemplateIds = Set(
            existingHabits
                .filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: startOfDay) }
                .compactMap { $0.template?.id }
        )

        let activePlanTargets = planTargets(on: startOfDay, context: context)

        for template in scheduled where !alreadyScheduledTemplateIds.contains(template.id) {
            let planned = activePlanTargets[template.id]
            let adaptedTarget = planned?.target ?? template.targetValue
            let adaptedReason = planned?.reason ?? ""
            let dailyHabit = DailyHabit(
                scheduledDate: startOfDay,
                adaptedTarget: adaptedTarget,
                adaptedReason: adaptedReason,
                template: template
            )
            context.insert(dailyHabit)
        }
    }

    // If an accepted weekly plan covers `date`, returns per-template target
    // overrides from that plan. Unknown template ids in the plan are ignored.
    private static func planTargets(on date: Date, context: ModelContext) -> [UUID: (target: Double, reason: String)] {
        guard let plan = WeeklyPlanService.activePlan(on: date, context: context) else { return [:] }
        guard let data = plan.aiPlanSnapshot.data(using: .utf8) else { return [:] }
        guard let decoded = try? JSONDecoder().decode(PlanSuggestion.self, from: data) else { return [:] }

        var result: [UUID: (Double, String)] = [:]
        for habit in decoded.habits {
            result[habit.templateId] = (habit.suggestedTarget, habit.rationale)
        }
        return result
    }

    // Marks any DailyHabits from before `date` that are still .pending as .missed.
    static func markMissedHabits(before date: Date, context: ModelContext) {
        let startOfToday = Calendar.current.startOfDay(for: date)
        let allHabits = (try? context.fetch(FetchDescriptor<DailyHabit>())) ?? []

        for habit in allHabits
        where habit.scheduledDate < startOfToday && habit.status == .pending {
            habit.status = .missed
        }
    }
}
