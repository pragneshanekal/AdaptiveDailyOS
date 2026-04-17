import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        if appState.hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}

#Preview("Onboarding") {
    let state = AppState()
    return RootView()
        .modelContainer(for: [HabitTemplate.self, DailyHabit.self, CompletionLog.self], inMemory: true)
        .environment(state)
}

#Preview("Main App") {
    let state = AppState()
    state.completeOnboarding()
    return RootView()
        .modelContainer(for: [HabitTemplate.self, DailyHabit.self, CompletionLog.self], inMemory: true)
        .environment(state)
}
