import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext

    // @Query requires the predicate dates to be captured at init time.
    @Query private var todayHabits: [DailyHabit]

    @State private var habitForLogging: DailyHabit?

    init() {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!
        _todayHabits = Query(
            filter: #Predicate<DailyHabit> { habit in
                habit.scheduledDate >= startOfToday && habit.scheduledDate < startOfTomorrow
            },
            sort: \DailyHabit.scheduledDate
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    progressHeader
                    habitList
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                HabitScheduler.scheduleHabitsForDate(Date(), context: modelContext)
                HabitScheduler.markMissedHabits(before: Date(), context: modelContext)
            }
            .sheet(item: $habitForLogging) { habit in
                LogHabitSheet(dailyHabit: habit)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Subviews

    private var progressHeader: some View {
        HStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 10)
                    .frame(width: 84, height: 84)

                Circle()
                    .trim(from: 0, to: completionFraction)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 84, height: 84)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: completionFraction)

                VStack(spacing: 0) {
                    Text("\(completedCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("of \(totalCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("\(completedCount) of \(totalCount) habits done")

            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle)
                    .font(.headline)
                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private var habitList: some View {
        if todayHabits.isEmpty {
            ContentUnavailableView(
                "No Habits Today",
                systemImage: "sparkles",
                description: Text("Complete onboarding to schedule your first habits.")
            )
            .padding(.top, 40)
        } else {
            // Pending first, then completed/skipped, each group sorted by name.
            let pending   = todayHabits.filter { $0.status == .pending }
            let completed = todayHabits.filter { $0.status != .pending }

            LazyVStack(spacing: 12) {
                ForEach(pending)   { habit in habitRow(habit) }
                ForEach(completed) { habit in habitRow(habit) }
            }
        }
    }

    private func habitRow(_ habit: DailyHabit) -> some View {
        HabitRowView(dailyHabit: habit) {
            habitForLogging = habit
        }
    }

    // MARK: - Computed properties

    private var completedCount: Int { todayHabits.filter { $0.status == .completed }.count }
    private var totalCount: Int { todayHabits.count }
    private var completionFraction: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }

    private var formattedDate: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var headerTitle: String {
        if totalCount == 0 { return "No habits yet" }
        if completedCount == totalCount { return "All done!" }
        return "\(totalCount - completedCount) remaining"
    }

    private var headerSubtitle: String {
        if totalCount == 0 { return "Add habits to get started" }
        if completedCount == totalCount { return "Great work today " }
        return "Keep going, you've got this"
    }
}

#Preview {
    let container = try! ModelContainer(
        for: HabitTemplate.self, DailyHabit.self, CompletionLog.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    PreviewHelpers.insertSampleData(into: ModelContext(container))
    return TodayView()
        .modelContainer(container)
        .environment(AppState())
}
