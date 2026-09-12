import XCTest
@testable import MockingStarCore

final class MockingStarDeviceIdTests: XCTestCase {
    func test_mockingStarDeviceId_UsesExactDeviceIdKeyOnly() {
        XCTAssertEqual(
            MockingStarCore.mockingStarDeviceId(from: ["deviceId": "maestro-1"]),
            "maestro-1"
        )
        XCTAssertEqual(
            MockingStarCore.mockingStarDeviceId(from: [
                "DeviceId": "f0b2e2ae-aed6-4b67-a189-987ead693cbb"
            ]),
            ""
        )
        XCTAssertEqual(
            MockingStarCore.mockingStarDeviceId(from: [
                "DeviceId": "f0b2e2ae-aed6-4b67-a189-987ead693cbb",
                "deviceId": "maestro-1"
            ]),
            "maestro-1"
        )
        XCTAssertEqual(MockingStarCore.mockingStarDeviceId(from: [:]), "")
    }
}
