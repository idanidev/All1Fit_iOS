import SwiftUI

// MARK: - Tabata Form View
struct TabataFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tabataService: TabataService
    
    // Form state
    @State private var name: String = ""
    @State private var type: TabataType = .intervals
    @State private var workSeconds: Int = 30
    @State private var restSeconds: Int = 10
    @State private var rounds: Int = 8
    @State private var sets: Int = 1
    @State private var setRestSeconds: Int = 60
    
    // Treadmill phases
    @State private var treadmillPhases: [TreadmillPhase] = []
    @State private var showingAddPhase = false
    
    // Edit mode
    private let tabataToEdit: Tabata?
    private var isEditing: Bool { tabataToEdit != nil }
    
    @State private var isSaving = false
    
    // MARK: - Initializers
    
    init(type: TabataType = .intervals) {
        self.tabataToEdit = nil
        _type = State(initialValue: type)
    }
    
    init(tabataToEdit: Tabata) {
        self.tabataToEdit = tabataToEdit
        _name = State(initialValue: tabataToEdit.name)
        _type = State(initialValue: tabataToEdit.type)
        _workSeconds = State(initialValue: tabataToEdit.workSeconds)
        _restSeconds = State(initialValue: tabataToEdit.restSeconds)
        _rounds = State(initialValue: tabataToEdit.rounds)
        _sets = State(initialValue: tabataToEdit.sets)
        _setRestSeconds = State(initialValue: tabataToEdit.setRestSeconds)
        _treadmillPhases = State(initialValue: tabataToEdit.treadmillPhases ?? [])
    }
    
    // MARK: - Computed Properties
    
    private var totalDuration: Int {
        if type == .intervals {
            let roundDuration = workSeconds + restSeconds
            let setDuration = roundDuration * rounds
            let totalSetRest = max(0, sets - 1) * setRestSeconds
            return (setDuration * sets) + totalSetRest
        } else {
            return treadmillPhases.reduce(0) { $0 + ($1.durationMinutes * 60) }
        }
    }
    
    private var formattedDuration: String {
        let minutes = totalDuration / 60
        let seconds = totalDuration % 60
        if seconds == 0 {
            return "\(minutes) min"
        }
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (type == .intervals || !treadmillPhases.isEmpty)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section("Información") {
                    TextField("Nombre del Tabata", text: $name)
                    
                    if !isEditing {
                        Picker("Tipo", selection: $type) {
                            ForEach(TabataType.allCases, id: \.self) { type in
                                Label(type.displayName, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                    }
                }
                
                if type == .intervals {
                    // Intervals configuration
                    intervalsSection
                } else {
                    // Treadmill configuration
                    treadmillSection
                }
                
                // Preview
                Section("Vista Previa") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundStyle(type == .intervals ? .orange : .blue)
                            
                            Text(name.isEmpty ? "Mi Tabata" : name)
                                .font(.headline)
                        }
                        
                        if type == .intervals {
                            Text("\(workSeconds)s trabajo / \(restSeconds)s descanso × \(rounds) rondas")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(treadmillPhases.count) fases")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("Duración total: \(formattedDuration)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(isEditing ? "Editar Tabata" : "Nuevo Tabata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Guardar" : "Crear") {
                        saveTabata()
                    }
                    .disabled(!isValid || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingAddPhase) {
                TreadmillPhaseFormView { phase in
                    treadmillPhases.append(phase)
                }
            }
        }
    }
    
    // MARK: - Intervals Section
    private var intervalsSection: some View {
        Group {
            Section("Tiempos") {
                Stepper("Trabajo: \(workSeconds)s", value: $workSeconds, in: 10...120, step: 5)
                Stepper("Descanso: \(restSeconds)s", value: $restSeconds, in: 5...120, step: 5)
            }
            
            Section("Rondas") {
                Stepper("Rondas: \(rounds)", value: $rounds, in: 1...30)
                Stepper("Sets: \(sets)", value: $sets, in: 1...10)
                
                if sets > 1 {
                    Stepper("Descanso entre sets: \(setRestSeconds)s", value: $setRestSeconds, in: 30...300, step: 15)
                }
            }
        }
    }
    
    // MARK: - Treadmill Section
    private var treadmillSection: some View {
        Section("Fases") {
            ForEach(treadmillPhases) { phase in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(phase.name)
                            .font(.headline)
                        Spacer()
                        Text("\(phase.durationMinutes) min")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    
                    HStack(spacing: 16) {
                        Label("\(Int(phase.inclinePercent))%", systemImage: "arrow.up.right")
                        Label("\(String(format: "%.1f", phase.speedKmh)) km/h", systemImage: "speedometer")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    if !phase.description.isEmpty {
                        Text(phase.description)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete { indexSet in
                treadmillPhases.remove(atOffsets: indexSet)
            }
            .onMove { from, to in
                treadmillPhases.move(fromOffsets: from, toOffset: to)
            }
            
            Button {
                showingAddPhase = true
            } label: {
                Label("Añadir Fase", systemImage: "plus.circle.fill")
            }
        }
    }
    
    // MARK: - Save
    private func saveTabata() {
        isSaving = true
        
        let tabata = Tabata(
            id: tabataToEdit?.id ?? UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            workSeconds: workSeconds,
            restSeconds: restSeconds,
            rounds: rounds,
            sets: sets,
            setRestSeconds: setRestSeconds,
            treadmillPhases: type == .treadmill ? treadmillPhases : nil,
            exercises: nil,
            isCustom: true,
            createdAt: tabataToEdit?.createdAt ?? Date()
        )
        
        Task {
            do {
                try await tabataService.saveTabata(tabata)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                isSaving = false
            }
        }
    }
}

// MARK: - Treadmill Phase Form
struct TreadmillPhaseFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onSave: (TreadmillPhase) -> Void
    
    @State private var name = ""
    @State private var durationMinutes = 5
    @State private var inclinePercent: Double = 10
    @State private var speedKmh: Double = 4.0
    @State private var description = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre", text: $name)
                
                Stepper("Duración: \(durationMinutes) min", value: $durationMinutes, in: 1...30)
                
                VStack(alignment: .leading) {
                    Text("Inclinación: \(Int(inclinePercent))%")
                    Slider(value: $inclinePercent, in: 0...15, step: 1)
                }
                
                VStack(alignment: .leading) {
                    Text("Velocidad: \(String(format: "%.1f", speedKmh)) km/h")
                    Slider(value: $speedKmh, in: 2...8, step: 0.5)
                }
                
                TextField("Descripción (opcional)", text: $description)
            }
            .navigationTitle("Nueva Fase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Añadir") {
                        let phase = TreadmillPhase(
                            name: name.isEmpty ? "Fase \(durationMinutes)min" : name,
                            durationMinutes: durationMinutes,
                            inclinePercent: inclinePercent,
                            speedKmh: speedKmh,
                            description: description
                        )
                        onSave(phase)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TabataFormView()
        .environmentObject(TabataService())
}
