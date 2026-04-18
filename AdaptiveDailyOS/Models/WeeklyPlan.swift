import Foundation
import SwiftData

@Model
final class WeeklyPlan {
    var id: UUID
    var weekStart: Date
    var aiPlanSnapshot: String
    var predictedRate: Double
    var actualRate: Double
    var acceptedAt: Date?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \AdaptationEvent.plan)
    var adaptationEvents: [AdaptationEvent] = []

    init(
        id: UUID = UUID(),
        weekStart: Date,
        aiPlanSnapshot: String,
        predictedRate: Double,
        actualRate: Double = 0,
        acceptedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.weekStart = weekStart
        self.aiPlanSnapshot = aiPlanSnapshot
        self.predictedRate = predictedRate
        self.actualRate = actualRate
        self.acceptedAt = acceptedAt
        self.createdAt = createdAt
    }
}
