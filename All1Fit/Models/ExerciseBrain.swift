import Foundation

final class ExerciseBrain {
    static func detectTargetMuscles(from text: String) -> (primary: BodyPart, secondary: [BodyPart])
    {
        let lowercased = text.lowercased()

        // 1. LEGS (Priority Check due to "Press" overlap)
        if containsAny(
            lowercased,
            [
                "squat", "sentadilla", "zancada", "lunge", "prensa", "leg press", "jaca", "hack",
                "step up", "bulgarian",
            ])
        {
            if containsAny(
                lowercased, ["front", "frontal", "hack", "jaca", "cajon", "step", "bulgara"])
            {
                return (.quads, [.glutes, .abs])
            }
            return (.quads, [.glutes, .hamstrings])
        }

        if containsAny(lowercased, ["extension"])
            && containsAny(lowercased, ["leg", "pierna", "quad", "cuadriceps"])
        {
            return (.quads, [])
        }

        if containsAny(
            lowercased,
            [
                "deadlift", "muerto", "peso muerto", "good morning", "buenos dias", "glute",
                "gluteo", "hip", "cadera", "femoral", "curl leg", "curl de pierna", "nordic",
            ])
        {
            if containsAny(lowercased, ["romanian", "rumano", "stiff", "rigida"]) {
                return (.hamstrings, [.glutes, .back])
            }
            if containsAny(lowercased, ["hip", "glute", "puente", "bridge", "thrust"]) {
                return (.glutes, [.hamstrings])
            }
            return (.back, [.hamstrings, .glutes])  // Default conventional deadlift
        }

        // Calves specific
        if containsAny(
            lowercased, ["calf", "gemelo", "pantorrilla", "soleo", "elevacion de talones"])
        {
            return (.calves, [])
        }

        // 2. BACK (antes que pecho: "jalón al pecho" es espalda aunque contenga "pecho")
        if containsAny(
            lowercased, ["row", "remo", "pull", "chin", "dorsal", "dominada", "jalon", "jalón", "pulldown"])
        {
            if containsAny(lowercased, ["face"]) { return (.shoulders, [.back]) }  // Face pull
            return (.back, [.biceps])
        }

        // 3. CHEST
        if containsAny(
            lowercased,
            [
                "bench", "banca", "chest", "pecho", "push up", "flexion", "fondos en paralelas",
                "dips chest",
            ])
        {
            if containsAny(lowercased, ["incline", "inclinado"]) {
                return (.chest, [.shoulders, .triceps])
            }
            return (.chest, [.triceps, .shoulders])
        }
        // Generic "Press" check (after Legs check)
        if containsAny(lowercased, ["press"])
            && !containsAny(lowercased, ["militar", "hombro", "shoulder", "overhead"])
        {
            // If it's just "Press" or "Press de banca" it's chest. "Prensa" is handled above.
            return (.chest, [.triceps, .shoulders])
        }

        // 4. SHOULDERS
        if containsAny(
            lowercased,
            [
                "shoulder", "hombro", "militar", "overhead", "lateral", "arnold", "front raise",
                "pajaros", "face pull", "press militar",
            ])
        {
            if containsAny(lowercased, ["press", "militar", "overhead"]) {
                return (.shoulders, [.triceps])
            }
            return (.shoulders, [])
        }

        // 5. ARMS
        if containsAny(lowercased, ["curl", "bicep", "bícep", "martillo", "predicador"]) {
            return (.biceps, [.gettingPumped])
        }

        if containsAny(
            lowercased, ["tricep", "trícep", "copa", "frances", "skull", "rompecraneos"])
        {
            return (.triceps, [.shoulders])
        }
        // Dips/Fondos check (if not chest focused)
        if containsAny(lowercased, ["dips", "fondos", "dippings"]) { return (.triceps, [.chest]) }

        if containsAny(lowercased, ["extension"])
            && containsAny(lowercased, ["tricep", "cuerda", "polea"])
        {
            return (.triceps, [])
        }

        // 6. ABS
        if containsAny(
            lowercased,
            ["ab", "core", "plank", "plancha", "crunch", "sit up", "abdominal", "rueda", "wheel"])
        {
            return (.abs, [])
        }

        // 7. OLYMPIC
        if containsAny(lowercased, ["snatch", "clean", "jerk", "arrancada", "cargada", "envion"]) {
            return (.quads, [.shoulders, .back, .triceps])
        }

        return (.none, [])
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}

extension BodyPart {
    // Hidden "Easter egg" muscle just for logic internal usage if needed
    fileprivate static var gettingPumped: BodyPart { .none }
}
