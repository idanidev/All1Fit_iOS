# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **IMPORTANT:** Before writing any UI code, read `design.md` in the project root. It is the single source of truth for all design decisions (colors, typography, spacing, gradients, component patterns). Every screen and component must follow it exactly.

## Build & Run Commands

```bash
# Build for simulator
xcodebuild -scheme "All1Fit" -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Build for device
xcodebuild -scheme "All1Fit" -configuration Debug -destination 'name=iPhone de Daniel' build

# Build Watch app
xcodebuild -scheme "All1FitWatch Watch App" -configuration Debug build

# Install and run on device (custom script)
./run_on_device.sh

# Run tests (Swift Testing, target All1FitTests)
xcodebuild test -scheme "All1Fit" -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' ENABLE_TESTABILITY=YES

# Reset SPM packages if dependencies fail
# In Xcode: File > Packages > Reset Package Caches
```

Unit tests live in `All1FitTests/` (Swift Testing framework, NOT XCTest): gym models, plan generator, session service logic and `ExerciseBrain`. A pre-push hook runs the suite (`git config core.hooksPath scripts/git-hooks` to activate per clone). No linter is configured.

**IMPORTANT:** el scheme completo requiere la plataforma watchOS instalada (embebe la app del Watch). Si `xcodebuild` falla con "watchOS X.Y must be installed", descargarla con `xcodebuild -downloadPlatform watchOS`.

## Architecture

**SwiftUI app targeting iOS 17+ / watchOS.** Uses Swift Package Manager with Firebase iOS SDK (11.0.0+) and GoogleSignIn (8.0.0+).

### Targets
- **All1Fit** — Main iOS app
- **All1FitWatch Watch App** — Apple Watch companion
- **All1FitWidgetsExtension** — Live Activities (Dynamic Island for Tabata timer)

### Data Flow
```
RootView (auth state machine)
  → SplashView        (while AuthService.isReady == false)
  → PremiumOnboardingView  (first launch, unauthenticated)
  → LoginView          (unauthenticated, onboarding complete)
  → MainTabView        (authenticated — 5 tabs)
```

Tabs: Inicio(0), RMs(1), Entreno(2, `TrainingHubView` — landing que fusiona WODs y Tabatas), Gym(3, `GymHubView`), Ajustes(4). `WorkoutsView` y `TabataListView` NO llevan `NavigationStack` propio: van pushed desde `TrainingHubView`.

Services are `@MainActor` `ObservableObject` classes injected via `@EnvironmentObject`. Views observe them with `@StateObject`. Excepción: `GymSessionService` vive en `MainTabView` (compartido con el mini player flotante y el logger a pantalla completa) y se inyecta explícitamente por parámetro.

### Key Services
| Service | Responsibility |
|---------|---------------|
| `AuthService` | Firebase Auth (Email, Apple SIWA, Google OAuth) |
| `EjercicioService` | RM exercise CRUD with optimistic local-first updates |
| `WorkoutService` | Workout history persistence |
| `TabataService` | Tabata CRUD |
| `TabataSessionManager` | Active timer session state, haptics, phases |
| `TabataActivityManager` | Live Activity lifecycle |
| `PhoneConnectivityService` | WatchConnectivity bridge (JSON serialization, background transfer) |
| `GymRoutineService` | Rutinas de gym (CRUD, carpetas/programas) |
| `GymSessionService` | Sesión activa de gym (snapshot en UserDefaults, doble progresión, PRs) + historial |
| `BodyMeasurementService` | Medidas corporales |
| `CustomExerciseService` | Ejercicios propios del usuario + favoritos (UserDefaults) |

### Gym (sección)
- Catálogo estático en `GymExerciseCatalog` (`Models/GymExercise.swift`); ejercicios propios en Firestore.
- `GymPlanGenerator` (`Models/`) genera programas desde el cuestionario (`GymPlanWizardView`) con prescripciones basadas en metaanálisis 2024-2026 (RIR, descansos, superseries antagonistas para pérdida de grasa). Es determinista y está testeado — si se cambian esquemas, actualizar `GymPlanGeneratorTests`.
- El logger (`ActiveGymSessionView`) se minimiza a `GymMiniPlayer`; los pesos se almacenan SIEMPRE en kg y se convierten en UI con `WeightUnit`.

### Firestore Structure
All data is user-scoped: `/users/{uid}/ejercicios`, `/users/{uid}/workoutResults`, `/users/{uid}/tabataResults`, `/users/{uid}/gymRoutines`, `/users/{uid}/gymSessions`, `/users/{uid}/bodyMeasurements`, `/users/{uid}/customExercises`. Offline persistence is enabled with a 100MB cache. Services use a 30-second query cache to avoid redundant fetches.

### Domain Language
The codebase uses **Spanish** for domain terms (Ejercicio = Exercise, Porcentajes = Percentages, entrenamientos = workouts). Code structure keywords (Services, Views, Models, Utils) are in English.

### Design System
`All1FitDesignSystem.swift` is the canonical source for colors, typography, spacing, and component styles. `ModernDesignSystem.swift` exists as a legacy compatibility stub. Use `All1FitDesignSystem` for all new work.

- Dark theme with pure black backgrounds
- Accent gradients: Orange→Red (RMs), Blue→Cyan (Tabata), Purple→Pink (Workouts)
- Glass effects via `ultraThinMaterial` with white overlays
- Spacing scale: xxs(4), xs(8), sm(12), md(16), lg(20), xl(24), xxl(32), xxxl(40)

### Muscle Detection
`Ejercicio` model auto-detects muscle groups from exercise names via regex matching (e.g., "bench" → Chest, "squat" → Legs). This also drives the icon selection (Olympic lifts vs. isolation exercises).

### Watch Connectivity
`PhoneConnectivityService.shared` syncs ejercicios, tabatas, and workouts to the Watch via `transferUserInfo` (reliable queued transfer). Uses JSON serialization for complex models and timestamp-based conflict resolution.

## Conventions

- All services use `@MainActor` for thread safety
- Optimistic UI updates: mutate local state first, then sync to Firestore
- File organization: one view/model/service per file
- `MARK:` comments for logical sections within files
- Accessibility: VoiceOver labels, `accessibilityReduceMotion` checks on infinite animations
- Firebase `GoogleService-Info.plist` is not in the repo — must be downloaded from Firebase Console and placed in `All1Fit/`
