import Foundation

extension Tabata {
    static var sampleIntervals: Tabata {
        Tabata(
            id: "sample-intervals",
            name: "Sample HIIT",
            type: .intervals,
            workSeconds: 20,
            restSeconds: 10,
            rounds: 8,
            sets: 1,
            setRestSeconds: 0
        )
    }
    
    static var sampleTreadmill: Tabata {
         Tabata(
            id: "sample-treadmill",
            name: "Sample Treadmill",
            type: .treadmill,
            workSeconds: 0,
            restSeconds: 0,
            rounds: 0,
            sets: 0,
            setRestSeconds: 0,
            treadmillPhases: [
                TreadmillPhase(name: "Warmup", durationMinutes: 5, inclinePercent: 0, speedKmh: 4, description: "Warmup")
            ]
        )
    }
}
