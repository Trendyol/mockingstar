import XCTest
@testable import PluginCore
import CommonKit
import CommonKitTestSupport

final class ModifierStoreTests: XCTestCase {
    var store: ModifierStore!
    var fileManager: MockFileManager!
    var fileUrlBuilder: MockFileUrlBuilder!

    let folder = URL(filePath: "/tmp/Modifiers")
    let fileURL = URL(filePath: "/tmp/Modifiers/test-modifier.js")

    let sampleCode = """
    var id = "test-modifier"
    var path = "/users/1"
    var method = "GET"
    var scenario = null
    var enabled = false
    var priority = 0
    var sampleMockRequestId = null
    function transformer(req, chain) { return chain.proceed(req) }
    """

    override func setUp() {
        super.setUp()
        fileManager = .init()
        fileUrlBuilder = .init()
        fileUrlBuilder.stubbedModifierFolderUrlResult = folder
        fileUrlBuilder.stubbedModifierFileUrlResult = fileURL
        store = ModifierStore(domain: "Dev", fileManager: fileManager, fileUrlBuilder: fileUrlBuilder)
    }

    func test_list_EmptyFolder_ReturnsEmpty() throws {
        fileManager.stubbedFileOrDirectoryExistsResult = (false, false)
        XCTAssertTrue(try store.list().isEmpty)
    }

    func test_create_WritesFile() throws {
        fileManager.stubbedFileExistResult = false
        let model = try ModifierParser().parse(jsCode: sampleCode)
        try store.create(model)
        XCTAssertTrue(fileManager.invokedWriteContent)
        XCTAssertEqual(fileManager.invokedWriteContentParameters?.url, fileURL)
        XCTAssertEqual(fileManager.invokedWriteContentParameters?.content, sampleCode)
    }

    func test_create_WhenExists_Throws409StyleError() throws {
        fileManager.stubbedFileExistResult = true
        let model = try ModifierParser().parse(jsCode: sampleCode)
        XCTAssertThrowsError(try store.create(model))
    }

    func test_delete_RemovesFile() throws {
        try store.delete(id: "test-modifier")
        XCTAssertEqual(fileManager.invokedRemoveFileParameters?.path, fileURL.path())
    }
}
