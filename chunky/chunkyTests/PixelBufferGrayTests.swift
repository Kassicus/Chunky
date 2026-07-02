// chunky/chunkyTests/PixelBufferGrayTests.swift
import XCTest
import CoreVideo
@testable import chunky

final class PixelBufferGrayTests: XCTestCase {
    func testConvertsLumaPlane() throws {
        // Create a 4x2 420f buffer and write a known luma pattern into plane 0.
        var pb: CVPixelBuffer?
        let attrs = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, 4, 2, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, attrs, &pb)
        let buffer = try XCTUnwrap(pb)
        CVPixelBufferLockBaseAddress(buffer, [])
        let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0)!.assumingMemoryBound(to: UInt8.self)
        let bpr = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        for y in 0..<2 { for x in 0..<4 { base[y*bpr + x] = UInt8(y*4 + x) } }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        let img = try XCTUnwrap(PixelBufferGray.grayImage(from: buffer))
        XCTAssertEqual(img.width, 4); XCTAssertEqual(img.height, 2)
        XCTAssertEqual(img.pixel(x: 3, y: 1), 7)   // y*4+x = 1*4+3
        XCTAssertEqual(img.pixel(x: 0, y: 0), 0)
    }
}
