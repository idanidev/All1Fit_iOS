import SwiftUI

// MARK: - SVG Path Data Parser
/// Convierte una cadena de datos de trazado SVG ("d" attribute) en un `Path` de SwiftUI.
/// Soporta los comandos usados por los datos de anatomía vectorial de MuscleBodyData:
/// M/m, L/l, C/c, Q/q, A/a, Z/z (absolutos y relativos), incluyendo el formato
/// compacto de SVG (números pegados, flags de arco de un solo carácter).
enum SVGPathParser {

    static func path(from d: String) -> Path {
        var path = Path()
        var scanner = Scanner(d)

        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var command: Character?

        while true {
            if let c = scanner.nextCommand() {
                command = c
            }
            guard let cmd = command, scanner.hasMore else { break }

            switch cmd {
            case "M", "m":
                guard let dx = scanner.nextNumber(), let dy = scanner.nextNumber() else { return path }
                current = cmd == "m" ? CGPoint(x: current.x + dx, y: current.y + dy) : CGPoint(x: dx, y: dy)
                subpathStart = current
                path.move(to: current)
                // Pares adicionales tras un M se tratan como L implícitos (regla SVG)
                command = cmd == "m" ? "l" : "L"

            case "L", "l":
                guard let dx = scanner.nextNumber(), let dy = scanner.nextNumber() else { return path }
                current = cmd == "l" ? CGPoint(x: current.x + dx, y: current.y + dy) : CGPoint(x: dx, y: dy)
                path.addLine(to: current)

            case "C", "c":
                guard let x1 = scanner.nextNumber(), let y1 = scanner.nextNumber(),
                      let x2 = scanner.nextNumber(), let y2 = scanner.nextNumber(),
                      let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return path }
                let isRelative = cmd == "c"
                let c1 = isRelative ? CGPoint(x: current.x + x1, y: current.y + y1) : CGPoint(x: x1, y: y1)
                let c2 = isRelative ? CGPoint(x: current.x + x2, y: current.y + y2) : CGPoint(x: x2, y: y2)
                let end = isRelative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                path.addCurve(to: end, control1: c1, control2: c2)
                current = end

            case "Q", "q":
                guard let x1 = scanner.nextNumber(), let y1 = scanner.nextNumber(),
                      let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return path }
                let isRelative = cmd == "q"
                let c1 = isRelative ? CGPoint(x: current.x + x1, y: current.y + y1) : CGPoint(x: x1, y: y1)
                let end = isRelative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                path.addQuadCurve(to: end, control: c1)
                current = end

            case "A", "a":
                guard let rx = scanner.nextNumber(), let ry = scanner.nextNumber(),
                      let rotation = scanner.nextNumber(),
                      let largeArc = scanner.nextFlag(), let sweep = scanner.nextFlag(),
                      let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return path }
                let isRelative = cmd == "a"
                let end = isRelative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                appendArc(to: &path, from: current, to: end, rx: rx, ry: ry,
                          rotationDegrees: rotation, largeArc: largeArc, sweep: sweep)
                current = end

            case "Z", "z":
                path.closeSubpath()
                current = subpathStart

