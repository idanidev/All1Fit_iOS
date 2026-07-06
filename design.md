# All1Fit Design System

> Source of truth for all UI decisions. Every new screen, component, and feature must follow these rules exactly. Claude Code must reference this file on every prompt.

---

## Brand Identity

**App name:** All1Fit
**Platform:** iOS 17+ / watchOS
**Tone:** Athletic, premium, dark-mode-first. Inspired by Nike Training Club, Hevy, and Strong.
**Core principle:** Heavy numbers, strong gradients, glass layers over pure black. Never flat. Never light.

---

## Color System

### Primary Brand Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `all1FitOrange` | `#FF9500` | RMs, primary CTA, accent |
| `all1FitRed` | `#FF453A` | Danger, RM gradient end |
| `all1FitPurple` | `#BF5AF2` | Workouts, WOD |
| `all1FitBlue` | `#0A84FF` | Tabata, gym exercises |
| `all1FitCyan` | `#30D1F2` | Tabata gradient end |
| `all1FitPink` | `#FF3890` | Workout gradient end |

### Semantic Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `all1FitSuccess` | `#30D158` | Completion, positive progression |
| `all1FitWarning` | `#FFD000` | Caution, set rest |
| `all1FitError` | `#FF453A` | Errors, destructive actions |

### Background Colors (Dark-mode first)

| Token | Hex | Usage |
|-------|-----|-------|
| `all1FitBackground` | `#000000` | Page background (pure black) |
| `all1FitBackgroundSecondary` | `#1C1C1E` | Cards, grouped backgrounds |
| `all1FitBackgroundTertiary` | `#2C2C2E` | Tertiary inputs, separators |

**SwiftUI:** Use `Color(uiColor: .systemBackground)`, `Color(uiColor: .secondarySystemGroupedBackground)`, and `Color(uiColor: .tertiarySystemGroupedBackground)` to automatically respect the system dark/light preference.

### Section Accent Gradients

Each main section of the app has a locked gradient identity:

| Section | Gradient | Colors |
|---------|----------|--------|
| **RMs / Haltero** | Orange → Red | `[.orange, .red]` |
| **Gym / Dumbbell** | Blue → Cyan | `[.blue, .cyan]` |
| **Gimnástico** | Green → Teal | `[.green, .teal]` |
| **Workouts / WOD** | Purple → Pink | `[.all1FitPurple, .all1FitPink]` |
| **Tabata** | Blue → Cyan | `[.all1FitBlue, .all1FitCyan]` |
| **CrossFit** | Red → Pink | `[.all1FitRed, .pink]` |
| **Running** | Orange → Yellow | `[.all1FitOrange, .yellow]` |

**Rule:** Never mix section gradients. RMs are always orange. Tabata is always blue. Workouts are always purple.

### Color Usage Rules

- **DO** use gradient overlays at 10–15% opacity for card backgrounds
- **DO** use `ultraThinMaterial` for glass effects
- **DO** use `.opacity(0.12)` tinted backgrounds on icon containers
- **DON'T** use solid bright colors as full backgrounds
- **DON'T** use white backgrounds in dark mode
- **DON'T** mix more than two gradient colors in a single element

---

## Typography System

### Scale

| Token | Size | Weight | Design | Usage |
|-------|------|--------|--------|-------|
| `all1FitDisplayLarge` | 64pt | Bold | Rounded | Hero numbers (timers, big RM) |
| `all1FitDisplayMedium` | 48pt | Bold | Rounded | Section hero stats |
| `all1FitDisplaySmall` | 36pt | Bold | Rounded | Stat cards |
| `all1FitHeadlineLarge` | 28pt | Bold | Rounded | Screen titles |
| `all1FitHeadlineMedium` | 22pt | Semibold | Rounded | Section headers |
| `all1FitHeadlineSmall` | 18pt | Semibold | Rounded | Card headers |
| `all1FitBodyLarge` | 17pt | Regular | Default | Primary body text |
| `all1FitBodyMedium` | 15pt | Regular | Default | Secondary body |
| `all1FitBodySmall` | 13pt | Regular | Default | Tertiary text |
| `all1FitLabelLarge` | 14pt | Semibold | Default | Labels, tags |
| `all1FitLabelMedium` | 12pt | Semibold | Default | Small labels |
| `all1FitLabelSmall` | 10pt | Medium | Default | Badges, micro labels |
| `all1FitCaption` | 11pt | Regular | Default | Captions, footnotes |

