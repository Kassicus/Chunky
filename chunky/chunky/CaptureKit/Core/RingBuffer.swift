// chunky/chunky/CaptureKit/Core/RingBuffer.swift
import Foundation

/// Fixed-capacity buffer that overwrites the oldest element when full.
/// Pure value type — no capture frameworks. Holds the last N frames/samples.
nonisolated struct RingBuffer<Element> {
    private var storage: [Element] = []
    let capacity: Int

    init(capacity: Int) {
        precondition(capacity > 0, "RingBuffer capacity must be positive")
        self.capacity = capacity
        storage.reserveCapacity(capacity)
    }

    mutating func append(_ element: Element) {
        if storage.count == capacity { storage.removeFirst() }
        storage.append(element)
    }

    var elements: [Element] { storage }   // oldest → newest
    var count: Int { storage.count }
    var isFull: Bool { storage.count == capacity }

    mutating func removeAll() { storage.removeAll(keepingCapacity: true) }
}

extension RingBuffer: Sendable where Element: Sendable {}
