// chunky/chunky/Features/Live/TeeBoxOverlay.swift
import SwiftUI

struct TeeBoxOverlay: View {
    @Binding var roi: CGRect

    @State private var moveDragStart: CGRect? = nil
    @State private var resizeDragStart: CGRect? = nil

    private let handleSize: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            overlayContent(in: geo.size)
        }
    }

    // MARK: - Content

    private func overlayContent(in size: CGSize) -> some View {
        let rect = scaledRect(size: size)
        return ZStack(alignment: .topLeading) {
            // Full-size anchor so ZStack fills the GeometryReader
            Color.clear
                .frame(width: size.width, height: size.height)

            // Body drag target (move)
            Color.clear
                .frame(width: rect.width, height: rect.height)
                .contentShape(Rectangle())
                .offset(x: rect.minX, y: rect.minY)
                .gesture(moveDragGesture(size: size))

            // Dashed ROI border (visual only)
            Rectangle()
                .stroke(
                    Theme.optic,
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .allowsHitTesting(false)

            // "TEE BOX" eyebrow label above top-left corner
            Text("TEE BOX")
                .font(Theme.eyebrow)
                .kerning(1.5)
                .foregroundStyle(Theme.optic)
                .offset(x: rect.minX + 8, y: max(0, rect.minY - 22))
                .allowsHitTesting(false)

            // Bottom-right corner resize handle
            Circle()
                .fill(Theme.optic)
                .frame(width: handleSize, height: handleSize)
                .offset(
                    x: rect.maxX - handleSize / 2,
                    y: rect.maxY - handleSize / 2
                )
                .gesture(resizeDragGesture(size: size))
        }
    }

    // MARK: - Helpers

    private func scaledRect(size: CGSize) -> CGRect {
        CGRect(
            x: roi.minX * size.width,
            y: roi.minY * size.height,
            width: roi.width * size.width,
            height: roi.height * size.height
        )
    }

    // MARK: - Gestures

    private func moveDragGesture(size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard size.width > 0, size.height > 0 else { return }
                if moveDragStart == nil { moveDragStart = roi }
                guard let start = moveDragStart else { return }
                let dx = value.translation.width / size.width
                let dy = value.translation.height / size.height
                let newX = max(0, min(1 - start.width, start.minX + dx))
                let newY = max(0, min(1 - start.height, start.minY + dy))
                roi = CGRect(x: newX, y: newY, width: start.width, height: start.height)
            }
            .onEnded { _ in
                moveDragStart = nil
            }
    }

    private func resizeDragGesture(size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard size.width > 0, size.height > 0 else { return }
                if resizeDragStart == nil { resizeDragStart = roi }
                guard let start = resizeDragStart else { return }
                let dw = value.translation.width / size.width
                let dh = value.translation.height / size.height
                let minSize: CGFloat = 0.05
                let newW = max(minSize, min(1 - start.minX, start.width + dw))
                let newH = max(minSize, min(1 - start.minY, start.height + dh))
                roi = CGRect(x: start.minX, y: start.minY, width: newW, height: newH)
            }
            .onEnded { _ in
                resizeDragStart = nil
            }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var roi = CGRect(x: 0.3, y: 0.4, width: 0.4, height: 0.25)
    Rectangle()
        .fill(Color.black.opacity(0.85))
        .overlay {
            TeeBoxOverlay(roi: $roi)
        }
}
