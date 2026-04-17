import Foundation
import SwiftData

@Model
final class DailyHabit {
    var id: UUID
    var scheduledDate: Date
    var adaptedTarget: Double
    var adaptedReason: String
    var status: DailyHabitStatus

    var template: HabitTemplate?

    @Relationship(deleteRule: .cascade, inverse: \CompletionLog.dailyHabit)
    var completionLogs: [CompletionLog] = []

    init(
        id: UUID = UUID(),
        scheduledDate: Date,
        adaptedTarget: Double,
        adaptedReason: String = "",
        status: DailyHabitStatus = .pending,
        template: HabitTemplate? = nil
    ) {
        self.id = id
        self.scheduledDate = scheduledDate
        self.adaptedTarget = adaptedTarget
        self.adaptedReason = adaptedReason
        self.status = status
        self.template = template
    }
}
