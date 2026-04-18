import SwiftUI
import SwiftData

struct WeeklyPlanDetailView: View {
    let plan: WeeklyPlan

    @Environment(\.dismiss) private var dismiss
    @Query private var templates: [HabitTemplate]

    var body: some View {
        NavigationStack {
            Group {
                if let decoded {
                    List {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(decoded.summary)
                                    .font(.body)
                                HStack(spacing: 6) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .foregroundStyle(.secondary)
                                    Text("Predicted: \(Int(plan.predictedRate * 100))% completion")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                if let acceptedAt = plan.acceptedAt {
                                    Text("Accepted \(acceptedAt.formatted(.dateTime.month().day().hour().minute()))")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 4)
                        } header: {
                            Text("Week of \(plan.weekStart.formatted(.dateTime.month().day()))")
                        }

                        Section("Targets for this week") {
                            ForEach(decoded.habits) { habit in
                                PlanHabitDetailRow(
                                    suggestion: habit,
                                    previousTarget: templateTargets[habit.templateId],
                                    unit: templateUnits[habit.templateId] ?? ""
                                )
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Plan unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text("The stored plan could not be read.")
                    )
                }
            }
            .navigationTitle("Plan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var decoded: PlanSuggestion? {
        guard let data = plan.aiPlanSnapshot.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PlanSuggestion.self, from: data)
    }

    private var templateTargets: [UUID: Double] {
        Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0.targetValue) })
    }

    private var templateUnits: [UUID: String] {
        Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0.unit) })
    }
}

private struct PlanHabitDetailRow: View {
    let suggestion: PlanHabitSuggestion
    let previousTarget: Double?
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(suggestion.name)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
                targetBadge
            }
            Text(suggestion.rationale)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var targetBadge: some View {
        HStack(spacing: 4) {
            if let previousTarget, previousTarget != suggestion.suggestedTarget {
                Text("\(formatted(previousTarget)) \(unit)")
                    .strikethrough()
                    .foregroundStyle(.tertiary)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Text("\(formatted(suggestion.suggestedTarget)) \(unit)")
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .font(.subheadline)
        .monospacedDigit()
    }

    private var color: Color {
        guard let previousTarget else { return .primary }
        if suggestion.suggestedTarget > previousTarget { return .orange }
        if suggestion.suggestedTarget < previousTarget { return .blue }
        return .primary
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}
