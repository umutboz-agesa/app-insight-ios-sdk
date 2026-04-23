import Foundation
import os.log

enum AILogger {
    private static let log = OSLog(subsystem: "com.appinsight.sdk", category: "AppInsightSDK")

    static func info(_ msg: String) {
        os_log("[AppInsight] %{public}@", log: log, type: .info, msg)
    }

    static func error(_ msg: String) {
        os_log("[AppInsight] ⚠️ %{public}@", log: log, type: .error, msg)
    }
}
