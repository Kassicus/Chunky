import Foundation

/// Serializes a tracked ball path to/from a compact JSON string for
/// `Shot.rawTrackJSON`, so carry can be recomputed later (spec §10).
nonisolated enum ShotTrackCodec {
    static func encode(_ track: [TrackPoint]) -> String {
        guard let data = try? JSONEncoder().encode(track),
              let s = String(data: data, encoding: .utf8) else { return "[]" }
        return s
    }

    static func decode(_ json: String) -> [TrackPoint]? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([TrackPoint].self, from: data)
    }
}
