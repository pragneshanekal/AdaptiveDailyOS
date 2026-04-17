import SwiftUI
import SwiftData

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            ProgressView()
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: HabitTemplate.self, DailyHabit.self, CompletionLog.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    PreviewHelpers.insertSampleData(into: ModelContext(container))
    return MainTabView()
        .modelContainer(container)
        .environment(AppState())
}
