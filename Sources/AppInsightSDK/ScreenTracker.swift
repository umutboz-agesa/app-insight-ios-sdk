import Foundation

final class ScreenTracker {

    // screen name → appeared timestamp (ms)
    private var activeScreens: [String: Int64] = [:]
    private let lock = NSLock()

    /// Ekran göründü. Timestamp döner (ms).
    func appeared(_ name: String) -> Int64 {
        let ts = nowMs()
        lock.withLock { activeScreens[name] = ts }
        return ts
    }

    /// Ekran kapandı. (ts, durationMs) döner.
    func disappeared(_ name: String) -> (ts: Int64, durationMs: Int)? {
        let ts = nowMs()
        let startTs: Int64? = lock.withLock {
            let v = activeScreens[name]
            activeScreens.removeValue(forKey: name)
            return v
        }
        guard let start = startTs else { return nil }
        let duration = Int(ts - start)
        return (ts, duration)
    }

    private func nowMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