### Typography Rules

- **Hero numbers** (RM values, timer countdown, rep counts): always `.rounded` design, **Bold** or **Black** weight
- **Section headers** within cards: `.headline` or `all1FitHeadlineSmall`
- **Body content**: system default design (not rounded)
- **Badges and tags**: `.bold` or `.semibold`, `.uppercase` optional
- **Gradient text**: Apply `LinearGradient` via `.foregroundStyle()` on big numbers and hero labels only
- **Never** use thin or ultraLight weights — app is athletic, weights should feel strong

---

## Spacing System

| Token | Value | Usage |
|-------|-------|-------|
| `xxxs` | 2pt | Micro gaps |
| `xxs` / `Layout.xxs` | 4pt | Icon-to-label gaps |
| `xs` / `Layout.xs` | 8pt | Between chips, tight groups |
| `sm` / `Layout.sm` | 12pt | Between list rows, compact sections |
| `md` / `Layout.md` | 16pt | Standard padding, card internal spacing |
| `lg` / `Layout.lg` | 24pt | Between sections |
| `xl` / `Layout.xl` | 32pt | Major section breaks |
| `xxl` / `Layout.xxl` | 48pt | Hero section padding |
| `xxxl` | 64pt | Full-screen top padding |

**Preferred VStack/HStack spacing by context:**
- List rows: `spacing: 0` (use Divider)
- Card internal sections: `spacing: 12–16`
- Page-level VStack: `spacing: 24`
- Chip rows / tag rows: `spacing: 8`

---

## Corner Radius System

| Token | Value | Usage |
|-------|-------|-------|
| `radiusSm` / `xs` | 8pt | Small chips, tags, table cells |
| `radiusMd` / `sm` | 12pt | Input fields, compact cards |
| `radiusLg` / `lg` | 20pt | Standard cards, chart containers |
| `radiusXl` / `xl` | 24pt | Sheets, large cards |
| `round` | 999pt | Capsule/pill shapes, avatar circles |

**Rule:** Prefer `RoundedRectangle(cornerRadius:)` over `.clipShape(Capsule())` unless the element is explicitly pill-shaped.

---

## Shadow System

| Level | Color | Radius | Offset |
|-------|-------|--------|--------|
| Small | black 10% | 4 | y: 2 |
| Medium | black 15% | 8 | y: 4 |
| Large | black 20% | 16 | y: 8 |
| Colored | brand color 30% | 12 | y: 6 |

**Rule:** Use colored shadows on primary action buttons matching their gradient color. Use medium shadow on cards. Never use drop shadows on backgrounds or full-width containers.

---

## Animation System

| Token | Type | Duration | Usage |
|-------|------|----------|-------|
| `all1FitSpring` | spring(0.4, 0.7) | — | State transitions, selections |
| `all1FitQuick` | easeInOut | 0.2s | Button press, toggle |
| `all1FitSmooth` | easeInOut | 0.3s | Sheet, modal, expand |
| `all1FitSlow` | easeInOut | 0.5s | Hero entrance, chart |

**Rules:**
- Chart animations: `.spring(duration: 0.8).delay(0.3)` on appear
- Number transitions: always use `.contentTransition(.numericText())`
- Scale press feedback: `scaleEffect(0.96)` on button press
- Always pair with haptic feedback for taps

---

## Haptic Feedback Rules

| Action | Haptic |
|--------|--------|
| Light tap (chip, filter, toggle) | `UIImpactFeedbackGenerator(.light)` |
| Standard button tap | `UIImpactFeedbackGenerator(.medium)` |
| Save / confirm | `UINotificationFeedbackGenerator(.success)` |
| Error | `UINotificationFeedbackGenerator(.error)` |
| Phase transition (Tabata) | `UINotificationFeedbackGenerator(.success)` |

---

## Component Patterns

### Cards

All cards use `Color(uiColor: .secondarySystemGroupedBackground)` as background, clipped to `RoundedRectangle(cornerRadius: 16–20)`.

