// chunky/chunky/Features/Live/LiveSessionController.swift
import AVFoundation
import CoreVideo
import Foundation
import Observation

/// Drives the Live screen: owns the capture coordinator, current calibration and
/// club, runs the vision→metrics pipeline on each impact, and auto-saves the
/// resulting shot to the selected club (spec §10 — no manual save step).
@MainActor
@Observable
final class LiveSessionController {

    // MARK: - Injected

    private var store: ShotStore?
    private var settings: AppSettings?

    // MARK: - Capture

    private let coordinator: CaptureCoordinator
    private let pipeline = ShotPipeline()
    private let vision = VisionPipeline()

    // MARK: - State

    private(set) var status: CaptureStatus = .idle
    private(set) var latestResult: ShotResult?
    private(set) var latestShot: Shot?
    private(set) var latestTrackJSON: String?
    var selectedClub: Club?
    var activeCalibration: CalibrationScale?
    var currentSession: Session?
    /// Tee-box region for motion confirmation, in image-pixel coords (y-down).
    var teeBoxROI: (x: Int, y: Int, w: Int, h: Int)?
    var motionActivityThreshold: Double = 0.02

    // MARK: - Init

    init(coordinator: CaptureCoordinator = CaptureCoordinator()) {
        self.coordinator = coordinator
    }

    // MARK: - Injection

    func attach(store: ShotStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
    }

    // MARK: - Passthrough

    var previewSession: AVCaptureSession { coordinator.previewSession }
    var currentLens: CaptureConfiguration.Lens { coordinator.currentLens }

    // MARK: - Gate

    /// A club and a calibration are both required before capture can be armed.
    var canArm: Bool { selectedClub != nil && activeCalibration != nil }

    /// Pure: whether a produced result should auto-save (guards against a nil club).
    static func shouldAutoSave(result: ShotResult?, club: Club?) -> Bool {
        result != nil && club != nil
    }

    // MARK: - Frame access (Task 9 / CalibrateView)

    func latestFrame() -> CVPixelBuffer? {
        coordinator.recentFrames().last?.value
    }

    // MARK: - Arm / Disarm

    func arm() async {
        guard canArm else { return }

        coordinator.onImpactCapture = { [weak self] capture in
            self?.handleCapture(capture)
        }

        // Wire motion confirmation from the tee-box ROI, if set.
        // Capture `self` weakly; read `self?.coordinator` inside the closure to
        // avoid a retain cycle between coordinator and its own departureProvider.
        if let roi = teeBoxROI {
            let threshold = motionActivityThreshold
            coordinator.departureProvider = vision.makeDepartureProvider(
                recentFrames: { [weak self] in self?.coordinator.recentFrames() ?? [] },
                roi: roi,
                activityThreshold: threshold
            )
        } else {
            coordinator.departureProvider = nil   // audio-only
        }

        do {
            try await coordinator.arm()
        } catch {
            status = .failed("\(error)")
            return
        }
        status = coordinator.status
    }

    func disarm() {
        coordinator.disarm()
        status = .idle
    }

    // MARK: - Lens toggle

    func toggleLens() async {
        let next: CaptureConfiguration.Lens = coordinator.currentLens == .telephoto ? .wide : .telephoto
        try? await coordinator.setLens(next)
        settings?.lens = next == .telephoto ? .telephoto : .wide
    }

    // MARK: - Impact handler

    /// Runs vision→metrics on the captured window and auto-saves the shot.
    func handleCapture(_ capture: ImpactCapture) {
        guard let calibration = activeCalibration,
              let club = selectedClub,
              let settings else { return }
        guard let out = pipeline.output(
            from: capture,
            calibration: calibration,
            atmosphere: settings.atmosphere,
            modeledSpinRPM: club.modeledSpinRPM
        ) else { return }

        latestResult = out.result
        latestTrackJSON = out.rawTrackJSON

        guard Self.shouldAutoSave(result: out.result, club: club), let store else { return }
        latestShot = try? store.saveShot(
            out.result,
            to: club,
            session: currentSession,
            rawTrackJSON: out.rawTrackJSON
        )
    }
}
