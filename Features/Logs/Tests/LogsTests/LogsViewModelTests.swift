//
//  LogsViewModelTests.swift
//
//
//  Created by Yusuf Özgül on 11.11.2023.
//

import CommonKit
import CommonKitTestSupport
import XCTest
@testable import Logs

final class LogsViewModelTests: XCTestCase {
    private var viewModel: LogsViewModel!
    private var logStream: MockLogStreamHandler!

    override func setUp() {
        super.setUp()
        logStream = .init()
        viewModel = .init(logStreamHandler: logStream)

        let (stream, continuation) = AsyncStream.makeStream(of: LogModel.self)
        logStream.stubbedStreamResult = stream
        continuation.finish()
    }

    @MainActor
    func test_ListenLogs_Fill_filteredLogs() async {
        let log = LogModel(severity: .warning, message: "Test Data", category: "LogsViewModelTests")
        logStream.stubbedReadAllLogsResult = [log]
        await viewModel.readLogs()

        XCTAssertEqual(viewModel.filteredLogs, [log])
    }

    @MainActor
    func test_filterLogs_search() async {
        let log = LogModel(severity: .warning, message: "Test Data", category: "LogsViewModelTests")
        logStream.stubbedReadAllLogsResult = [log]
        await viewModel.readLogs()

        XCTAssertEqual(viewModel.filteredLogs, [log])

        viewModel.searchTerm = "example-log"
        viewModel.filterLogs()

        XCTAssertEqual(viewModel.filteredLogs, [])
    }

    @MainActor
    func test_filterLogs_filter() async {
        let log = LogModel(severity: .debug, message: "Test Data", category: "LogsViewModelTests")
        logStream.stubbedReadAllLogsResult = [log]
        await viewModel.readLogs()

        viewModel.filterType = [.info, .notice, .warning, .error, .critical, .fault]
        viewModel.filterLogs()

        XCTAssertEqual(viewModel.filteredLogs, [])
    }
}
