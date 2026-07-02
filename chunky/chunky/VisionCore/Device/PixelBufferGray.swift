// chunky/chunky/VisionCore/Device/PixelBufferGray.swift
import CoreVideo

/// Converts a CVPixelBuffer to a GrayImage by reading the luma plane.
///
/// Supported pixel formats:
/// - kCVPixelFormatType_420YpCbCr8BiPlanarFullRange  (420f)
/// - kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange (420v)
/// - kCVPixelFormatType_32BGRA (fallback: uses the G channel)
///
/// Returns nil for unsupported formats.
nonisolated enum PixelBufferGray {

    static func grayImage(from pixelBuffer: CVPixelBuffer) -> GrayImage? {
        // Skip (don't trap) a degenerate zero-dimension buffer: GrayImage's
        // precondition would crash the caller, whereas callers already handle
        // a nil return by skipping the frame. Real capture buffers are never
        // zero-dimension; this is defensive.
        guard CVPixelBufferGetWidth(pixelBuffer) > 0,
              CVPixelBufferGetHeight(pixelBuffer) > 0 else {
            return nil
        }

        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)

        switch format {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
             kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            return lumaFromBiplanar(pixelBuffer)

        case kCVPixelFormatType_32BGRA:
            return grayFromBGRA(pixelBuffer)

        default:
            return nil
        }
    }

    // MARK: - Private helpers

    /// Reads plane 0 (luma) of a 420 YpCbCr8 BiPlanar buffer into a contiguous GrayImage.
    /// Correctly handles bytesPerRowOfPlane padding by copying only `width` bytes per row.
    private static func lumaFromBiplanar(_ pixelBuffer: CVPixelBuffer) -> GrayImage? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddr = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
            return nil
        }

        let width  = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bpr    = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)

        let src = baseAddr.assumingMemoryBound(to: UInt8.self)
        var pixels = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            let srcRow = src.advanced(by: y * bpr)
            let dstOffset = y * width
            pixels.withUnsafeMutableBufferPointer { dst in
                UnsafeMutableRawPointer(dst.baseAddress! + dstOffset)
                    .copyMemory(from: srcRow, byteCount: width)
            }
        }

        return GrayImage(width: width, height: height, pixels: pixels)
    }

    /// Reads the G channel of a 32BGRA buffer as a grayscale approximation.
    private static func grayFromBGRA(_ pixelBuffer: CVPixelBuffer) -> GrayImage? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddr = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        let width  = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bpr    = CVPixelBufferGetBytesPerRow(pixelBuffer)

        let src = baseAddr.assumingMemoryBound(to: UInt8.self)
        var pixels = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                // BGRA layout: byte offsets B=0, G=1, R=2, A=3
                pixels[y * width + x] = src[y * bpr + x * 4 + 1]  // G channel
            }
        }

        return GrayImage(width: width, height: height, pixels: pixels)
    }
}
