import Foundation
import FirebaseFirestore

// MARK: - Body Measurement (medidas corporales)
struct BodyMeasurement: Codable, Identifiable {
    @DocumentID var id: String?
    var date: Date
    var weight: Double?    // kg
    var bodyFat: Double?   // %
    var chest: Double?     // cm
    var waist: Double?     // cm
    var hips: Double?      // cm
    var arm: Double?       // cm
    var thigh: Double?     // cm

    init(date: Date = Date(), weight: Double? = nil, bodyFat: Double? = nil,
         chest: Double? = nil, waist: Double? = nil, hips: Double? = nil,
         arm: Double? = nil, thigh: Double? = nil) {
        self.date = date
        self.weight = weight
        self.bodyFat = bodyFat
        self.chest = chest
        self.waist = waist
        self.hips = hips
        self.arm = arm
        self.thigh = thigh
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _id = try c.decode(DocumentID<String>.self, forKey: .id)
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        weight = try c.decodeIfPresent(Double.self, forKey: .weight)
        bodyFat = try c.decodeIfPresent(Double.self, forKey: .bodyFat)
        chest = try c.decodeIfPresent(Double.self, forKey: .chest)
        waist = try c.decodeIfPresent(Double.self, forKey: .waist)
        hips = try c.decodeIfPresent(Double.self, forKey: .hips)
        arm = try c.decodeIfPresent(Double.self, forKey: .arm)
        thigh = try c.decodeIfPresent(Double.self, forKey: .thigh)
    }

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }

    /// Campos con valor, para listado (label, valor, unidad)
    var filledFields: [(label: String, value: Double, unit: String)] {
        var result: [(String, Double, String)] = []
        if let weight { result.append(("Peso", weight, "kg")) }
        if let bodyFat { result.append(("Grasa", bodyFat, "%")) }
        if let chest { result.append(("Pecho", chest, "cm")) }
        if let waist { result.append(("Cintura", waist, "cm")) }
        if let hips { result.append(("Cadera", hips, "cm")) }
        if let arm { result.append(("Brazo", arm, "cm")) }
        if let thigh { result.append(("Muslo", thigh, "cm")) }
        return result
    }
}
