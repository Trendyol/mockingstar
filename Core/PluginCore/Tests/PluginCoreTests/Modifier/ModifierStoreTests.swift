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

    let sampleModel = ModifierModel(
        id: "test-modifier",
        path: "/users/1",
        method: "GET",
        scenario: nil,
        enabled: false,
        order: 1,
        sampleMockRequestId: nil,
        transformerCode: "function transformer(req, chain) { return chain.proceed(req) }"
    )

    override func setUp() {
        super.setUp()
        fileManager = .init()
        fileUrlBuilder = .init()
        fileUrlBuilder.stubbedModifierFolderUrlResult = folder
        fileUrlBuilder.stubbedModifierFileUrlResult = fileURL
        fileUrlBuilder.modifierFileUrlHandler = { [folder] _, id in
            folder.appending(path: "\(id).js")
        }
        store = ModifierStore(domain: "Dev", fileManager: fileManager, fileUrlBuilder: fileUrlBuilder)
    }

    func test_list_EmptyFolder_ReturnsEmpty() throws {
        fileManager.stubbedFileOrDirectoryExistsResult = (false, false)
        XCTAssertTrue(try store.list().isEmpty)
    }

    func test_create_WritesCanonicalFile() throws {
        fileManager.stubbedFileExistResult = false
        try store.create(sampleModel)
        XCTAssertTrue(fileManager.invokedWriteContent)
        XCTAssertEqual(fileManager.invokedWriteContentParameters?.url, fileURL)
        let content = try XCTUnwrap(fileManager.invokedWriteContentParameters?.content)
        XCTAssertFalse(content.contains("var id"))
        XCTAssertFalse(content.contains("enabled"))
        XCTAssertTrue(content.contains("var order = 1"))
        XCTAssertTrue(content.contains("function transformer"))
    }

    func test_create_WhenExists_Throws409StyleError() throws {
        fileManager.stubbedFileExistResult = true
        XCTAssertThrowsError(try store.create(sampleModel)) { error in
            guard case ModifierStoreError.alreadyExists("test-modifier") = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    func test_create_InvalidId_Throws() {
        let model = ModifierModel(id: "../evil", path: "/x", method: "GET", transformerCode: "function transformer(req, chain) { return chain.proceed(req) }")
        XCTAssertThrowsError(try store.create(model)) { error in
            guard case ModifierStoreError.invalidId = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    func test_get_ReadsSingleFileByFilename() throws {
        fileManager.stubbedFileExistResult = true
        fileManager.stubbedReadFileResult = """
        var path = "/users/1"
        var method = "GET"
        var order = 2
        function transformer(req, chain) { return chain.proceed(req) }
        """

        let model = try store.get(id: "test-modifier")

        XCTAssertEqual(model?.id, "test-modifier")
        XCTAssertEqual(model?.order, 2)
        XCTAssertEqual(fileManager.invokedReadFileCount, 1)
        XCTAssertFalse(fileManager.invokedFolderContent)
    }

    func test_get_MissingFile_ReturnsNil() throws {
        fileManager.stubbedFileExistResult = false
        XCTAssertNil(try store.get(id: "missing"))
        XCTAssertEqual(fileManager.invokedReadFileCount, 0)
    }

    func test_getIds_ReadsOnlyRequestedFiles() throws {
        fileManager.stubbedFileExistResult = true
        fileManager.stubbedReadFileResult = """
        var path = "/users/1"
        var method = "GET"
        var order = 1
        function transformer(req, chain) { return chain.proceed(req) }
        """
        fileUrlBuilder.stubbedModifierFileUrlResult = URL(filePath: "/tmp/Modifiers/a.js")

        let models = try store.get(ids: ["a", "b"])

        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(fileManager.invokedReadFileCount, 2)
        XCTAssertFalse(fileManager.invokedFolderContent)
    }

    func test_update_RewritesCanonicalFile() throws {
        fileManager.stubbedFileExistResult = true
        try store.update(currentId: sampleModel.id, with: sampleModel)
        XCTAssertTrue(fileManager.invokedWriteContent)
        let content = try XCTUnwrap(fileManager.invokedWriteContentParameters?.content)
        XCTAssertFalse(content.contains("var id"))
        XCTAssertTrue(content.contains("var order = 1"))
    }

    func test_update_MissingFile_ThrowsNotFound() {
        fileManager.stubbedFileExistResult = false
        XCTAssertThrowsError(try store.update(currentId: sampleModel.id, with: sampleModel)) { error in
            guard case ModifierStoreError.notFound("test-modifier") = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    func test_update_RenameWritesThenMovesCanonicalFile() throws {
        let renamed = ModifierModel(
            id: "renamed",
            path: sampleModel.path,
            method: sampleModel.method,
            order: sampleModel.order,
            transformerCode: sampleModel.transformerCode
        )
        fileManager.fileExistHandler = { $0.hasSuffix("/test-modifier.js") }
        fileManager.stubbedReadFileResult = "old content"

        try store.update(currentId: "test-modifier", with: renamed)

        XCTAssertEqual(fileManager.invokedWriteContentParameters?.url, fileURL)
        XCTAssertEqual(
            fileManager.invokedMoveFileParameters?.newPath,
            "/tmp/Modifiers/renamed.js"
        )
    }

    func test_update_RenameTargetExistsThrowsConflictWithoutWriting() {
        let renamed = ModifierModel(
            id: "renamed",
            path: "/users/1",
            method: "GET",
            transformerCode: sampleModel.transformerCode
        )
        fileManager.fileExistHandler = { path in
            path.hasSuffix("/test-modifier.js") || path.hasSuffix("/renamed.js")
        }

        XCTAssertThrowsError(try store.update(currentId: "test-modifier", with: renamed)) {
            guard case ModifierStoreError.alreadyExists("renamed") = $0 else {
                return XCTFail("unexpected \($0)")
            }
        }
        XCTAssertFalse(fileManager.invokedWriteContent)
    }

    func test_update_MoveFailureRestoresOriginalContent() {
        let renamed = ModifierModel(
            id: "renamed",
            path: "/users/1",
            method: "GET",
            transformerCode: sampleModel.transformerCode
        )
        var writes: [String] = []
        fileManager.fileExistHandler = { $0.hasSuffix("/test-modifier.js") }
        fileManager.stubbedReadFileResult = "original source"
        fileManager.writeContentHandler = { content, _ in writes.append(content) }
        fileManager.moveFileHandler = { _, _ in
            throw FileManagerError.moveFileError(NSError(domain: "test", code: 1))
        }

        XCTAssertThrowsError(try store.update(currentId: "test-modifier", with: renamed))
        XCTAssertEqual(writes.last, "original source")
    }

    func test_delete_RemovesFile() throws {
        fileManager.stubbedFileExistResult = true
        try store.delete(id: "test-modifier")
        XCTAssertEqual(fileManager.invokedRemoveFileParameters?.path, fileURL.path())
    }

    func test_list_UsesFilenameAsId_IgnoresEmbeddedId() throws {
        fileManager.stubbedFileOrDirectoryExistsResult = (true, true)
        fileManager.stubbedFolderContentResult = [URL(filePath: "/tmp/Modifiers/file-name.js")]
        fileManager.stubbedReadFileResult = """
        var id = "embedded"
        var path = "/users/1"
        var method = "GET"
        var priority = 5
        function transformer(req, chain) { return chain.proceed(req) }
        """

        let models = try store.list()

        XCTAssertEqual(models.count, 1)
        XCTAssertEqual(models.first?.id, "file-name")
        XCTAssertEqual(models.first?.order, 5)
    }

    func test_list_SkipsCorruptFiles() throws {
        fileManager.stubbedFileOrDirectoryExistsResult = (true, true)
        fileManager.stubbedFolderContentResult = [
            URL(filePath: "/tmp/Modifiers/good.js"),
            URL(filePath: "/tmp/Modifiers/bad.js"),
        ]
        fileManager.stubbedReadFileResult = "var path = "
        // First read fails (syntax), second also uses same stub — both skipped is fine for corrupt path.
        // Use a custom sequence via overridden stub by writing two different contents isn't supported;
        // instead verify corrupt-only folder returns empty.
        fileManager.stubbedFolderContentResult = [URL(filePath: "/tmp/Modifiers/bad.js")]
        XCTAssertTrue(try store.list().isEmpty)
    }
}
