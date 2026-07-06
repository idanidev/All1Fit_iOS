import SwiftUI

// MARK: - Lista de Rutinas
/// Rutinas guardadas: crear, editar, borrar y empezar entrenamiento.
struct RoutineListView: View {
    @ObservedObject var routineService: GymRoutineService
    @ObservedObject var sessionService: GymSessionService

    @State private var showingBuilder = false
    @State private var editingRoutine: GymRoutine?
    @State private var errorMessage: String?

    /// Rutinas agrupadas por programa (sin programa al final)
    private var groupedRoutines: [(folder: String?, routines: [GymRoutine])] {
        let grouped = Dictionary(grouping: routineService.routines) { $0.folder }
        let named = grouped
            .compactMap { key, value in key.map { (folder: Optional($0), routines: value) } }
            .sorted { ($0.folder ?? "") < ($1.folder ?? "") }
        let unfiled = grouped[nil].map { [(folder: String?.none, routines: $0)] } ?? []
        return named + unfiled
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if routineService.isLoading && routineService.routines.isEmpty {
                    loadingSection
                } else if routineService.routines.isEmpty {
                    emptySection
                    starterSection
                } else {
                    ForEach(Array(groupedRoutines.enumerated()), id: \.offset) { _, group in
                        if let folder = group.folder {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.all1FitBlue)
                                Text(folder)
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                Spacer()
                                Text("\(group.routines.count)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 6)
                        }
                        ForEach(group.routines) { routine in
                            RoutineCard(
                                routine: routine,
                                onStart: { startSession(routine) },
                                onEdit: { editingRoutine = routine },
                                onDuplicate: { duplicateRoutine(routine) },
                                onDelete: { deleteRoutine(routine) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Rutinas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showingBuilder = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                }
            }
        }
        .sheet(isPresented: $showingBuilder) {
            RoutineBuilderView(routineService: routineService, routine: nil)
        }
        .sheet(item: $editingRoutine) { routine in
            RoutineBuilderView(routineService: routineService, routine: routine)
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task { await routineService.fetchRoutines() }
    }

    // MARK: - Actions

    private func startSession(_ routine: GymRoutine) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        sessionService.startSession(from: routine)
    }

    private func deleteRoutine(_ routine: GymRoutine) {
        guard let id = routine.id else { return }
        Task {
            do {
                try await routineService.deleteRoutine(id: id)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func duplicateRoutine(_ routine: GymRoutine) {
        Task {
            do {
                try await routineService.createRoutine(routine.duplicated())
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Rutinas de ejemplo

    private var starterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: [.all1FitBlue, .all1FitCyan.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 3, height: 18)
                Text("O empieza con una de ejemplo")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .padding(.top, 16)

            ForEach(Array(GymRoutine.starterRoutines.enumerated()), id: \.offset) { _, starter in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(starter.name)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                        Text("\(starter.exercises.count) ejercicios · \(starter.totalSets) series")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        Task {
                            do {
                                try await routineService.createRoutine(starter)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        Text("Añadir")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Empty / Loading

    private var loadingSection: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(height: 110)
                    .shimmer()
            }
        }
    }

    private var emptySection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [.all1FitBlue.opacity(0.25), .clear], center: .center, startRadius: 0, endRadius: 70))
                    .frame(width: 140, height: 140)
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

            VStack(spacing: 6) {
                Text("Sin rutinas aún")
                    .font(.title3.bold())
                Text("Crea tu primera rutina para entrenar más rápido")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showingBuilder = true
            } label: {
                Text("Crear rutina")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 48)
    }
}

// MARK: - Tarjeta de rutina
struct RoutineCard: View {
    let routine: GymRoutine
    let onStart: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(routine.name)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .lineLimit(1)
                    Text("\(routine.exercises.count) ejercicios · \(routine.totalSets) series")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button { onEdit() } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    Button { onDuplicate() } label: {
                        Label("Duplicar", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) { onDelete() } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Opciones de \(routine.name)")
            }

            if let notes = routine.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if !routine.muscleGroups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(routine.muscleGroups, id: \.self) { muscle in
                            Text(muscle.rawValue)
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(muscle.color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(muscle.color.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Button {
                onStart()
            } label: {
                Label("Empezar", systemImage: "play.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .shadow(color: .all1FitBlue.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }
        }
    }
}

#Preview {
    NavigationStack {
        RoutineListView(routineService: GymRoutineService(), sessionService: GymSessionService())
    }
    .preferredColorScheme(.dark)
}
