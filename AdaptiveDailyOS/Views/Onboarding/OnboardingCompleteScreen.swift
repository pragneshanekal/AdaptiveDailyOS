import SwiftUI
import SwiftData

struct OnboardingCompleteScreen: View {
    @Binding var selectedHabits: Set<UUID>

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var isAnimating = false

    private let suggested = HabitScheduler.suggestedHabits

    var body: some View {
        VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 120, height: 120)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isAnimating)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.accentColor)
                            .scaleEffect(isAnimating ? 1.0 : 0.85)
                            .animation(.spring(duration: 0.6), value: isAnimating)
                    }

                    VStack(spacing: 12) {
                        Text("You're all set!")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("\(selectedHabits.count) habit\(selectedHabits.count == 1 ? "" : "s") scheduled for today")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Summary of selected habits
                VStack(spacing: 8) {
                    ForEach(chosenHabits) { habit in
                        HStack(spacing: 12) {
                            Image(systemName: habit.category.systemImageName)
                                .font(.body)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24)
                                .accessibilityHidden(true)
                            Text(habit.name)
                                .font(.body)
                            Spacer()
                            Text(formattedTarget(for: habit))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 32)
                    }
                }

                Spacer()

                Button {
                    saveAndStart()
                } label: {
                    Text("Start Tracking")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.12), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear { isAnimating = true }
    }

    private var chosenHabits: [SuggestedHabit] {
        suggested.filter { selectedHabits.contains($0.id) }
    }

    private func formattedTarget(for habit: SuggestedHabit) -> String {
        let value = habit.targetValue.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(habit.targetValue))
            : String(habit.targetValue)
        return "\(value) \(habit.unit)"
    }

    private func saveAndStart() {
        for suggested in chosenHabits {
            let template = HabitTemplate(
                name: suggested.name,
                category: suggested.category,
                targetValue: suggested.targetValue,
                unit: suggested.unit,
                frequency: suggested.frequency,
                difficultyScore: suggested.difficultyScore
            )
            modelContext.insert(template)
        }

        HabitScheduler.scheduleHabitsForDate(Date(), context: modelContext)
        appState.completeOnboarding()
    }
}

#Preview {
    OnboardingCompleteScreen(selectedHabits: .constant(Set(HabitScheduler.suggestedHabits.prefix(3).map(\.id))))
        .modelContainer(for: [HabitTemplate.self, DailyHabit.self, CompletionLog.self], inMemory: true)
        .environment(AppState())
}
