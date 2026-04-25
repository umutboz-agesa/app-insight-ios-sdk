import Foundation
import os.log

enum AppInsightLogger {
    private static let log = OSLog(subsystem: "com.appinsight.sdk", category: "AppInsightSDK")

    /// Set AppInsight.shared.isDebug = true to enable verbose logs.
    static var isDebug: Bool = false

    static func debug(_ msg: String) {
        guard isDebug else { return }
        os_log("[AppInsight] 🔍 %{public}@", log: log, type: .debug, msg)
    }

    static func info(_ msg: String) {
        os_log("[AppInsight] %{public}@", log: log, type: .info, msg)
    }

    static func error(_ msg: String) {
        os_log("[AppInsight] ⚠️ %{public}@", log: log, type: .error, msg)
    }
}
