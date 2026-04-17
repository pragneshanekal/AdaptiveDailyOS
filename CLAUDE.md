# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

iOS habit tracker with AI adaptation. SwiftUI + SwiftData.
Target: iOS 17+. Language: Swift 5.9.

## Commands

```bash
# Build for iOS Simulator
xcodebuild build -scheme AdaptiveDailyOS -destination "platform=iOS Simulator,name=iPhone 16"

# Run all tests
xcodebuild test -scheme AdaptiveDailyOS -destination "platform=iOS Simulator,name=iPhone 16"

# Run a single test file (unit tests use Swift Testing framework)
xcodebuild test -scheme AdaptiveDailyOS -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:AdaptiveDailyOSTests/AdaptiveDailyOSTests

# Clean build
xcodebuild clean -scheme AdaptiveDailyOS

# Build for device (no signing configured yet)
xcodebuild build -scheme AdaptiveDailyOS -destination "generic/platform=iOS"
```

No linter is configured. Xcode's built-in Swift compiler warnings serve as the lint signal.

## Architecture

**No ViewModels.** Views use `@Query` and `@Environment` directly. Do not introduce a ViewModel layer.

```
AdaptiveDailyOS/
├── Models/          # SwiftData @Model classes
├── Views/
│   ├── Today/       # Today tab views
│   └── Progress/    # Progress tab views
└── Services/
    └── AIService.swift   # Phase 2 only — AI calls isolated here
```

The app entry point (`AdaptiveDailyOSApp.swift`) owns the `ModelContainer` and injects it via `.modelContainer()`. Views receive the container through `@Environment(\.modelContext)` and query with `@Query`.

Unit tests use the **Swift Testing** framework (`@Test` annotation). UI tests use XCTest. For unit tests that need SwiftData, configure an in-memory `ModelContainer` — see `ContentView.swift`'s preview for the pattern.

## Data Models

Defined in `/Models` as SwiftData `@Model` classes:

| Model | Key fields |
|---|---|
| `HabitTemplate` | id, name, category, targetValue, unit, frequency, difficultyScore, active |
| `DailyHabit` | id, templateId, scheduledDate, adaptedTarget, adaptedReason, status |
| `CompletionLog` | id, dailyHabitId, completedAt, valueLogged, note |
| `WeeklyPlan` | id, userId, weekStart, aiPlanSnapshot, predictedRate, actualRate |
| `AdaptationEvent` | id, planId, habitAffected, triggerReason, beforeState, afterState |

## Phase 1 Scope

Local only. No networking. No AI calls.
Focus: working Today tab, Progress tab, onboarding flow, and streak logic.

`AIService.swift` should not exist yet — create it only when Phase 2 begins.

## Coding Standards

- SwiftUI preview on every view
- Descriptive variable names, no abbreviations
- Comments only on non-obvious logic (hidden constraints, subtle invariants, workarounds)
- No third-party dependencies in Phase 1