```swift
// Standard card
VStack(...) { ... }
    .padding()
    .background(Color(uiColor: .secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
```

**Glass card (premium/hero):**
```swift
.background(.ultraThinMaterial)
.overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
.clipShape(RoundedRectangle(cornerRadius: 20))
```

### Stat Cards (`StatCard`)

4-up grid layout (2×2). Each card has:
- Icon in brand color (top left)
- Large bold value
- Small secondary label below
- Background: `secondarySystemGroupedBackground`
- Corner radius: 16pt

### Hero Stats Section

Every detail screen opens with a hero stats section:
- Radial gradient glow behind the main number (brand color, 35% opacity, blurred 30pt)
- Large display number with gradient foreground (56–64pt, `.black` weight)
- Style/category badge below (capsule, brand color, 12% opacity background)
- Progression indicator (green/red capsule with arrow icon)

### Buttons

**Primary action (full-width):**
- Gradient fill (section gradient)
- Capsule or `RoundedRectangle(cornerRadius: 14)`
- Colored shadow matching gradient
- White text, semibold

**Secondary/ghost:**
- `.ultraThinMaterial` background
- White or brand color text

**Icon buttons (toolbar):**
- `Image(systemName:)` only, no background
- Size: `.title2` in toolbar, `.system(size: 24)` inline

### Chips / Filter Tags

```swift
Text(label)
    .font(.system(.subheadline, design: .rounded, weight: .semibold))
    .foregroundStyle(isSelected ? .white : .primary)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(isSelected ? AnyShapeStyle(Color.orange) : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)))
    .clipShape(Capsule())
```

Active chips use the section's brand color. Inactive chips use `secondarySystemGroupedBackground`.

### Stepper / Numeric Input

For rep counts and values with increments, use large visual stepper:
- Minus/plus buttons: `minus.circle.fill` / `plus.circle.fill`, 36–40pt, brand color
- Center number: 52–56pt, `.black` weight, `.rounded` design, brand color
- Background: `secondarySystemGroupedBackground`, cornerRadius: 16
- Always pair with quick-preset chips below

### List Rows

- Use `LazyVStack(spacing: 0)` with manual `Divider().padding(.leading, X)` for rows
- Internal padding: `.padding()` (16pt all sides)
- Background: `secondarySystemGroupedBackground`
- Clip entire container with `RoundedRectangle(cornerRadius: 16)`
- First row: crown/trophy icon in yellow if it's the top result
- Numbered: `#N` in `.caption` secondary for others

### Section Headers

```swift
HStack {
    Label("Título", systemImage: "icon")
        .font(.headline)
    Spacer()
    // Optional: subtitle or action
    Text("valor")
        .font(.subheadline.bold())
        .foregroundStyle(brandColor)
}
```

---

## Screen Layout Pattern

Every screen follows this vertical structure:

```
1. NavigationStack (title: .inline or .large)
2. ScrollView
   └── VStack(spacing: 24)
       ├── Hero / Stats section     (top, .padding(.top))
       ├── Segmented picker         (time range or filter)
       ├── Chart / main content     (if applicable)
       ├── Data table / percentages (section-specific)
       ├── Statistics grid (2×2)
       └── History / list section
3. Toolbar: leading = edit/secondary, trailing = primary action (+)
```

**Background:** `Color(uiColor: .systemGroupedBackground).ignoresSafeArea()`

---

## Navigation & Sheets

- Sheets use `.presentationDetents([.fraction(0.7), .large])` for forms
- Full detail views use `NavigationStack` push
- Edit sheets use `.presentationDetents([.large])`
- All sheets: `.presentationDragIndicator(.visible)`, `.presentationCornerRadius(24)`

---

## Tab Structure

| Tab | Index | Icon | Gradient |
|-----|-------|------|----------|
| Inicio | 0 | `house.fill` | — |
| RMs | 1 | `figure.strengthtraining.traditional` | Orange → Red |
| Entreno | 2 | `figure.run` | Purple → Pink |
| Gym | 3 | `dumbbell.fill` | Blue → Cyan |
| Ajustes | 4 | `gearshape.fill` | — |

**Tint:** `.orange` globally

