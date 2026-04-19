import SwiftUI
import SwiftData

struct AdaptationReviewSheet: View {
    let candidates: [StruggleCandidate]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var proposals: [AdaptationProposal] = []
    @State private var decisions: [UUID: Decision] = [:]
    @State private var loadState: LoadState = .loading
    @State private var errorMessage: String?

    enum LoadState { case loading, ready, failed, empty }
    enum Decision { case accepted, rejected }

    var body: some View {
        NavigationStack {
            Group {
                switch loadState {
                case .loading: loadingView
                case .empty:   emptyView
                case .failed:  failedView
                case .ready:   readyView
                }
            }
            .navigationTitle("Adjust Targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if case .ready = loadState {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") { apply() }
                            .disabled(!hasAnyDecision)
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
            Text("Looking at recent progress…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "Nothing to adjust",
            systemImage: "checkmark.circle",
            description: Text("No struggling habits right now.")
        )
    }

    private var failedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Couldn't generate suggestions")
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

    private var readyView: some View {
        List {
            Section {
                Text("You've missed several habits recently. Here are gentler targets to rebuild momentum.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(proposals) { proposal in
                ProposalRow(
                    proposal: proposal,
                    decision: decisions[proposal.templateId],
                    onAccept: { decisions[proposal.templateId] = .accepted },
                    onReject: { decisions[proposal.templateId] = .rejected }
                )
            }
        }
    }

    private var hasAnyDecision: Bool { !decisions.isEmpty }

    // MARK: - Actions

    private func load() async {
        loadState = .loading
        errorMessage = nil
        guard !candidates.isEmpty else {
            loadState = .empty
            return
        }
        do {
            let generated = try await AdaptationService().generateProposals(for: candidates)
            proposals = generated
            loadState = generated.isEmpty ? .empty : .ready
        } catch {
            errorMessage = error.localizedDescription
            loadState = .failed
        }
    }

    private func apply() {
        let service = AdaptationService()
        for proposal in proposals {
            switch decisions[proposal.templateId] {
            case .accepted:
                try? service.accept(proposal, context: modelContext)
            case .rejected:
                service.reject(proposal, context: modelContext)
            case .none:
                break
            }
        }
        dismiss()
    }
}

private struct ProposalRow: View {
    let proposal: AdaptationProposal
    let decision: AdaptationReviewSheet.Decision?
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(proposal.name)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
                targetBadge
            }
            Text(proposal.rationale)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(proposal.triggerReason)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                Button {
                    onReject()
                } label: {
                    Label("Keep", systemImage: decision == .rejected ? "checkmark.circle.fill" : "circle")
                        .font(.footnote)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(decision == .rejected ? .secondary : .gray)

                Button {
                    onAccept()
                } label: {
                    Label("Adjust", systemImage: decision == .accepted ? "checkmark.circle.fill" : "circle")
                        .font(.footnote)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(decision == .accepted ? .accentColor : .gray)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    private var targetBadge: some View {
        HStack(spacing: 4) {
            Text("\(formatted(proposal.previousTarget)) \(proposal.unit)")
                .strikethrough()
                .foregroundStyle(.tertiary)
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("\(formatted(proposal.newTarget)) \(proposal.unit)")
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
        }
        .font(.subheadline)
        .monospacedDigit()
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}
