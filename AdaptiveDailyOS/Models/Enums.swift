import Foundation

enum HabitCategory: String, Codable, CaseIterable {
    case health       = "Health"
    case fitness      = "Fitness"
    case mindfulness  = "Mindfulness"
    case learning     = "Learning"
    case productivity = "Productivity"
    case social       = "Social"
    case custom       = "Custom"

    var systemImageName: String {
        switch self {
        case .health:       return "heart.fill"
        case .fitness:      return "figure.run"
        case .mindfulness:  return "brain.head.profile"
        case .learning:     return "book.fill"
        case .productivity: return "checkmark.seal.fill"
        case .social:       return "person.2.fill"
        case .custom:       return "star.fill"
        }
    }
}

enum HabitFrequency: String, Codable, CaseIterable {
    case daily    = "Daily"
    case weekdays = "Weekdays"
    case weekends = "Weekends"
    case custom   = "Custom"
}

enum DailyHabitStatus: String, Codable {
    case pending   = "Pending"
    case completed = "Completed"
    case skipped   = "Skipped"
    case missed    = "Missed"
}
