import SwiftUI
import SwiftData

struct HabitRowView: View {
    let dailyHabit: DailyHabit
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .frame(width: 48, height: 48)
                    Image(systemName: category?.systemImageName ?? "star.fill")
                        .font(.body)
                        .foregroundStyle(iconForeground)
                }
                .accessibilityHidden(true)

                // Name + target
                VStack(alignment: .leading, spacing: 3) {
                    Text(dailyHabit.template?.name ?? "Habit")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(targetLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Status chip
                statusChip
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(dailyHabit.status.rawValue)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: - Subviews

    private var statusChip: some View {
        Group {
            switch dailyHabit.status {
            case .completed:
                Label("Done", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor, in: Capsule())
            case .skipped:
                Label("Skipped", systemImage: "arrow.uturn.right.circle.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            case .missed:
                Label("Missed", systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.systemRed), in: Capsule())
            case .pending:
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(Color(.tertiaryLabel))
                    .padding(.trailing, 4)
            }
        }
    }

    // MARK: - Helpers

    private var category: HabitCategory? { dailyHabit.template?.category }

    private var iconBackground: Color {
        dailyHabit.status == .completed ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemFill)
    }

    private var iconForeground: Color {
        dailyHabit.status == .completed ? Color.accentColor : Color(.secondaryLabel)
    }

    private var targetLabel: String {
        let unit = dailyHabit.template?.unit ?? ""
        if dailyHabit.status == .completed, let logged = latestLoggedValue {
            let loggedStr = format(logged)
            if logged == dailyHabit.adaptedTarget {
                return "\(loggedStr) \(unit)"
            }
            return "\(loggedStr) \(unit) · target \(format(dailyHabit.adaptedTarget))"
        }
        return "\(format(dailyHabit.adaptedTarget)) \(unit)"
    }

    private var latestLoggedValue: Double? {
        dailyHabit.completionLogs
            .sorted { $0.completedAt > $1.completedAt }
            .first?.valueLogged
    }

    private func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }

    private var accessibilityLabel: String {
        dailyHabit.template?.name ?? "Habit"
    }

    private var accessibilityHint: String {
        switch dailyHabit.status {
        case .pending:   return "Tap to log this habit"
        case .completed: return "Tap to update your log"
        case .skipped:   return "Tap to update your log"
        case .missed:    return ""
        }
    }
}

#Preview {
    let template = HabitTemplate(name: "Morning Run", category: .fitness,
                                 targetValue: 30, unit: "minutes", frequency: .daily, difficultyScore: 3)
    let habit = DailyHabit(scheduledDate: Date(), adaptedTarget: 30, template: template)

    HabitRowView(dailyHabit: habit, onTap: {})
        .padding()
        .modelContainer(for: [HabitTemplate.self, DailyHabit.self, CompletionLog.self], inMemory: true)
}