            default:
                return path
            }
        }
        return path
    }

    // MARK: - Arco elíptico → curvas Bézier cúbicas (algoritmo estándar SVG, apéndice F.6)

    private static func appendArc(to path: inout Path, from p1: CGPoint, to p2: CGPoint,
                                   rx rxIn: Double, ry ryIn: Double, rotationDegrees: Double,
                                   largeArc: Bool, sweep: Bool) {
        if p1 == p2 { return }
        if rxIn == 0 || ryIn == 0 {
            path.addLine(to: p2)
            return
        }

        let phi = rotationDegrees * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        var rx = abs(rxIn), ry = abs(ryIn)

        let dx2 = (p1.x - p2.x) / 2, dy2 = (p1.y - p2.y) / 2
        let x1p = cosPhi * dx2 + sinPhi * dy2
        let y1p = -sinPhi * dx2 + cosPhi * dy2

        // Corrige radios demasiado pequeños para el arco solicitado
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            let scale = sqrt(lambda)
            rx *= scale; ry *= scale
        }

        let sign: Double = (largeArc != sweep) ? 1 : -1
        let num = max(0, rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p)
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        let coef = den == 0 ? 0 : sign * sqrt(num / den)
        let cxp = coef * (rx * y1p / ry)
        let cyp = coef * -(ry * x1p / rx)

        let cx = cosPhi * cxp - sinPhi * cyp + (p1.x + p2.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p1.y + p2.y) / 2

        func angle(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            let dot = ux * vx + uy * vy
            let len = sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
            var a = len == 0 ? 0 : acos(max(-1, min(1, dot / len)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }

        let theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var deltaTheta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep && deltaTheta > 0 { deltaTheta -= 2 * .pi }
        if sweep && deltaTheta < 0 { deltaTheta += 2 * .pi }

        // Divide en segmentos de máximo 90º para una aproximación Bézier fiel
        let segments = max(1, Int(ceil(abs(deltaTheta) / (.pi / 2))))
        let delta = deltaTheta / Double(segments)
        let k = 4.0 / 3.0 * tan(delta / 4)

        var theta = theta1
        for _ in 0..<segments {
            let thetaEnd = theta + delta
            let cosT = cos(theta), sinT = sin(theta)
            let cosTE = cos(thetaEnd), sinTE = sin(thetaEnd)

            let p1x = cx + rx * cosT * cosPhi - ry * sinT * sinPhi
            let p1y = cy + rx * cosT * sinPhi + ry * sinT * cosPhi
            let p2x = cx + rx * cosTE * cosPhi - ry * sinTE * sinPhi
            let p2y = cy + rx * cosTE * sinPhi + ry * sinTE * cosPhi

            let dx1 = -rx * sinT, dy1 = ry * cosT
            let dx2 = -rx * sinTE, dy2 = ry * cosTE

            let c1x = p1x + k * (dx1 * cosPhi - dy1 * sinPhi)
            let c1y = p1y + k * (dx1 * sinPhi + dy1 * cosPhi)
            let c2x = p2x - k * (dx2 * cosPhi - dy2 * sinPhi)
            let c2y = p2y - k * (dx2 * sinPhi + dy2 * cosPhi)

            path.addCurve(to: CGPoint(x: p2x, y: p2y),
                          control1: CGPoint(x: c1x, y: c1y),
                          control2: CGPoint(x: c2x, y: c2y))
            theta = thetaEnd
        }
    }

    // MARK: - Escáner de tokens

    private struct Scanner {
        let chars: [Character]
        var index = 0

        init(_ s: String) { chars = Array(s) }

        var hasMore: Bool { index < chars.count }

        private mutating func skipSeparators() {
            while index < chars.count, chars[index] == " " || chars[index] == "," || chars[index] == "\n" || chars[index] == "\t" {
                index += 1
            }
        }

        /// Lee la siguiente letra de comando si el próximo token no numérico es una letra
        mutating func nextCommand() -> Character? {
            skipSeparators()
            guard index < chars.count, chars[index].isLetter else { return nil }
            let c = chars[index]
            index += 1
            return c
        }

        /// Lee un número SVG (soporta signo, decimales y notación pegada tipo "3.06.15")
        mutating func nextNumber() -> Double? {
            skipSeparators()
            guard index < chars.count else { return nil }
            var s = ""
            if chars[index] == "-" || chars[index] == "+" {
                s.append(chars[index]); index += 1
            }
            var sawDot = false
            while index < chars.count {
                let c = chars[index]
                if c.isNumber {
                    s.append(c); index += 1
                } else if c == "." && !sawDot {
                    sawDot = true; s.append(c); index += 1
                } else if (c == "e" || c == "E"), index + 1 < chars.count,
                          chars[index + 1].isNumber || chars[index + 1] == "-" || chars[index + 1] == "+" {
                    s.append(c); index += 1
                    s.append(chars[index]); index += 1
                } else {
                    break
                }
            }
            return s.isEmpty || s == "-" || s == "+" ? nil : Double(s)
        }

        /// Lee un flag de arco: exactamente un carácter '0' o '1'
        mutating func nextFlag() -> Bool? {
            skipSeparators()
            guard index < chars.count, chars[index] == "0" || chars[index] == "1" else { return nil }
            let value = chars[index] == "1"
            index += 1
            return value
        }
    }
}
