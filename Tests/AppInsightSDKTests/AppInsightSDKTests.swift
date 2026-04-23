import XCTest
@testable import AppInsightSDK

final class AppInsightSDKTests: XCTestCase {

    func testScreenTrackerAppearedDisappeared() {
        let tracker = ScreenTracker()

        let ts = tracker.appeared("HomeScreen")
        XCTAssertGreaterThan(ts, 0)

        Thread.sleep(forTimeInterval: 0.05)

        let result = tracker.disappeared("HomeScreen")
        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result!.durationMs, 40)
    }

    func testScreenTrackerDisappearedWithoutAppeared() {
        let tracker = ScreenTracker()
        let result = tracker.disappeared("UnknownScreen")
        XCTAssertNil(result)
    }

    func testInboundInitOkParsing() {
        let json = """
        {"type":"init_ok","app_id":"abc-123","session_id":"sess-456"}
        """.data(using: .utf8)!

        let msg = InboundMessage.parse(from: json)
        if case .initOk(let appId, let sessionId) = msg {
            XCTAssertEqual(appId, "abc-123")
            XCTAssertEqual(sessionId, "sess-456")
        } else {
            XCTFail("Expected initOk")
        }
    }

    func testInboundInitErrorParsing() {
        let json = """
        {"type":"init_error","code":"BUNDLE_ID_MISMATCH","message":"mismatch"}
        """.data(using: .utf8)!

        let msg = InboundMessage.parse(from: json)
        if case .initError(let code, let message) = msg {
            XCTAssertEqual(code, "BUNDLE_ID_MISMATCH")
            XCTAssertEqual(message, "mismatch")
        } else {
            XCTFail("Expected initError")
        }
    }

    func testInboundInsightPushParsing() {
        let json = """
        {
          "type": "insight_push",
          "insight_id": "ins-1",
          "title": "Fırsat!",
          "body": "Hemen al",
          "data": {"code": "SAVE10"},
          "target_screen": "checkout",
          "display": {"style": "banner", "duration_ms": 5000},
          "action": {"type": "deeplink", "url": "app://promo"}
        }
        """.data(using: .utf8)!

        let msg = InboundMessage.parse(from: json)
        if case .insightPush(let insight) = msg {
            XCTAssertEqual(insight.id, "ins-1")
            XCTAssertEqual(insight.title, "Fırsat!")
            XCTAssertEqual(insight.body, "Hemen al")
            XCTAssertEqual(insight.targetScreen, "checkout")
            XCTAssertEqual(insight.data["code"] as? String, "SAVE10")
            XCTAssertEqual(insight.display?.style, "banner")
            XCTAssertEqual(insight.action?.url, "app://promo")
        } else {
            XCTFail("Expected insightPush")
        }
    }

    func testInboundDataPushParsing() {
        let json = """
        {"type":"data_push","event":"promo_banner","data":{"image":"url"}}
        """.data(using: .utf8)!

        let msg = InboundMessage.parse(from: json)
        if case .dataPush(let event, let data) = msg {
            XCTAssertEqual(event, "promo_banner")
            XCTAssertEqual(data["image"] as? String, "url")
        } else {
            XCTFail("Expected dataPush")
        }
    }

    func testSdkInitPayloadSerialization() {
        let payload = SdkInitPayload(
            apiKey: "ak_test", deviceId: "dev-1", sessionId: "sess-1",
            platform: "ios", bundleId: "com.test.app",
            appVersion: "1.0.0", osVersion: "17.4", model: "iPhone16,2"
        )
        let data = OutboundMessage.sdkInit(payload).toJSON()
        XCTAssertNotNil(data)

        let json = try? JSONSerialization.jsonObject(with: data!) as? [String: Any]
        XCTAssertEqual(json?["type"] as? String, "sdk_init")
        XCTAssertEqual(json?["api_key"] as? String, "ak_test")
        XCTAssertEqual(json?["platform"] as? String, "ios")
    }

    func testScreenEventPayloadSerialization() {
        let payload = ScreenEventPayload(
            apiKey: "ak_test", deviceId: "dev-1", sessionId: "sess-1",
            screen: "HomeScreen", event: "disappeared",
            ts: 1713700000000, durationMs: 4500
        )
        let data = OutboundMessage.screenEvent(payload).toJSON()
        XCTAssertNotNil(data)

        let json = try? JSONSerialization.jsonObject(with: data!) as? [String: Any]
        XCTAssertEqual(json?["type"] as? String, "screen_event")
        let p = json?["payload"] as? [String: Any]
        XCTAssertEqual(p?["screen"] as? String, "HomeScreen")
        XCTAssertEqual(p?["event"] as? String, "disappeared")
        XCTAssertEqual(p?["duration_ms"] as? Int, 4500)
    }
}
