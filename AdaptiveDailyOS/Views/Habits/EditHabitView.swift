import SwiftUI
import SwiftData

struct EditHabitView: View {
    enum Mode {
        case create
        case edit(HabitTemplate)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var name: String = ""
    @State private var category: HabitCategory = .health
    @State private var targetValue: Double = 1
    @State private var unit: String = "minutes"
    @State private var frequency: HabitFrequency = .daily
    @State private var difficultyScore: Int = 2
    @State private var active: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(HabitCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.systemImageName).tag(cat)
                        }
                    }
                }

                Section("Target") {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("", value: $targetValue, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    TextField("Unit (e.g. minutes, glasses)", text: $unit)
                }

                Section("Schedule") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach([HabitFrequency.daily, .weekdays, .weekends], id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Difficulty") {
                    Stepper("Score: \(difficultyScore)", value: $difficultyScore, in: 1...5)
                }

                if case .edit = mode {
                    Section {
                        Toggle("Active", isOn: $active)
                    } footer: {
                        Text("Paused habits stop appearing in Today but keep their history and streaks.")
                    }
                }
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: loadInitialState)
        }
    }

    private var titleText: String {
        switch mode {
        case .create: return "New Habit"
        case .edit:   return "Edit Habit"
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !unit.trimmingCharacters(in: .whitespaces).isEmpty &&
        targetValue > 0
    }

    private func loadInitialState() {
        if case let .edit(template) = mode {
            name = template.name
            category = template.category
            targetValue = template.targetValue
            unit = template.unit
            frequency = template.frequency
            difficultyScore = template.difficultyScore
            active = template.active
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespaces)

        switch mode {
        case .create:
            let template = HabitTemplate(
                name: trimmedName,
                category: category,
                targetValue: targetValue,
                unit: trimmedUnit,
                frequency: frequency,
                difficultyScore: difficultyScore,
                active: active
            )
            modelContext.insert(template)
            HabitScheduler.scheduleHabitsForDate(Date(), context: modelContext)

        case .edit(let template):
            template.name = trimmedName
            template.category = category
            template.targetValue = targetValue
            template.unit = trimmedUnit
            template.frequency = frequency
            template.difficultyScore = difficultyScore
            template.active = active
            HabitScheduler.scheduleHabitsForDate(Date(), context: modelContext)
        }

        dismiss()
    }
}

#Preview("Create") {
    EditHabitView(mode: .create)
        .modelContainer(for: [HabitTemplate.self, DailyHabit.self, CompletionLog.self], inMemory: true)
}
