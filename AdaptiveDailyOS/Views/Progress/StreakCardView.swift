import SwiftUI
import SwiftData

struct StreakCardView: View {
    @Query(filter: #Predicate<HabitTemplate> { $0.active }, sort: \HabitTemplate.name)
    private var templates: [HabitTemplate]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Streaks")
                .font(.headline)

            if templates.isEmpty {
                Text("No active habits yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                let streaks = StreakCalculator.allStreaks(for: templates)
                let bestCurrent = streaks.values.map(\.currentStreak).max() ?? 0

                ForEach(templates) { template in
                    let result = streaks[template.id] ?? StreakCalculator.StreakResult(currentStreak: 0, longestStreak: 0)
                    StreakRow(
                        template: template,
                        result: result,
                        isBest: result.currentStreak == bestCurrent && bestCurrent > 0
                    )

                    if template.id != templates.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct StreakRow: View {
    let template: HabitTemplate
    let result: StreakCalculator.StreakResult
    let isBest: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 40, height: 40)
                Image(systemName: template.category.systemImageName)
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(template.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if isBest {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Best streak")
                    }
                }
                Text("Best: \(result.longestStreak) day\(result.longestStreak == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(result.currentStreak)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(result.currentStreak > 0 ? Color.accentColor : Color(.tertiaryLabel))
                Text("day streak")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(result.currentStreak) day streak")
        }
    }
}

#Preview {
    StreakCardView()
        .padding()
        .modelContainer(for: [HabitTemplate.self, DailyHabit.self, CompletionLog.self], inMemory: true)
}
