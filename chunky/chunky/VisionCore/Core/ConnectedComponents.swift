// chunky/chunky/VisionCore/Core/ConnectedComponents.swift
import Foundation

nonisolated struct Blob: Equatable {
    let pixelCount: Int
    let minX: Int, minY: Int, maxX: Int, maxY: Int
    let sumX: Double, sumY: Double
    var boundingWidth: Int { maxX - minX + 1 }
    var boundingHeight: Int { maxY - minY + 1 }
    var centroid: Vec2 { Vec2(sumX / Double(pixelCount), sumY / Double(pixelCount)) }
}

nonisolated enum ConnectedComponents {
    static func blobs(in image: GrayImage, threshold: UInt8) -> [Blob] {
        let w = image.width, h = image.height
        var visited = [Bool](repeating: false, count: w * h)
        var result: [Blob] = []
        var stack: [(Int, Int)] = []
        for startY in 0..<h {
            for startX in 0..<w {
                let idx0 = startY * w + startX
                if visited[idx0] || image.pixels[idx0] <= threshold { continue }
                stack.removeAll(keepingCapacity: true)
                stack.append((startX, startY))
                visited[idx0] = true
                var count = 0, sumX = 0.0, sumY = 0.0
                var minX = startX, minY = startY, maxX = startX, maxY = startY
                while let (x, y) = stack.popLast() {
                    count += 1; sumX += Double(x); sumY += Double(y)
                    minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
                    for (dx, dy) in [(1,0),(-1,0),(0,1),(0,-1)] {
                        let nx = x + dx, ny = y + dy
                        guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
                        let nIdx = ny * w + nx
                        if !visited[nIdx] && image.pixels[nIdx] > threshold {
                            visited[nIdx] = true
                            stack.append((nx, ny))
                        }
                    }
                }
                result.append(Blob(pixelCount: count, minX: minX, minY: minY, maxX: maxX, maxY: maxY, sumX: sumX, sumY: sumY))
            }
        }
        return result
    }
}
