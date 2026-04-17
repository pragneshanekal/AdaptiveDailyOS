import SwiftUI
import SwiftData

struct OnboardingView: View {
    @State private var currentPage: Int = 0
    @State private var selectedHabits: Set<UUID> = []

    var body: some View {
        TabView(selection: $currentPage) {
            WelcomeScreen(currentPage: $currentPage)
                .tag(0)

            HabitPickerScreen(currentPage: $currentPage, selectedHabits: $selectedHabits)
                .tag(1)

            OnboardingCompleteScreen(selectedHabits: $selectedHabits)
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut, value: currentPage)
        .ignoresSafeArea()
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [HabitTemplate.self, DailyHabit.self, CompletionLog.self], inMemory: true)
        .environment(AppState())
}
