import Foundation
import SwiftData

@Model
final class HabitTemplate {
    var id: UUID
    var name: String
    var category: HabitCategory
    var targetValue: Double
    var unit: String
    var frequency: HabitFrequency
    var difficultyScore: Int
    var active: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \DailyHabit.template)
    var dailyHabits: [DailyHabit] = []

    init(
        id: UUID = UUID(),
        name: String,
        category: HabitCategory,
        targetValue: Double,
        unit: String,
        frequency: HabitFrequency,
        difficultyScore: Int,
        active: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.targetValue = targetValue
        self.unit = unit
        self.frequency = frequency
        self.difficultyScore = difficultyScore
        self.active = active
        self.createdAt = createdAt
    }
}
