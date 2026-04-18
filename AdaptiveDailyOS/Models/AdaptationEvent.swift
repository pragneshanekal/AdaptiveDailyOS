import Foundation
import SwiftData

@Model
final class AdaptationEvent {
    var id: UUID
    var occurredAt: Date
    var habitTemplateId: UUID?
    var habitName: String
    var triggerReason: String
    var beforeState: String
    var afterState: String
    var accepted: Bool

    var plan: WeeklyPlan?

    init(
        id: UUID = UUID(),
        occurredAt: Date = Date(),
        habitTemplateId: UUID? = nil,
        habitName: String,
        triggerReason: String,
        beforeState: String,
        afterState: String,
        accepted: Bool = false,
        plan: WeeklyPlan? = nil
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.habitTemplateId = habitTemplateId
        self.habitName = habitName
        self.triggerReason = triggerReason
        self.beforeState = beforeState
        self.afterState = afterState
        self.accepted = accepted
        self.plan = plan
    }
}
