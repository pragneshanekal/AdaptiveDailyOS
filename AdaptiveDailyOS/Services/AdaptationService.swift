import Foundation
import SwiftData

// MARK: - DTOs decoded from AI response

struct AdaptationSuggestion: Decodable {
    let adaptations: [AdaptationHabitSuggestion]
}

struct AdaptationHabitSuggestion: Decodable, Identifiable {
    let templateId: UUID
    let name: String
    let newTarget: Double
    let rationale: String

    var id: UUID { templateId }
}

// A single struggling habit together with its recent history snapshot.
struct StruggleCandidate {
    let template: HabitTemplate
    let recent: [DailyHabit]      // last 3 scheduled, most recent first
    let currentTarget: Double     // active plan override or template default
    let missedCount: Int
}

// A proposal pending user review. Tracks previous target for side-by-side UI.
struct AdaptationProposal: Identifiable {
    let templateId: UUID
    let name: String
    let unit: String
    let previousTarget: Double
    let newTarget: Double
    let rationale: String
    let triggerReason: String

    var id: UUID { templateId }
}

// MARK: - Service

struct AdaptationService {
    let ai: AIService

    init(ai: AIService = AIService()) {
        self.ai = ai
    }

    // Scans active templates for ones with 2+ misses in their last 3 scheduled
    // DailyHabits. Templates already adapted in the last 3 days are skipped to
    // avoid re-prompting during the same struggle window.
    static func struggleCandidates(now: Date = Date(), context: ModelContext) -> [StruggleCandidate] {
        let templates = (try? context.fetch(
            FetchDescriptor<HabitTemplate>(predicate: #Predicate { $0.active })
        )) ?? []

        let startOfToday = Calendar.current.startOfDay(for: now)
        let recentEvents = recentAdaptationEvents(since: Calendar.current.date(byAdding: .day, value: -3, to: now) ?? now,
                                                   context: context)
        let recentlyAdaptedIds = Set(recentEvents.compactMap { $0.habitTemplateId })
        let planTargets = Self.planTargets(on: startOfToday, context: context)

        var candidates: [StruggleCandidate] = []
        for template in templates where !recentlyAdaptedIds.contains(template.id) {
            let history = scheduledHistory(for: template, before: startOfToday, context: context)
            let lastThree = Array(history.prefix(3))
            guard lastThree.count == 3 else { continue }
            let missed = lastThree.filter { $0.status == .missed }.count
            guard missed >= 2 else { continue }
            let currentTarget = planTargets[template.id] ?? template.targetValue
            candidates.append(StruggleCandidate(
                template: template,
                recent: lastThree,
                currentTarget: currentTarget,
                missedCount: missed
            ))
        }
        return candidates
    }

    // Asks the AI to propose reduced targets for the struggling habits. Returns
    // one AdaptationProposal per candidate the AI suggests.
    func generateProposals(for candidates: [StruggleCandidate]) async throws -> [AdaptationProposal] {
        guard !candidates.isEmpty else { return [] }

        let userMessage = buildUserPrompt(candidates: candidates)
        let responseText = try await ai.sendMessage(
            systemPrompt: Self.systemPrompt,
            userMessage: userMessage,
            maxTokens: 1000
        )

        let json = Self.extractJSON(from: responseText)
        guard let data = json.data(using: .utf8) else {
            throw AdaptationError.unparseable("empty response")
        }

        let suggestion: AdaptationSuggestion
        do {
            suggestion = try JSONDecoder().decode(AdaptationSuggestion.self, from: data)
        } catch {
            throw AdaptationError.unparseable(error.localizedDescription)
        }

        let candidatesById = Dictionary(uniqueKeysWithValues: candidates.map { ($0.template.id, $0) })
        return suggestion.adaptations.compactMap { s in
            guard let candidate = candidatesById[s.templateId] else { return nil }
            let clamped = clampReduction(previous: candidate.currentTarget, proposed: s.newTarget)
            return AdaptationProposal(
                templateId: s.templateId,
                name: candidate.template.name,
                unit: candidate.template.unit,
                previousTarget: candidate.currentTarget,
                newTarget: clamped,
                rationale: s.rationale,
                triggerReason: "\(candidate.missedCount) of last 3 scheduled were missed"
            )
        }
    }

    // Persists an accepted adaptation: updates the active plan's snapshot so
    // future DailyHabits use the new target, and records an AdaptationEvent.
    // Today's already-scheduled DailyHabit is intentionally not rewritten.
    func accept(_ proposal: AdaptationProposal, context: ModelContext) throws {
        let now = Date()
        let plan = WeeklyPlanService.activePlan(on: now, context: context)

        if let plan {
            try updatePlanSnapshot(plan: plan, templateId: proposal.templateId,
                                    newTarget: proposal.newTarget, rationale: proposal.rationale)
        }

        let event = AdaptationEvent(
            habitTemplateId: proposal.templateId,
            habitName: proposal.name,
            triggerReason: proposal.triggerReason,
            beforeState: "target=\(format(proposal.previousTarget)) \(proposal.unit)",
            afterState: "target=\(format(proposal.newTarget)) \(proposal.unit) — \(proposal.rationale)",
            accepted: true,
            plan: plan
        )
        context.insert(event)
    }

    // Records a rejected proposal as a dismissed event so it counts toward
    // throttling and shows up in the history timeline.
    func reject(_ proposal: AdaptationProposal, context: ModelContext) {
        let event = AdaptationEvent(
            habitTemplateId: proposal.templateId,
            habitName: proposal.name,
            triggerReason: proposal.triggerReason,
            beforeState: "target=\(format(proposal.previousTarget)) \(proposal.unit)",
            afterState: "declined (\(format(proposal.newTarget)) \(proposal.unit))",
            accepted: false,
            plan: WeeklyPlanService.activePlan(on: Date(), context: context)
        )
        context.insert(event)
    }

    // MARK: - Internals

    private static let systemPrompt = """
    You are an assistant inside an iOS habit tracker. The user is mid-week and \
    struggling with some habits (2+ misses in their last 3 scheduled days). \
    Propose a modestly reduced target for each struggling habit so they can \
    rebuild momentum.

    Return ONLY a single JSON object, no prose, no code fences. Schema:
    {
      "adaptations": [
        {
          "templateId": string (UUID),
          "name": string,
          "newTarget": number,
          "rationale": string   // 1 short sentence explaining the reduction
        }
      ]
    }

    Guidelines:
    - Reduce each target by 20-40%. Never cut by more than 50%.
    - Keep the result meaningful (e.g. > 0, rounded to a sensible value).
    - Include one entry per struggling habit you were given.
    - Never raise a target in this flow — this is an adaptation for struggle.
    """

    private func buildUserPrompt(candidates: [StruggleCandidate]) -> String {
        var lines: [String] = ["Struggling habits from the last 3 scheduled days:"]
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        for c in candidates {
            lines.append("- id=\(c.template.id.uuidString) name=\"\(c.template.name)\" currentTarget=\(format(c.currentTarget)) \(c.template.unit) missed=\(c.missedCount)/3")
            for day in c.recent {
                lines.append("    \(iso.string(from: day.scheduledDate)) status=\(day.status.rawValue) target=\(format(day.adaptedTarget))")
            }
        }
        lines.append("")
        lines.append("Produce the JSON adaptation.")
        return lines.joined(separator: "\n")
    }

    // Rewrites the plan snapshot JSON so the given template's suggestedTarget
    // is updated. Other habits in the plan are left untouched. If the template
    // isn't in the plan's habits array, it's appended as a new entry.
    private func updatePlanSnapshot(plan: WeeklyPlan, templateId: UUID, newTarget: Double, rationale: String) throws {
        guard let data = plan.aiPlanSnapshot.data(using: .utf8),
              var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AdaptationError.planUpdateFailed
        }
        var habits = (json["habits"] as? [[String: Any]]) ?? []
        let idString = templateId.uuidString
        if let idx = habits.firstIndex(where: { ($0["templateId"] as? String)?.caseInsensitiveCompare(idString) == .orderedSame }) {
            habits[idx]["suggestedTarget"] = newTarget
            habits[idx]["rationale"] = rationale
        } else {
            habits.append([
                "templateId": idString,
                "name": "",
                "suggestedTarget": newTarget,
                "rationale": rationale
            ])
        }
        json["habits"] = habits
        let updated = try JSONSerialization.data(withJSONObject: json)
        guard let string = String(data: updated, encoding: .utf8) else {
            throw AdaptationError.planUpdateFailed
        }
        plan.aiPlanSnapshot = string
    }

