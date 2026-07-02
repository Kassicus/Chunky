// chunky/chunky/CaptureKit/Device/ImpactClipWriter.swift
import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

/// Encodes a pre-captured frame window to a `.mov` file using AVAssetWriter.
///
/// Build-verified only — on-device clip quality is validated in Task 12.
final class ImpactClipWriter: Sendable {

    // MARK: - Errors

    enum ClipWriterError: Error, Sendable {
        case emptyFrames
        case writerSetupFailed(String)
        case writerFinishFailed(String)
    }

    // MARK: - Write

    /// Encodes `frames` to a `.mov` file at `url`.
    ///
    /// Presentation times are derived from each frame's `timeSeconds` relative
    /// to the first frame, so the clip always starts at PTS zero regardless of
    /// the wall-clock origin of the captured buffer ring.
    ///
    /// Waits on `input.isReadyForMoreMediaData` before each append via
    /// `Task.yield()` — in batch mode (`expectsMediaDataInRealTime = false`)
    /// this guard is almost always a no-op, but the contract requires it.
    ///
    /// - Parameters:
    ///   - frames: Time-ordered pixel buffers. Must be non-empty.
    ///   - fps: Nominal capture frame rate (informational; actual PTS drives encoding).
    ///   - url: Destination file URL. Any pre-existing file is replaced.
    nonisolated func write(
        frames: [Timestamped<CVPixelBuffer>],
        fps: Double,
        to url: URL
    ) async throws {
        guard let first = frames.first else {
            throw ClipWriterError.emptyFrames
        }

        let firstTime = first.timeSeconds
        let width  = CVPixelBufferGetWidth(first.value)
        let height = CVPixelBufferGetHeight(first.value)

        // Replace any pre-existing file — AVAssetWriter refuses to overwrite.
        try? FileManager.default.removeItem(at: url)

        // ── Writer ────────────────────────────────────────────────────────────
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        } catch {
            throw ClipWriterError.writerSetupFailed(error.localizedDescription)
        }

        // ── Input (H.264, dimensions taken from the first pixel buffer) ───────
        let videoSettings: [String: Any] = [
            AVVideoCodecKey:  AVVideoCodecType.h264,
            AVVideoWidthKey:  width,
            AVVideoHeightKey: height,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false   // batch write; no live throttle

        // ── Pixel-buffer adaptor ───────────────────────────────────────────────
        // Match the 420f biplanar format used by CameraCaptureController so the
        // encoder receives native YCbCr data without an intermediate conversion.
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )

        guard writer.canAdd(input) else {
            throw ClipWriterError.writerSetupFailed("Cannot add video input to writer")
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw ClipWriterError.writerSetupFailed(writer.error?.localizedDescription ?? "startWriting() returned false")
        }
        writer.startSession(atSourceTime: .zero)

        // ── Append frames ──────────────────────────────────────────────────────
        // PTS is the offset from the first captured frame (not wall-clock zero)
        // on a 600 Hz timescale (evenly divisible by 30, 60, 120, 240 fps).
        for frame in frames {
            let pts = CMTime(
                seconds: frame.timeSeconds - firstTime,
                preferredTimescale: 600
            )

            // Yield to the cooperative thread pool until the encoder drains.
            while !input.isReadyForMoreMediaData {
                await Task.yield()
            }

            adaptor.append(frame.value, withPresentationTime: pts)
        }

        input.markAsFinished()

        // ── Finish ────────────────────────────────────────────────────────────
        // `finishWriting()` is the async Swift concurrency API (iOS 16+).
        // Status must be checked manually — the method itself does not throw.
        await writer.finishWriting()

        if writer.status == .failed {
            throw ClipWriterError.writerFinishFailed(
                writer.error?.localizedDescription ?? "Unknown AVAssetWriter failure"
            )
        }
    }

    // MARK: - Convenience URL

    /// Returns a unique `.mov` URL in the app's Documents directory.
    nonisolated func makeClipURL() -> URL {
        let docs = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return docs.appendingPathComponent("clip_\(UUID().uuidString).mov")
    }
}
