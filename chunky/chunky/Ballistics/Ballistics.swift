// chunky/chunky/Ballistics/Ballistics.swift
import Foundation

/// Pure point-mass trajectory integrator with aerodynamic drag and Magnus lift.
/// No Apple UI/capture frameworks — deterministic and unit-testable.
nonisolated enum Ballistics {

    /// Integrate from launch (origin, height 0) until the ball returns to launch
    /// height. Carry = horizontal distance from origin at that landing point.
    static func integrate(
        launch: LaunchConditions,
        airDensityKgM3 rho: Double,
        ball: BallModel = .standard,
        aero: AeroTable = .standard,
        dt: Double = 0.001,
        gravity g: Double = 9.81
    ) -> Trajectory {
        let theta = Conversions.degToRad(launch.launchAngleDeg)
        let psi = Conversions.degToRad(launch.azimuthDeg)
        let v0 = launch.speedMS

        var position = Vec3.zero
        var velocity = Vec3(
            v0 * cos(theta) * cos(psi),
            v0 * sin(theta),
            v0 * cos(theta) * sin(psi)
        )

        let omega = Conversions.rpmToRadPerSec(launch.spinRPM)   // rad/s
        let tilt = Conversions.degToRad(launch.spinAxisTiltDeg)
        // Pure backspin axis is +z (with velocity +x this yields lift +y);
        // tilt rotates the axis toward +y to introduce sidespin.
        let spinAxis = Vec3(0, sin(tilt), cos(tilt)).normalized

        let radius = ball.diameter / 2
        let area = ball.area
        let mass = ball.mass
        let gravityAcc = Vec3(0, -g, 0)

        func acceleration(_ v: Vec3) -> Vec3 {
            let speed = v.magnitude
            guard speed > 0 else { return gravityAcc }
            let spinRatio = omega * radius / speed
            let (cd, cl) = aero.coefficients(spinRatio: spinRatio)
            let dragForce = (-0.5 * rho * area * cd * speed) * v
            let magnusForce = (0.5 * rho * area * cl * speed) * spinAxis.cross(v)
            return gravityAcc + (1.0 / mass) * (dragForce + magnusForce)
        }

        var t = 0.0
        var apex = 0.0
        var points: [Vec3] = [position]
        let maxTime = 30.0

        while t < maxTime {
            // RK4 over state (position, velocity); acceleration depends only on velocity.
            // k1 position-derivative is the current velocity (acceleration depends only on velocity)
            let a1 = acceleration(velocity)
            let v2 = velocity + (dt / 2) * a1
            let a2 = acceleration(v2)
            let v3 = velocity + (dt / 2) * a2
            let a3 = acceleration(v3)
            let v4 = velocity + dt * a3
            let a4 = acceleration(v4)

            let prev = position
            position = position + (dt / 6) * (velocity + 2.0 * v2 + 2.0 * v3 + v4)
            velocity = velocity + (dt / 6) * (a1 + 2.0 * a2 + 2.0 * a3 + a4)
            t += dt
            apex = max(apex, position.y)
            points.append(position)

            // Landing: ball descends back through launch height.
            if position.y <= 0 && velocity.y < 0 {
                let denom = prev.y - position.y
                let frac = denom != 0 ? prev.y / denom : 0
                let landing = prev + frac * (position - prev)
                let carry = (landing.x * landing.x + landing.z * landing.z).squareRoot()
                return Trajectory(
                    carryMeters: carry,
                    flightTimeS: t - dt + frac * dt,
                    apexMeters: apex,
                    points: points,
                    landed: true
                )
            }
        }

        let carry = (position.x * position.x + position.z * position.z).squareRoot()
        return Trajectory(carryMeters: carry, flightTimeS: t, apexMeters: apex, points: points, landed: false)
    }
}
