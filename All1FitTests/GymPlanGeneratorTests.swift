import Testing
@testable import All1Fit

// MARK: - Generador de planes a medida
@Suite("GymPlanGenerator")
struct GymPlanGeneratorTests {

    private func prefs(goal: GymGoal = .hipertrofia,
                       experience: GymExperience = .intermedio,
                       days: Int = 3,
                       equipment: GymEquipmentAccess = .gimnasioCompleto) -> GymPlanPreferences {
        GymPlanPreferences(goal: goal, experience: experience, daysPerWeek: days, equipment: equipment)
    }

    @Test("Número de rutinas según días", arguments: [(2, 2), (3, 3), (4, 4), (5, 5)])
    func routineCount(days: Int, expected: Int) {
        let plan = GymPlanGenerator.makePlan(from: prefs(days: days))
        #expect(plan.count == expected)
    }

    @Test("3 días: principiante recibe Full Body, intermedio recibe PPL")
    func threeDaySplitByExperience() {
        let beginner = GymPlanGenerator.makePlan(from: prefs(experience: .principiante, days: 3))
        #expect(beginner.allSatisfy { $0.name.hasPrefix("Full Body") })

        let intermediate = GymPlanGenerator.makePlan(from: prefs(experience: .intermedio, days: 3))
        let names = intermediate.map(\.name)
        #expect(names.contains("Push (Empuje)"))
        #expect(names.contains("Pull (Tirón)"))
        #expect(names.contains("Legs (Pierna)"))
    }

    @Test("El esquema distingue básicos y aislamiento (evidencia 2024-2026)")
    func goalSchemeApplied() {
        let plan = GymPlanGenerator.makePlan(from: prefs(goal: .fuerza))
        var checkedCompound = false
        var checkedIsolation = false

        for exercise in plan.flatMap(\.exercises) {
            guard let catalogEntry = exercise.catalogExercise else { continue }
            if catalogEntry.primaryMuscle == .abs || catalogEntry.primaryMuscle == .calves {
                #expect(exercise.reps == 15, "\(exercise.exerciseName)")
            } else if catalogEntry.secondaryMuscles.isEmpty {
                // Aislamiento en fuerza: 3×8, descanso 120s
                let matches = exercise.sets == 3 && exercise.reps == 8 && exercise.restSeconds == 120
                #expect(matches, "\(exercise.exerciseName)")
                checkedIsolation = true
            } else {
                // Básicos en fuerza: 4×4, descanso 210s (RIR 2-3, la fuerza no exige fallo)
                let matches = exercise.sets == 4 && exercise.reps == 4 && exercise.restSeconds == 210
                #expect(matches, "\(exercise.exerciseName)")
                checkedCompound = true
            }
        }
        #expect(checkedCompound)
        #expect(checkedIsolation)
    }

    @Test("Pérdida de grasa genera superseries antagonistas")
    func fatLossSupersets() {
        let plan = GymPlanGenerator.makePlan(from: prefs(goal: .perderGrasa, days: 4))
        let paired = plan.flatMap(\.exercises).filter { $0.supersetGroup != nil }
        #expect(!paired.isEmpty)

        let antagonists: [Set<BodyPart>] = [[.chest, .back], [.biceps, .triceps], [.quads, .hamstrings]]
        for routine in plan {
            let groups = Dictionary(grouping: routine.exercises.filter { $0.supersetGroup != nil },
                                    by: { $0.supersetGroup ?? 0 })
            for (_, pair) in groups {
                #expect(pair.count == 2)
                let muscles = Set(pair.compactMap { $0.catalogExercise?.primaryMuscle })
                #expect(antagonists.contains(muscles), "\(pair.map(\.exerciseName))")
            }
        }
    }

    @Test("El resto de objetivos no lleva superseries y toda rutina lleva pauta")
    func notesAndNoSupersetsForOtherGoals() {
        for goal in [GymGoal.fuerza, .hipertrofia, .general] {
            let plan = GymPlanGenerator.makePlan(from: prefs(goal: goal))
            let hasNotes = plan.allSatisfy { $0.notes?.isEmpty == false }
            #expect(hasNotes)
            let noSupersets = plan.flatMap(\.exercises).allSatisfy { $0.supersetGroup == nil }
            #expect(noSupersets)
        }
    }

    @Test("Plan de peso corporal: solo ejercicios sin material")
    func bodyweightOnly() {
        let plan = GymPlanGenerator.makePlan(from: prefs(equipment: .pesoCorporal))
        for routine in plan {
            #expect(!routine.exercises.isEmpty, "\(routine.name) quedó vacía")
            for exercise in routine.exercises {
                let catalogEntry = GymExerciseCatalog.exercise(named: exercise.exerciseName)
                #expect(catalogEntry?.equipment == GymEquipment.bodyweight, "\(exercise.exerciseName)")
            }
        }
    }

    @Test("Todas las combinaciones generan planes válidos y resolubles")
    func allCombinationsValid() {
        for goal in GymGoal.allCases {
            for experience in GymExperience.allCases {
                for days in [2, 3, 4, 5] {
                    for equipment in GymEquipmentAccess.allCases {
                        let plan = GymPlanGenerator.makePlan(
                            from: prefs(goal: goal, experience: experience, days: days, equipment: equipment)
                        )
                        #expect(!plan.isEmpty)
                        for routine in plan {
                            #expect(routine.folder == GymPlanGenerator.planFolder)
                            #expect(!routine.exercises.isEmpty, "\(routine.name) vacía (\(equipment.rawValue))")
                            // Sin ejercicios repetidos dentro de la rutina
                            let names = routine.exercises.map(\.exerciseName)
                            #expect(names.count == Set(names).count, "duplicados en \(routine.name)")
                            // Todos resolubles en el catálogo
                            for exercise in routine.exercises {
                                #expect(GymExerciseCatalog.exercise(named: exercise.exerciseName) != nil, "\(exercise.exerciseName)")
                            }
                        }
                    }
                }
            }
        }
    }

    @Test("Principiante prioriza máquinas; avanzado prioriza barra")
    func experienceEquipmentPriority() {
        let beginnerPlan = GymPlanGenerator.makePlan(from: prefs(experience: .principiante, days: 3))
        let advancedPlan = GymPlanGenerator.makePlan(from: prefs(experience: .avanzado, days: 3))

        func equipmentCounts(_ plan: [GymRoutine]) -> [GymEquipment: Int] {
            var counts: [GymEquipment: Int] = [:]
            for exercise in plan.flatMap(\.exercises) {
                if let eq = exercise.catalogExercise?.equipment {
                    counts[eq, default: 0] += 1
                }
            }
            return counts
        }

        let beginnerBarbell = equipmentCounts(beginnerPlan)[.barbell] ?? 0
        let advancedBarbell = equipmentCounts(advancedPlan)[.barbell] ?? 0
        #expect(advancedBarbell > beginnerBarbell)
    }
}
