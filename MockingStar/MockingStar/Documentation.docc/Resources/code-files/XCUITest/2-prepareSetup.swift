import XCTest
import MockingStar

@MainActor
final class MockingStarExampleUITests: XCTestCase, BaseMockXCTest {
    let deviceId: String = UUID().uuidString
    let mockDomain: String = "Example"
    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        app.launchEnvironment["MockingStarDomain"] = mockDomain
        app.launchEnvironment["MockingStar_DoNotUseLive"] = "1"
        app.launchEnvironment["DeviceID"] = deviceId
        app.launchEnvironment["EnableMockingStar"] = "1"
        app.launch()
    }
}