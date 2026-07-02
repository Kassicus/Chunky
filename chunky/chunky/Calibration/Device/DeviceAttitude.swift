// chunky/chunky/Calibration/Device/DeviceAttitude.swift
//
// CoreMotion gravity → image-plane gravity vector for the active landscape
// camera orientation.
//
// ## Device → image-plane axis mapping
//
// CoreMotion reports gravity in the device body frame (fixed to the device,
// independent of display/capture orientation):
//
//   device +x  = to the right when held in portrait (short right side)
//   device +y  = toward the top when held in portrait (long top edge)
//   device +z  = out of the screen toward the user
//
// The image coordinate system used throughout this project is:
//
//   image +x  = to the right of the frame
//   image +y  = downward in the frame  (y-DOWN, top-left origin)
//
// ### Landscape-right (UIDeviceOrientation.landscapeRight)
// Device rotated 90° CCW from portrait; the portrait top is now on the RIGHT
// of the landscape image. The home/lock button is on the right side of the
// landscape image. This is the default capture orientation for this app.
//
//   Portrait +y (device up)    → landscape right → image +x
//   Portrait +x (device right) → landscape down  → image +y
//
//   imagePlaneGravity.x = gravity.y
//   imagePlaneGravity.y = gravity.x
//
// Verification (device upright, landscape-right):
//   Physical down  = portrait-right direction  = device +x
//   ∴ gravity ≈ (+1, 0, 0) in device frame
//   imagePlaneGravity ≈ (0, +1) — gravity points straight down in image ✓
//
// ### Landscape-left (UIDeviceOrientation.landscapeLeft)
// Device rotated 90° CW from portrait; the portrait top is now on the LEFT
// of the landscape image. The home/lock button is on the left side.
//
//   Portrait +y (device up)    → landscape left → image -x
//   Portrait +x (device right) → landscape up   → image -y
//   ∴ image +x = -device_y; image +y = -device_x
//
//   imagePlaneGravity.x = -gravity.y
//   imagePlaneGravity.y = -gravity.x
//
// Verification (device upright, landscape-left):
//   Physical down  = portrait-left direction  = device -x
//   ∴ gravity ≈ (-1, 0, 0) in device frame
//   imagePlaneGravity ≈ (0, +1) — gravity points straight down in image ✓
//
// ## SDK notes
// - `CMMotionManager` has one instance per app; if CaptureKit ever needs its
//   own motion stream, coordinate via a shared manager or use the attitude
//   reference frame directly.
// - `deviceMotionUpdateInterval` is set before each `startDeviceMotionUpdates`
//   call so the interval takes effect even if the manager was already running.
// - Updates are delivered on `OperationQueue.main`; `MainActor.assumeIsolated`
//   bridges from the OperationQueue callback (whose actor-context is opaque to
//   the Swift type system) back to the main actor, following the pattern used
//   in `CaptureCoordinator`.
// - `UIDevice.current.beginGeneratingDeviceOrientationNotifications()` is
//   required for `UIDevice.current.orientation` to return a value other than
//   `.unknown`. Balanced calls prevent conflicts with other app subsystems.

import CoreMotion
import UIKit

/// Streams `CMMotionManager` device-motion updates and exposes the current
/// gravity vector projected into the camera image plane (x→right, y→DOWN)
/// for the active landscape orientation.
///
/// Feed `imagePlaneGravity` into `CalibrationMath.imageUpUnit` to derive the
/// "up" direction in image-pixel space.
///
/// ## Usage
/// ```swift
/// let attitude = DeviceAttitude()
/// attitude.start()
/// // ... later, on the main actor ...
/// if let g = attitude.imagePlaneGravity {
///     let up = CalibrationMath.imageUpUnit(imagePlaneGravity: g)
/// }
/// attitude.stop()
/// ```
///
/// ## Concurrency
/// All properties are mutated on the main actor via `MainActor.assumeIsolated`
/// inside the CoreMotion handler (which is delivered on `OperationQueue.main`).
/// With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` this class is implicitly
/// `@MainActor`-isolated; call `start()` and `stop()` from the main actor and
/// read `imagePlaneGravity`/`gravity` from the main actor only.
///
/// ## Build note
/// CoreMotion device-motion requires a physical device; this class is
/// build-verified only. On-device accuracy depends on sensor quality and the
/// device being level enough that the z-component of gravity is small relative
/// to the in-plane components.
final class DeviceAttitude {

    // MARK: - Public API

    /// Raw device-frame gravity from `CMDeviceMotion.gravity`
    /// (x→portrait-right, y→portrait-up, z→out-of-screen).
    /// `nil` until `start()` receives its first update.
    private(set) var gravity: Vec3?

    /// Gravity projected into the camera image plane (x→right, y→DOWN) for
    /// the current landscape orientation.
    ///
    /// Pass directly to `CalibrationMath.imageUpUnit(imagePlaneGravity:)`.
    /// `nil` until `start()` receives its first update.
    private(set) var imagePlaneGravity: Vec2?

    /// CoreMotion update rate in seconds per sample. Default: 1/60 s (60 Hz).
    /// Must be set before calling `start()`; ignored if motion updates are
    /// already running.
    var updateInterval: TimeInterval = 1.0 / 60.0

    // MARK: - Private state

    private let motionManager = CMMotionManager()

    // MARK: - Lifecycle

    /// Starts the device-motion stream.
    ///
    /// Safe to call when already running — existing updates are stopped first
    /// so the new `updateInterval` takes effect. Does nothing if
    /// `CMMotionManager.isDeviceMotionAvailable` returns `false` (simulator).
    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        // Enable UIDevice orientation so projectToImagePlane can distinguish
        // landscape-right from landscape-left.
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        // Stop any existing stream before applying the new interval.
        motionManager.stopDeviceMotionUpdates()
        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            // Bridge OperationQueue.main → main actor (they run on the same
            // thread but are distinct in Swift's concurrency type system).
            MainActor.assumeIsolated {
                guard let self, let motion else { return }
                let raw = motion.gravity
                let gVec = Vec3(raw.x, raw.y, raw.z)
                self.gravity = gVec
                self.imagePlaneGravity = Self.projectToImagePlane(gVec)
            }
        }
    }

    /// Stops the device-motion stream and clears the cached vectors.
    func stop() {
        motionManager.stopDeviceMotionUpdates()
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        gravity = nil
        imagePlaneGravity = nil
    }

    // MARK: - Axis mapping

    /// Projects the device-frame gravity vector onto the image plane for the
    /// current landscape orientation (see file header for derivation).
    ///
    /// Falls back to landscape-right when the orientation is ambiguous
    /// (portrait, face-up/down, or `.unknown` before orientation notifications
    /// have delivered their first update).
    private static func projectToImagePlane(_ g: Vec3) -> Vec2 {
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            // CW 90° from portrait: image +x = -device_y, image +y = -device_x
            return Vec2(-g.y, -g.x)
        default:
            // Landscape-right (CCW 90° from portrait) — the rear-camera
            // default for this app: image +x = +device_y, image +y = +device_x
            return Vec2(g.y, g.x)
        }
    }
}
