// chunky/chunky/Calibration/Device/MarkerDetector.swift
//
// Vision-based calibration-marker corner detection.
//
// ## Marker strategy
// Primary:  `VNDetectBarcodesRequest` with `.qr` symbology — the printed
//           calibration target is a QR code of known physical size.  Vision
//           returns perspective-correct quad corners via the inherited
//           `VNRectangleObservation` properties on `VNBarcodeObservation`.
// Fallback: `VNDetectRectanglesRequest` — for a plain rectangular target when
//           no QR code is found.
//
// ## Coordinate convention
// Vision normalises observations to [0,1]² with a **bottom-left** origin.
// This file converts to top-left-origin **pixel** coordinates:
//
//     pixelX = normalised.x × imageWidth
//     pixelY = (1 − normalised.y) × imageHeight
//
// ## Scope note (MVP)
// True ArUco/AprilTag detection would require OpenCV or a third-party library
// (out of scope for MVP).  This file uses Apple Vision's built-in QR-code and
// rectangle detection as the Apple-native calibration-marker path.  It is
// **build-verified only**; on-device end-to-end detection has not been tested.
// The 4 corners produced here feed `CalibrationMath` (Task 6).

import CoreVideo
import Vision

/// Detects the calibration marker in a video frame and returns its 4 corner
/// points in pixel coordinates (top-left origin, y increases downward).
final class MarkerDetector {

    // MARK: - Public API

    /// Runs Vision requests on `pixelBuffer` and returns 4 corner `Vec2`s
    /// (top-left origin, y-down) for the best detected calibration marker,
    /// or `nil` when nothing is found.
    ///
    /// Corners are ordered [topLeft, topRight, bottomRight, bottomLeft].
    /// Pass the result directly to
    /// `CalibrationMath.pixelsPerMeter(markerCornersPx:markerSideMeters:)`.
    ///
    /// ## Concurrency note
    /// `VNImageRequestHandler.perform` is synchronous.  This `async` function
    /// does not internally hop to a background thread because `CVPixelBuffer`
    /// is non-Sendable in iOS 26's Swift overlay (see `CaptureCoordinator` for
    /// the project precedent on avoiding `Task.detached` with pixel buffers).
    /// Callers that cannot afford to block the calling actor should invoke this
    /// method from a detached task with an `@unchecked Sendable` wrapper.
    func detectCorners(in pixelBuffer: CVPixelBuffer) async -> [Vec2]? {
        let w = Double(CVPixelBufferGetWidth(pixelBuffer))
        let h = Double(CVPixelBufferGetHeight(pixelBuffer))

        // One handler per image; `orientation: .up` assumes the buffer is
        // already in display orientation.  Callers that rotate the device
        // should pass the true `CGImagePropertyOrientation` to avoid a skewed
        // bounding box.
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )

        // ── Primary: QR-code detection ─────────────────────────────────────
        let barcodeRequest = VNDetectBarcodesRequest()
        barcodeRequest.symbologies = [.qr]

        if let corners = Self.barcodeCorners(barcodeRequest,
                                             handler: handler, w: w, h: h) {
            return corners
        }

        // ── Fallback: rectangle detection ──────────────────────────────────
        let rectRequest = VNDetectRectanglesRequest()
        rectRequest.maximumObservations = 1
        rectRequest.minimumConfidence   = 0.7
        rectRequest.minimumAspectRatio  = 0.6
        rectRequest.maximumAspectRatio  = 1.4   // near-square calibration targets

        return Self.rectangleCorners(rectRequest, handler: handler, w: w, h: h)
    }

    // MARK: - Private helpers

    /// Performs the QR-code request and returns 4 perspective-correct corners
    /// from the highest-confidence observation.
    ///
    /// `VNBarcodeObservation` inherits from `VNRectangleObservation`, so the
    /// named quad-corner properties (`topLeft`, `topRight`, `bottomRight`,
    /// `bottomLeft`) are available directly on the observation.  These describe
    /// the actual marker quad — not an axis-aligned bounding box — so they
    /// remain accurate for tilted markers.
    ///
    /// Values are in Vision's normalised BL-origin coordinate space; the
    /// standard `(1 − ny) × height` flip converts them to top-left-origin
    /// pixel coordinates, matching the rectangle-path convention.
    ///
    /// Returns `nil` if no observation is found.
    private static func barcodeCorners(
        _ request: VNDetectBarcodesRequest,
        handler: VNImageRequestHandler,
        w: Double, h: Double
    ) -> [Vec2]? {
        do { try handler.perform([request]) } catch { return nil }
        guard let obs = request.results?.first else { return nil }

        let norm: [(Double, Double)] = [
            (Double(obs.topLeft.x),     Double(obs.topLeft.y)),
            (Double(obs.topRight.x),    Double(obs.topRight.y)),
            (Double(obs.bottomRight.x), Double(obs.bottomRight.y)),
            (Double(obs.bottomLeft.x),  Double(obs.bottomLeft.y)),
        ]
        return norm.map { nx, ny in Vec2(nx * w, (1.0 - ny) * h) }
    }

    /// Performs the rectangle request and converts the named quad corners of
    /// the best observation to top-left-origin pixel `Vec2`s.
    ///
    /// `VNRectangleObservation.topLeft` etc. describe display-space positions;
    /// their VALUES are in Vision's normalised BL-origin coordinate space, so
    /// the standard `(1 − ny) * height` flip is applied to all four corners.
    private static func rectangleCorners(
        _ request: VNDetectRectanglesRequest,
        handler: VNImageRequestHandler,
        w: Double, h: Double
    ) -> [Vec2]? {
        do { try handler.perform([request]) } catch { return nil }
        guard let obs = request.results?.first else { return nil }

        let norm: [(Double, Double)] = [
            (Double(obs.topLeft.x),     Double(obs.topLeft.y)),
            (Double(obs.topRight.x),    Double(obs.topRight.y)),
            (Double(obs.bottomRight.x), Double(obs.bottomRight.y)),
            (Double(obs.bottomLeft.x),  Double(obs.bottomLeft.y)),
        ]
        return norm.map { nx, ny in Vec2(nx * w, (1.0 - ny) * h) }
    }
}
