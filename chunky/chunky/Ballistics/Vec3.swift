// chunky/chunky/Ballistics/Vec3.swift
// Pure 3D vector for ballistics math. No Apple frameworks.
// World frame: +x downrange (toward target), +y up, +z to the right.

nonisolated struct Vec3: Equatable {
    var x: Double
    var y: Double
    var z: Double

    init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    static let zero = Vec3(0, 0, 0)

    static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x + b.x, a.y + b.y, a.z + b.z) }
    static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x - b.x, a.y - b.y, a.z - b.z) }
    static func * (s: Double, v: Vec3) -> Vec3 { Vec3(s * v.x, s * v.y, s * v.z) }
    static func * (v: Vec3, s: Double) -> Vec3 { s * v }

    var magnitude: Double { (x * x + y * y + z * z).squareRoot() }

    func dot(_ o: Vec3) -> Double { x * o.x + y * o.y + z * o.z }

    func cross(_ o: Vec3) -> Vec3 {
        Vec3(
            y * o.z - z * o.y,
            z * o.x - x * o.z,
            x * o.y - y * o.x
        )
    }

    /// Unit vector; a zero-length vector normalizes to zero.
    var normalized: Vec3 {
        let m = magnitude
        return m > 0 ? (1.0 / m) * self : .zero
    }
}
