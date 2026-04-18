import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HabitTemplate.createdAt)
    private var templates: [HabitTemplate]

    @State private var editingTemplate: HabitTemplate?
    @State private var showingNew = false
    @State private var deleteCandidate: HabitTemplate?

    var body: some View {
        NavigationStack {
            List {
                if activeTemplates.isEmpty && inactiveTemplates.isEmpty {
                    ContentUnavailableView(
                        "No Habits",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Tap + to add your first habit.")
                    )
                    .listRowBackground(Color.clear)
                }

                if !activeTemplates.isEmpty {
                    Section("Active") {
                        ForEach(activeTemplates) { template in
                            HabitRow(template: template)
                                .contentShape(Rectangle())
                                .onTapGesture { editingTemplate = template }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteCandidate = template
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        template.active = false
                                    } label: {
                                        Label("Pause", systemImage: "pause.circle")
                                    }
                                    .tint(.orange)
                                }
                        }
                    }
                }

                if !inactiveTemplates.isEmpty {
                    Section("Paused") {
                        ForEach(inactiveTemplates) { template in
                            HabitRow(template: template)
                                .contentShape(Rectangle())
                                .onTapGesture { editingTemplate = template }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteCandidate = template
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        template.active = true
                                    } label: {
                                        Label("Resume", systemImage: "play.circle")
                                    }
                                    .tint(.green)
                                }
                        }
                    }
                }
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add habit")
                }
            }
            .sheet(item: $editingTemplate) { template in
                EditHabitView(mode: .edit(template))
            }
            .sheet(isPresented: $showingNew) {
                EditHabitView(mode: .create)
            }
            .alert(
                "Delete habit?",
                isPresented: Binding(
                    get: { deleteCandidate != nil },
                    set: { if !$0 { deleteCandidate = nil } }
                ),
                presenting: deleteCandidate
            ) { template in
                Button("Delete", role: .destructive) {
                    modelContext.delete(template)
                    deleteCandidate = nil
                }
                Button("Cancel", role: .cancel) { deleteCandidate = nil }
            } message: { template in
                Text("Deleting “\(template.name)” will also remove all its history and streaks. To keep history, pause it instead.")
            }
        }
    }

    private var activeTemplates: [HabitTemplate] {
        templates.filter { $0.active }
    }

    private var inactiveTemplates: [HabitTemplate] {
        templates.filter { !$0.active }
    }
}

private struct HabitRow: View {
    let template: HabitTemplate

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(template.active ? Color.accentColor.opacity(0.18) : Color(.secondarySystemFill))
                    .frame(width: 40, height: 40)
                Image(systemName: template.category.systemImageName)
                    .foregroundStyle(template.active ? Color.accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text("\(formattedTarget) · \(template.frequency.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var formattedTarget: String {
        let value = template.targetValue.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(template.targetValue))
            : String(template.targetValue)
        return "\(value) \(template.unit)"
    }
}

#Preview {
    let container = try! ModelContainer(
        for: HabitTemplate.self, DailyHabit.self, CompletionLog.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    PreviewHelpers.insertSampleData(into: ModelContext(container))
    return HabitsView()
        .modelContainer(container)
}