- **Entreno** fusiona WODs y Tabatas: landing con dos tarjetas hero que navegan a cada lista (`TrainingHubView`). Las listas NO llevan `NavigationStack` propio (van pushed).
- **Gym** es el hub de entrenamiento de gimnasio: sesión activa (con mini player flotante al minimizar, como el de Tabata), rutinas, biblioteca de ejercicios, progreso, medidas y plan a medida.

### Confirmaciones

Las acciones destructivas o importantes usan `All1FitConfirmation` (`Views/Components/All1FitConfirmationSheet.swift`), NO el `confirmationDialog` del sistema: sheet con icono con glow, título grande, mensaje con contexto y botón degradado (rojo destructivo / azul), con acción secundaria opcional. Nuevas confirmaciones deben usar este componente.

---

## Exercise Style System

| Style | Label | Icon | Color | Gradient |
|-------|-------|------|-------|----------|
| `.barbell` | Haltero | `figure.strengthtraining.traditional` | Orange | Orange → Red |
| `.dumbbell` | Gym | `dumbbell.fill` | Blue | Blue → Cyan |
| `.gymnastic` | Gimnástico | `figure.gymnastics` | Green | Green → Teal |

Exercise style drives: icon color, progress bar color, chart color, filter chip color.

---

## Charts (Swift Charts)

- Line: gradient stroke, `lineWidth: 3`, `.catmullRom` interpolation
- Area: gradient fill, 0%→30% opacity top to bottom
- Points: brand color, `symbolSize: 80`
- Y-axis: `.leading` position
- X-axis: 3 labels max, `.caption2` font
- Chart height: 220pt
- Background: `secondarySystemGroupedBackground`, cornerRadius: 20
- Animate with `chartAnimated` flag on `.onAppear`

---

## Percentage / Rep Tables

Tables use `LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8)`.

Each cell:
- Label: colored based on intensity (red→orange→yellow→green→teal→blue→indigo→purple for 100%→30%)
- Value: bold, same color
- Background: color at `.opacity(0.08)`
- Corner radius: 8–10pt

---

## Dos and Don'ts

### DO
- Use pure black (`#000000`) as the primary page background
- Apply radial gradient glows behind hero numbers
- Use `.rounded` design for all numeric displays
- Add `contentTransition(.numericText())` to all changing numbers
- Use `.ultraThinMaterial` for overlays and glass cards
- Show exercise/section color consistently (orange = RM, blue = gym, purple = workout)
- Add haptic feedback to every meaningful interaction
- Use `LazyVStack` and `LazyVGrid` for lists with many items
- Apply `@MainActor` to all service classes
- Use optimistic UI updates (local state first, then Firestore)

### DON'T
- Use white or light backgrounds (dark mode first)
- Use flat/solid fills for primary buttons
- Mix section gradients (RM orange never appears in Tabata blue section)
- Use `List` with default styles — prefer custom `LazyVStack` with manual dividers
- Add animations longer than 0.5s on repeated/frequent UI
- Use `Stepper` system component for numeric inputs — use custom visual stepper
- Use `.picker` for reps/weight — use visual stepper or chip presets
- Skip haptic feedback on button taps
- Use more than 2 font weights on a single card
- Use emojis in production UI (only in display names / user content)

---

## Localization

Domain terms are in **Spanish** throughout the codebase:
- `Ejercicio` = Exercise
- `Entreno` / `Entrenamiento` = Workout
- `Tabata` = Tabata (same)
- `Porcentajes` = Percentages
- `RM` = Rep Max (abbreviation stays as RM)
- `Haltero` = Barbell/Olympic lifting style
- `Gimnástico` = Gymnastic/Calisthenics style

UI strings are in Spanish. Code structure (Services, Views, Models) is in English.

---

## Firebase / Data Constraints

- All user data: `/users/{uid}/ejercicios`, `/users/{uid}/workoutResults`, `/users/{uid}/tabataResults`
- Offline persistence: enabled, 100MB cache
- Cache timeout per service: 30 seconds
- Updates use optimistic local mutations first, then Firestore sync
- RMs: use `FieldValue.arrayUnion` for appending, full array rewrite for edit/delete

---

*Last updated: 2026-03-30 — All1Fit v1.x*
