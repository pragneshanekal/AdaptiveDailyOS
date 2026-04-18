import Foundation
import SwiftData

// MARK: - DTOs decoded from the AI response

struct PlanSuggestion: Decodable {
    let summary: String
    let predictedCompletionRate: Double
    let habits: [PlanHabitSuggestion]
}

struct PlanHabitSuggestion: Decodable, Identifiable {
    let templateId: UUID
    let name: String
    let suggestedTarget: Double
    let rationale: String

    var id: UUID { templateId }
}

// Draft plan held in memory while the user reviews; not yet persisted.
struct WeeklyPlanDraft {
    let weekStart: Date
    let suggestion: PlanSuggestion
    let rawJSON: String

    // Previous target per habit (from the template) for side-by-side display.
    let previousTargets: [UUID: Double]
}

// MARK: - Service

struct WeeklyPlanService {
    let ai: AIService

    init(ai: AIService = AIService()) {
        self.ai = ai
    }

    // Returns the start-of-week (Monday) for the week containing `date`.
    static func weekStart(for date: Date, calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.firstWeekday = 2 // Monday
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components) ?? cal.startOfDay(for: date)
    }

    // The accepted plan covering `date`, if any.
    static func activePlan(on date: Date, context: ModelContext) -> WeeklyPlan? {
        let weekStart = weekStart(for: date)
        let fetch = FetchDescriptor<WeeklyPlan>(
            predicate: #Predicate { $0.weekStart == weekStart && $0.acceptedAt != nil }
        )
        return (try? context.fetch(fetch))?.first
    }

    // Heuristic trigger: prompt when no plan exists yet for the upcoming/current
    // week and it's Sunday evening or later in the week.
    static func shouldPromptNewPlan(now: Date = Date(), context: ModelContext) -> Bool {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now) // 1 = Sunday
        let hour = cal.component(.hour, from: now)

        // Target week: if Sunday evening (>=17:00), promote for the upcoming Monday.
        let targetDate: Date
        if weekday == 1 && hour >= 17 {
            targetDate = cal.date(byAdding: .day, value: 1, to: now) ?? now
        } else {
            targetDate = now
        }

        return activePlan(on: targetDate, context: context) == nil
            && (weekday == 1 && hour >= 17 || weekday != 1)
    }

    // Build a draft plan by querying the AI. Does not persist anything.
    func generateDraft(for date: Date = Date(), context: ModelContext) async throws -> WeeklyPlanDraft {
        let weekStart = Self.weekStart(for: date)

        let templates = (try? context.fetch(
            FetchDescriptor<HabitTemplate>(predicate: #Predicate { $0.active })
        )) ?? []
        guard !templates.isEmpty else {
            throw PlanError.noActiveHabits
        }

        let recent = recentDailyHabits(context: context, days: 14)
        let userMessage = buildUserPrompt(templates: templates, recent: recent)

        let responseText = try await ai.sendMessage(
            systemPrompt: Self.systemPrompt,
            userMessage: userMessage,
            maxTokens: 1500
        )

        let json = Self.extractJSON(from: responseText)
        guard let data = json.data(using: .utf8) else {
            throw PlanError.unparseable("empty response")
        }

        do {
            let suggestion = try JSONDecoder().decode(PlanSuggestion.self, from: data)
            let previousTargets = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0.targetValue) })
            return WeeklyPlanDraft(
                weekStart: weekStart,
                suggestion: suggestion,
                rawJSON: json,
                previousTargets: previousTargets
            )
        } catch {
            throw PlanError.unparseable(error.localizedDescription)
        }
    }

    // Persist a draft as the accepted plan for its week. Replaces any existing
    // plan for the same week (keeps storage clean while the user iterates).
    @discardableResult
    func accept(_ draft: WeeklyPlanDraft, context: ModelContext) throws -> WeeklyPlan {
        let weekStart = draft.weekStart
        let existing = (try? context.fetch(
            FetchDescriptor<WeeklyPlan>(predicate: #Predicate { $0.weekStart == weekStart })
        )) ?? []
        for old in existing { context.delete(old) }

        let plan = WeeklyPlan(
            weekStart: weekStart,
            aiPlanSnapshot: draft.rawJSON,
            predictedRate: draft.suggestion.predictedCompletionRate,
            acceptedAt: Date()
        )
        context.insert(plan)
        return plan
    }

    // MARK: - Prompt helpers

    private static let systemPrompt = """
    You are an assistant inside an iOS habit tracker. You help the user plan \
    the upcoming week by adjusting habit targets based on their recent history.

    Return ONLY a single JSON object, no prose, no code fences. Schema:
    {
      "summary": string,                    // 1-2 sentence human-readable overview
      "predictedCompletionRate": number,    // 0.0 to 1.0
      "habits": [
        {
          "templateId": string (UUID),
          "name": string,
          "suggestedTarget": number,
          "rationale": string               // 1 short sentence
        }
      ]
    }

    Guidelines:
    - Lower targets slightly when recent completion rate is below 60%.
    - Keep targets when completion is 60-85%.
    - Raise targets modestly (max +20%) when completion is above 85%.
    - Never change a target by more than 50% in either direction.
    - Include every active habit from the input in the output.
    """

    private static func extractJSON(from text: String) -> String {
        // Tolerate leading/trailing prose or ```json fences.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}") {
            return String(trimmed[start...end])
        }
        return trimmed
    }

    private func recentDailyHabits(context: ModelContext, days: Int) -> [DailyHabit] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let fetch = FetchDescriptor<DailyHabit>(
            predicate: #Predicate { $0.scheduledDate >= cutoff },
            sortBy: [SortDescriptor(\.scheduledDate)]
        )
        return (try? context.fetch(fetch)) ?? []
    }

    private func buildUserPrompt(templates: [HabitTemplate], recent: [DailyHabit]) -> String {
        var lines: [String] = []
        lines.append("Active habits:")
        for t in templates {
            lines.append("- id=\(t.id.uuidString) name=\"\(t.name)\" target=\(formatted(t.targetValue)) \(t.unit) frequency=\(t.frequency.rawValue) difficulty=\(t.difficultyScore)")
        }
        lines.append("")
        lines.append("Last 14 days of scheduled habits (status + adapted target):")
        if recent.isEmpty {
            lines.append("(no history yet)")
        } else {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withFullDate]
            for habit in recent {
                guard let template = habit.template else { continue }
                lines.append("- \(iso.string(from: habit.scheduledDate)) \(template.name) target=\(formatted(habit.adaptedTarget)) status=\(habit.status.rawValue)")
            }
        }
        lines.append("")
        lines.append("Produce the JSON plan for the upcoming week.")
        return lines.joined(separator: "\n")
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }

    enum PlanError: Error, LocalizedError {
        case noActiveHabits
        case unparseable(String)

        var errorDescription: String? {
            switch self {
            case .noActiveHabits: return "No active habits to plan for. Add habits first."
            case .unparseable(let m): return "Couldn't understand the AI response: \(m)"
            }
        }
    }
}
