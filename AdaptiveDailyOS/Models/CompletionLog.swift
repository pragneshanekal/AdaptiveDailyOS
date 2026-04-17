import Foundation
import SwiftData

@Model
final class CompletionLog {
    var id: UUID
    var completedAt: Date
    var valueLogged: Double
    var note: String

    var dailyHabit: DailyHabit?

    init(
        id: UUID = UUID(),
        completedAt: Date = Date(),
        valueLogged: Double,
        note: String = "",
        dailyHabit: DailyHabit? = nil
    ) {
        self.id = id
        self.completedAt = completedAt
        self.valueLogged = valueLogged
        self.note = note
        self.dailyHabit = dailyHabit
    }
}
