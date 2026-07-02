// chunky/chunkyTests/RingBufferTests.swift
import XCTest
@testable import chunky

final class RingBufferTests: XCTestCase {
    func testAppendsUntilFull() {
        var b = RingBuffer<Int>(capacity: 3)
        b.append(1); b.append(2)
        XCTAssertEqual(b.elements, [1, 2])
        XCTAssertFalse(b.isFull)
        b.append(3)
        XCTAssertTrue(b.isFull)
        XCTAssertEqual(b.elements, [1, 2, 3])
    }

    func testOverwritesOldestWhenFull() {
        var b = RingBuffer<Int>(capacity: 3)
        [1, 2, 3, 4, 5].forEach { b.append($0) }
        XCTAssertEqual(b.elements, [3, 4, 5]) // oldest two evicted
        XCTAssertEqual(b.count, 3)
    }

    func testRemoveAll() {
        var b = RingBuffer<Int>(capacity: 2)
        b.append(1); b.removeAll()
        XCTAssertEqual(b.count, 0)
        XCTAssertEqual(b.elements, [])
        XCTAssertFalse(b.isFull)
    }
}
