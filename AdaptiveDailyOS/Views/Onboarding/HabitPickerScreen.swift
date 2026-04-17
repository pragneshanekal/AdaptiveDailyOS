import SwiftUI

struct HabitPickerScreen: View {
    @Binding var currentPage: Int
    @Binding var selectedHabits: Set<UUID>

    private let suggested = HabitScheduler.suggestedHabits

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Choose Your Habits")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Pick 1–5 habits to start with.\nYou can adjust them later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 56)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // Habit list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(suggested) { habit in
                        SuggestedHabitRow(
                            habit: habit,
                            isSelected: selectedHabits.contains(habit.id),
                            isDisabled: !selectedHabits.contains(habit.id) && selectedHabits.count >= 5
                        ) {
                            if selectedHabits.contains(habit.id) {
                                selectedHabits.remove(habit.id)
                            } else if selectedHabits.count < 5 {
                                selectedHabits.insert(habit.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }

            // Footer
            VStack(spacing: 12) {
                if !selectedHabits.isEmpty {
                    Text("\(selectedHabits.count) habit\(selectedHabits.count == 1 ? "" : "s") selected")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    currentPage = 2
                } label: {
                    Text("Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedHabits.isEmpty)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
            .padding(.top, 8)
        }
    }
}

private struct SuggestedHabitRow: View {
    let habit: SuggestedHabit
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemFill))
                        .frame(width: 44, height: 44)

                    Image(systemName: habit.category.systemImageName)
                        .font(.body)
                        .foregroundStyle(isSelected ? .white : Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(isDisabled && !isSelected ? .secondary : .primary)

                    Text("\(formattedTarget) · \(habit.frequency.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
                    )
            )
            .opacity(isDisabled && !isSelected ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled && !isSelected)
        .accessibilityLabel("\(habit.name), \(formattedTarget), \(habit.frequency.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var formattedTarget: String {
        let value = habit.targetValue.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(habit.targetValue))
            : String(habit.targetValue)
        return "\(value) \(habit.unit)"
    }
}

#Preview {
    HabitPickerScreen(currentPage: .constant(1), selectedHabits: .constant([]))
}
