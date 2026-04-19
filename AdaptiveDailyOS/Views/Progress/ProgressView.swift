import SwiftUI
import SwiftData

struct ProgressView: View {
    @Query(filter: #Predicate<HabitTemplate> { $0.active })
    private var activeTemplates: [HabitTemplate]

    @Query private var allCompletionLogs: [CompletionLog]

    @Query private var allDailyHabits: [DailyHabit]

    @State private var showingHistoryCalendar = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statsRow
                    StreakCardView()
                    WeeklyBarChartView()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingHistoryCalendar) {
                HistoryCalendarView()
            }
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 12) {
            Button {
                showingHistoryCalendar = true
            } label: {
                StatTile(
                    value: "\(weeklyCompletionPercent)%",
                    label: "This week",
                    icon: "calendar.badge.checkmark",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens history calendar")

            StatTile(
                value: "\(allCompletionLogs.count)",
                label: "All-time logs",
                icon: "checkmark.seal.fill"
            )
            StatTile(
                value: "\(activeTemplates.count)",
                label: "Active habits",
                icon: "list.bullet.clipboard"
            )
        }
    }

    // MARK: - Computed

    private var weeklyCompletionPercent: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday)!

        let thisWeek = allDailyHabits.filter { $0.scheduledDate >= sevenDaysAgo }
        guard !thisWeek.isEmpty else { return 0 }
        let completed = thisWeek.filter { $0.status == .completed }.count
        return Int((Double(completed) / Double(thisWeek.count)) * 100)
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    var showsChevron: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .offset(x: 14, y: -8)
                }
            }
            .accessibilityHidden(true)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview {
    let container = try! ModelContainer(
        for: HabitTemplate.self, DailyHabit.self, CompletionLog.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    PreviewHelpers.insertSampleData(into: ModelContext(container))
    return ProgressView()
        .modelContainer(container)
}
