// chunky/chunky/Features/Live/DebugOverlayView.swift
import SwiftUI

// MARK: - Debug Overlay View

/// DEV/diagnostic surface: plots the tracked ball path and displays computed
/// shot metrics. Intended for field-tuning — not shown in production UI.
struct DebugOverlayView: View {
    let track: [TrackPoint]
    let result: ShotResult
    let calibration: CalibrationScale

    var body: some View {
        VStack(spacing: 0) {
            eyebrowHeader
            trackCanvas
                .frame(maxWidth: .infinity)
                .aspectRatio(4 / 3, contentMode: .fit)
                .background(Theme.rangeDusk)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
            metricsPanel
                .padding([.horizontal, .bottom], 16)
                .padding(.top, 12)
        }
        .background(Theme.rangeDusk)
    }

    // MARK: - Eyebrow

    private var eyebrowHeader: some View {
        Text("DEBUG — TRACK & METRICS")
            .font(Theme.eyebrow)
            .kerning(1.5)
            .foregroundStyle(Theme.mist)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    // MARK: - Track canvas

    private var trackCanvas: some View {
        Canvas { ctx, size in
            drawTrack(ctx: ctx, size: size)
        }
    }

    private func drawTrack(ctx: GraphicsContext, size: CGSize) {
        // Nothing to draw for empty track
        guard !track.isEmpty else { return }

        let pad: CGFloat = 16
        let drawRect = CGRect(
            x: pad, y: pad,
            width: max(1, size.width - 2 * pad),
            height: max(1, size.height - 2 * pad)
        )

        // Bounding box of pixel positions
        let xs = track.map(\.pixel.x)
        let ys = track.map(\.pixel.y)
        let minX = xs.min()!
        let maxX = xs.max()!
        let minY = ys.min()!
        let maxY = ys.max()!
        let spanX = maxX - minX
        let spanY = maxY - minY

        // Uniform-aspect scale; guard zero-extent on each axis
        let scaleX: Double = spanX > 0 ? Double(drawRect.width) / spanX : 0
        let scaleY: Double = spanY > 0 ? Double(drawRect.height) / spanY : 0
        let scale: Double
        if spanX == 0 && spanY == 0 {
            scale = 1.0          // single-location cluster — just center
        } else if spanX == 0 {
            scale = scaleY
        } else if spanY == 0 {
            scale = scaleX
        } else {
            scale = min(scaleX, scaleY)
        }

        // Center the scaled track within drawRect
        let usedW = spanX * scale
        let usedH = spanY * scale
        let offsetX = (Double(drawRect.width) - usedW) / 2
        let offsetY = (Double(drawRect.height) - usedH) / 2

        // Map a pixel-space Vec2 → canvas CGPoint.
        // Pixel space is y-DOWN; we preserve that so the plot matches the image.
        func map(_ p: Vec2) -> CGPoint {
            CGPoint(
                x: drawRect.minX + CGFloat((p.x - minX) * scale + offsetX),
                y: drawRect.minY + CGFloat((p.y - minY) * scale + offsetY)
            )
        }

        // Polyline connecting all centroids
        if track.count > 1 {
            var line = Path()
            line.move(to: map(track[0].pixel))
            for pt in track.dropFirst() {
                line.addLine(to: map(pt.pixel))
            }
            ctx.stroke(line, with: .color(Theme.mist), lineWidth: 1.5)
        }

        // Centroid dots; radius optionally proportional to radiusPx
        for pt in track {
            let dotR = CGFloat(max(3.0, pt.radiusPx * scale))
            let dotRect = CGRect(
                x: CGFloat(map(pt.pixel).x) - dotR,
                y: CGFloat(map(pt.pixel).y) - dotR,
                width: dotR * 2, height: dotR * 2
            )
            ctx.fill(Path(ellipseIn: dotRect), with: .color(Theme.optic))
        }

        // Velocity vector: first → last of the usedFrameCount points (amber arrow)
        let used = min(max(result.usedFrameCount, 0), track.count)
        if used >= 2 {
            let origin = map(track[0].pixel)
            let tip    = map(track[used - 1].pixel)

            var shaft = Path()
            shaft.move(to: origin)
            shaft.addLine(to: tip)
            ctx.stroke(shaft, with: .color(Theme.amber), lineWidth: 2)

            // Arrowhead using the shaft direction (no trig needed)
            let dx = tip.x - origin.x
            let dy = tip.y - origin.y
            let len = (dx * dx + dy * dy).squareRoot()
            if len > 4 {
                let ux = dx / len
                let uy = dy / len
                // perpendicular unit vector (90° CCW)
                let px = -uy
                let py =  ux
                let arrowLen: CGFloat = 10
                let base = CGPoint(
                    x: tip.x - ux * arrowLen,
                    y: tip.y - uy * arrowLen
                )
                let wing: CGFloat = 5
                let p1 = CGPoint(x: base.x + px * wing, y: base.y + py * wing)
                let p2 = CGPoint(x: base.x - px * wing, y: base.y - py * wing)
                var head = Path()
                head.move(to: tip); head.addLine(to: p1)
                head.move(to: tip); head.addLine(to: p2)
                ctx.stroke(head, with: .color(Theme.amber), lineWidth: 2)
            }
        }
    }

    // MARK: - Metrics panel

    private var metricsPanel: some View {
        VStack(spacing: 0) {
            metricRow(label: "v0",       value: String(format: "%.1f mph", result.ballSpeedMPH))
            divider
            metricRow(label: "launch",   value: String(format: "%.1f°",   result.launchAngleDeg))
            divider
            metricRow(label: "carry",    value: String(format: "%.0f yd", result.carryYards))
            divider
            metricRow(label: "scale",    value: String(format: "%.0f px/m", calibration.pixelsPerMeter))
            divider
            metricRow(label: "frames",   value: "\(result.usedFrameCount)/\(track.count)")
            divider
            metricRow(label: "RMS",      value: String(format: "%.3f m",  result.fitRmsResidualMeters))
            divider
            confidenceRow
        }
        .padding(12)
        .background(Theme.turf)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.turfLine)
            .frame(height: 1)
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.eyebrow)
                .foregroundStyle(Theme.mist)
            Spacer()
            Text(value)
                .font(Theme.number(14))
                .foregroundStyle(Theme.chalk)
        }
        .padding(.vertical, 8)
    }

    private var confidenceRow: some View {
        HStack {
            Text("confidence")
                .font(Theme.eyebrow)
                .foregroundStyle(Theme.mist)
            Spacer()
            Text(result.confidence.rawValue.uppercased())
                .font(Theme.eyebrow)
                .foregroundStyle(Theme.confidenceColor(result.confidence))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.confidenceColor(result.confidence).opacity(0.18))
                .clipShape(Capsule())
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    // Synthetic track: 7 points along a diagonal (pixel y-down)
    let track: [TrackPoint] = [
        TrackPoint(timeSeconds: 0.000, pixel: Vec2(60, 150), radiusPx: 6, confidence: 0.90),
        TrackPoint(timeSeconds: 0.016, pixel: Vec2(88, 128), radiusPx: 6, confidence: 0.91),
        TrackPoint(timeSeconds: 0.033, pixel: Vec2(116, 106), radiusPx: 6, confidence: 0.92),
        TrackPoint(timeSeconds: 0.050, pixel: Vec2(144,  84), radiusPx: 6, confidence: 0.93),
        TrackPoint(timeSeconds: 0.066, pixel: Vec2(172,  62), radiusPx: 6, confidence: 0.90),
        TrackPoint(timeSeconds: 0.083, pixel: Vec2(200,  40), radiusPx: 6, confidence: 0.88),
        TrackPoint(timeSeconds: 0.100, pixel: Vec2(228,  18), radiusPx: 6, confidence: 0.85),
    ]

    let result = ShotResult(
        ballSpeedMS: 66,
        launchAngleDeg: 14.5,
        azimuthDeg: 0,
        spinRPM: 6500,
        spinSource: .modeled,
        spinAxisTiltDeg: 0,
        carryMeters: 150,
        confidence: .high,
        fitRmsResidualMeters: 0.012,
        usedFrameCount: 6
    )

    let calibration = CalibrationScale(
        pixelsPerMeter: 500,
        imageUpUnit: Vec2(0, -1)
    )

    ZStack {
        Theme.rangeDusk.ignoresSafeArea()
        ScrollView {
            DebugOverlayView(track: track, result: result, calibration: calibration)
                .padding()
        }
    }
}
