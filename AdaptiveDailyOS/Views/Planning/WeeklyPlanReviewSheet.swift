import SwiftUI
import SwiftData

struct WeeklyPlanReviewSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var draft: WeeklyPlanDraft?
    @State private var loadState: LoadState = .loading
    @State private var errorMessage: String?

    enum LoadState {
        case loading
        case ready
        case failed
    }

    var body: some View {
        NavigationStack {
            Group {
                switch loadState {
                case .loading:
                    loadingView
                case .ready:
                    if let draft { readyView(draft: draft) }
                case .failed:
                    failedView
                }
            }
            .navigationTitle("Weekly Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if case .ready = loadState, draft != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Accept") { accept() }
                    }
                }
            }
            .task { await load() }
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Generating plan…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var failedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Couldn't generate plan")
                .font(.headline)
            Text(errorMessage ?? "Unknown error")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Try Again") {
                Task { await load() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func readyView(draft: WeeklyPlanDraft) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(draft.suggestion.summary)
                        .font(.body)
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(.secondary)
                        Text("Predicted completion: \(Int(draft.suggestion.predictedCompletionRate * 100))%")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Week of \(draft.weekStart.formatted(.dateTime.month().day()))")
            }

            Section("Suggested Targets") {
                ForEach(draft.suggestion.habits) { habit in
                    HabitSuggestionRow(
                        suggestion: habit,
                        previousTarget: draft.previousTargets[habit.templateId]
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func load() async {
        loadState = .loading
        errorMessage = nil
        do {
            let newDraft = try await WeeklyPlanService().generateDraft(context: modelContext)
            draft = newDraft
            loadState = .ready
        } catch {
            errorMessage = error.localizedDescription
            loadState = .failed
        }
    }

    private func accept() {
        guard let draft else { return }
        do {
            try WeeklyPlanService().accept(draft, context: modelContext)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            loadState = .failed
        }
    }
}

private struct HabitSuggestionRow: View {
    let suggestion: PlanHabitSuggestion
    let previousTarget: Double?

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
                Text(formatted(previousTarget))
                    .strikethrough()
                    .foregroundStyle(.tertiary)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Text(formatted(suggestion.suggestedTarget))
                .fontWeight(.semibold)
                .foregroundStyle(trend.color)
        }
        .font(.subheadline)
        .monospacedDigit()
    }

    private var trend: (color: Color, symbol: String) {
        guard let previousTarget else { return (.primary, "") }
        if suggestion.suggestedTarget > previousTarget { return (.orange, "↑") }
        if suggestion.suggestedTarget < previousTarget { return (.blue, "↓") }
        return (.primary, "")
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}
