import SwiftUI
import SwiftData

struct LogHabitSheet: View {
    @Bindable var dailyHabit: DailyHabit

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var valueLogged: Double
    @State private var note: String = ""

    init(dailyHabit: DailyHabit) {
        self.dailyHabit = dailyHabit
        // Pre-fill with the full target so the user can just tap Done for a full completion.
        _valueLogged = State(initialValue: dailyHabit.adaptedTarget)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: category?.systemImageName ?? "star.fill")
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                        Text(dailyHabit.template?.name ?? "Habit")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(targetLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Amount logged") {
                    VStack(spacing: 12) {
                        HStack {
                            Text(formattedValue)
                                .font(.title)
                                .fontWeight(.bold)
                                .monospacedDigit()
                            Text(unit)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        Slider(
                            value: $valueLogged,
                            in: 0...(dailyHabit.adaptedTarget * 2),
                            step: stepSize
                        )
                        .tint(Color.accentColor)
                        .accessibilityLabel("Amount logged")
                        .accessibilityValue("\(formattedValue) \(unit)")

                        HStack {
                            Text("0")
                            Spacer()
                            Text(formattedMax)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Note (optional)") {
                    TextField("How did it go?", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("Log Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionButtons
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.bar)
            }
        }
    }

    // MARK: - Subviews

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                skipHabit()
            } label: {
                Text("Skip for Today")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            Button {
                markComplete()
            } label: {
                Text("Mark Complete")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

    private func markComplete() {
        let log = CompletionLog(
            valueLogged: valueLogged,
            note: note,
            dailyHabit: dailyHabit
        )
        modelContext.insert(log)
        dailyHabit.status = .completed
        dismiss()
    }

    private func skipHabit() {
        dailyHabit.status = .skipped
        dismiss()
    }

    // MARK: - Helpers

    private var category: HabitCategory? { dailyHabit.template?.category }
    private var unit: String { dailyHabit.template?.unit ?? "" }

    private var targetLabel: String {
        let target = dailyHabit.adaptedTarget
        let value  = target.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(target)) : String(target)
        return "Goal: \(value) \(unit)"
    }

    private var formattedValue: String {
        valueLogged.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(valueLogged))
            : String(format: "%.1f", valueLogged)
    }

    private var formattedMax: String {
        let max = dailyHabit.adaptedTarget * 2
        return max.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(max))
            : String(format: "%.1f", max)
    }

    // Use whole-number steps for most units; 0.5 for fractional targets.
    private var stepSize: Double {
        dailyHabit.adaptedTarget.truncatingRemainder(dividingBy: 1) == 0 ? 1 : 0.5
    }
}

#Preview {
    let template = HabitTemplate(name: "Morning Run", category: .fitness,
                                 targetValue: 30, unit: "minutes", frequency: .daily, difficultyScore: 3)
    let habit = DailyHabit(scheduledDate: Date(), adaptedTarget: 30, template: template)

    return LogHabitSheet(dailyHabit: habit)
        .modelContainer(for: [HabitTemplate.self, DailyHabit.self, CompletionLog.self], inMemory: true)
}