    private func clampReduction(previous: Double, proposed: Double) -> Double {
        let floor = previous * 0.5
        let ceiling = previous
        return min(max(proposed, floor), ceiling)
    }

    private func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }

    private static func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}") {
            return String(trimmed[start...end])
        }
        return trimmed
    }

    // Fetches a template's DailyHabits strictly before `date`, sorted most recent first.
    private static func scheduledHistory(for template: HabitTemplate, before date: Date, context: ModelContext) -> [DailyHabit] {
        let templateId = template.id
        let fetch = FetchDescriptor<DailyHabit>(
            predicate: #Predicate { habit in
                habit.scheduledDate < date && habit.template?.id == templateId
            },
            sortBy: [SortDescriptor(\.scheduledDate, order: .reverse)]
        )
        return (try? context.fetch(fetch)) ?? []
    }

    private static func recentAdaptationEvents(since cutoff: Date, context: ModelContext) -> [AdaptationEvent] {
        let fetch = FetchDescriptor<AdaptationEvent>(
            predicate: #Predicate { $0.occurredAt >= cutoff }
        )
        return (try? context.fetch(fetch)) ?? []
    }

    // Mirror of WeeklyPlanService.planTargets but usable from static context.
    private static func planTargets(on date: Date, context: ModelContext) -> [UUID: Double] {
        guard let plan = WeeklyPlanService.activePlan(on: date, context: context) else { return [:] }
        guard let data = plan.aiPlanSnapshot.data(using: .utf8) else { return [:] }
        guard let decoded = try? JSONDecoder().decode(PlanSuggestion.self, from: data) else { return [:] }
        var result: [UUID: Double] = [:]
        for habit in decoded.habits {
            result[habit.templateId] = habit.suggestedTarget
        }
        return result
    }

    enum AdaptationError: Error, LocalizedError {
        case unparseable(String)
        case planUpdateFailed

        var errorDescription: String? {
            switch self {
            case .unparseable(let m): return "Couldn't understand the AI response: \(m)"
            case .planUpdateFailed:   return "Couldn't update the plan snapshot."
            }
        }
    }
}
