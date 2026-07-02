// chunky/chunky/Metrics/Vec2.swift
// Pure 2D vector for image-plane (pixel) math in Metrics. No Apple frameworks.

nonisolated struct Vec2: Equatable {
    let x: Double
    let y: Double

    init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    static let zero = Vec2(0, 0)

    static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
    static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }
    static func * (s: Double, v: Vec2) -> Vec2 { Vec2(s * v.x, s * v.y) }
    static func * (v: Vec2, s: Double) -> Vec2 { s * v }

    var magnitude: Double { (x * x + y * y).squareRoot() }

    func dot(_ o: Vec2) -> Double { x * o.x + y * o.y }

    var normalized: Vec2 {
        let m = magnitude
        return m > 0 ? (1.0 / m) * self : .zero
    }

    /// 90° rotation (x, y) -> (y, -x). Used to derive the horizontal image axis
    /// from the calibrated "up" direction (they are orthogonal).
    var perpendicular: Vec2 { Vec2(y, -x) }
}

extension Vec2: Codable {}
