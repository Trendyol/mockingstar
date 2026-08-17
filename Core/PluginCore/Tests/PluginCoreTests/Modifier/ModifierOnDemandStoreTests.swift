import XCTest
@testable import PluginCore
import CommonKit
import CommonKitTestSupport

final class ModifierOnDemandStoreTests: XCTestCase {
    func test_getIds_DoesNotEnumerateFolder_AndScalesWithRequestedIds() throws {
        let fileManager = MockFileManager()
        let fileUrlBuilder = MockFileUrlBuilder()
        fileUrlBuilder.stubbedModifierFileUrlResult = URL(filePath: "/tmp/Modifiers/a.js")
        fileManager.stubbedFileExistResult = true
        fileManager.stubbedReadFileResult = """
        var path = "/x"
        var method = "GET"
        var order = 1
        function transformer(req, chain) { return chain.proceed(req) }
        """

        let store = ModifierStore(domain: "Dev", fileManager: fileManager, fileUrlBuilder: fileUrlBuilder)
        let models = try store.get(ids: ["a", "b", "c"])

        XCTAssertEqual(models.count, 3)
        XCTAssertEqual(fileManager.invokedReadFileCount, 3)
        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertEqual(fileManager.invokedFolderContentCount, 0)
    }
}
