import Foundation

struct StreakCalculator {

    struct StreakResult {
        let currentStreak: Int
        let longestStreak: Int
    }

    static func streak(for template: HabitTemplate) -> StreakResult {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let createdDay = calendar.startOfDay(for: template.createdAt)

        let completedDays = Set(
            template.dailyHabits
                .filter { $0.status == .completed }
                .map { calendar.startOfDay(for: $0.scheduledDate) }
        )
        let skippedDays = Set(
            template.dailyHabits
                .filter { $0.status == .skipped }
                .map { calendar.startOfDay(for: $0.scheduledDate) }
        )

        var currentStreak = 0
        var checkDate = today

        while checkDate >= createdDay {
            let isScheduled = isTemplateScheduled(template, on: checkDate)

            if !isScheduled {
                // Weekend for a weekday habit, etc. — transparent, skip over silently.
            } else if completedDays.contains(checkDate) || skippedDays.contains(checkDate) {
                // Completed and skipped both count toward streak length.
                currentStreak += 1
            } else if checkDate == today {
                // Today is still pending — don't penalise; just don't count it.
            } else {
                // Scheduled, past day, not completed or skipped — streak is broken.
                break
            }

            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previous
        }

        let longestStreak = computeLongestStreak(
            for: template,
            completedDays: completedDays,
            skippedDays: skippedDays
        )

        return StreakResult(currentStreak: currentStreak, longestStreak: longestStreak)
    }

    static func allStreaks(for templates: [HabitTemplate]) -> [UUID: StreakResult] {
        Dictionary(uniqueKeysWithValues: templates.map { ($0.id, streak(for: $0)) })
    }

    // MARK: - Private

    private static func isTemplateScheduled(_ template: HabitTemplate, on date: Date) -> Bool {
        switch template.frequency {
        case .daily:    return true
        case .weekdays: return !Calendar.current.isDateInWeekend(date)
        case .weekends: return Calendar.current.isDateInWeekend(date)
        case .custom:   return true
        }
    }

    private static func computeLongestStreak(
        for template: HabitTemplate,
        completedDays: Set<Date>,
        skippedDays: Set<Date>
    ) -> Int {
        guard !template.dailyHabits.isEmpty else { return 0 }

        let calendar = Calendar.current
        let createdDay = calendar.startOfDay(for: template.createdAt)
        let today = calendar.startOfDay(for: Date())

        var longest = 0
        var current = 0
        var checkDate = createdDay

        while checkDate <= today {
            let isScheduled = isTemplateScheduled(template, on: checkDate)

            if !isScheduled {
                // Transparent — neither extend nor reset.
            } else if completedDays.contains(checkDate) || skippedDays.contains(checkDate) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: checkDate) else { break }
            checkDate = next
        }

        return longest
    }
}
