//
//  LogsViewModelTests.swift
//  
//
//  Created by Yusuf Özgül on 11.11.2023.
//

import CommonKit
import XCTest
@testable import Logs

final class LogsViewModelTests: XCTestCase {
    private var viewModel: LogsViewModel!
    private var allLogsStream: AsyncStream<[LogModel]>!
    private var allLogsContinuation: AsyncStream<[LogModel]>.Continuation!

    override func setUp() {
        super.setUp()

        (allLogsStream, allLogsContinuation) = AsyncStream.makeStream(of: [LogModel].self)
        viewModel = .init(logsStream: allLogsStream)
    }

    func test_ListenLogs_Fill_filteredLogs() {
        XCTAssertEqual(viewModel.filteredLogs, [])

        let log =  LogModel(severity: .debug, message: "Test Data", category: "LogsViewModelTests")

        allLogsContinuation.yield([log])

        expectation(description: "logs").isInverted = true
        waitForExpectations(timeout: 1, handler: nil)

        XCTAssertEqual(viewModel.filteredLogs, [log])
    }

    @MainActor func test_filterLogs_search() {
        XCTAssertEqual(viewModel.filteredLogs, [])

        let log =  LogModel(severity: .debug, message: "Test Data", category: "LogsViewModelTests")

        allLogsContinuation.yield([log])

        expectation(description: "logs").isInverted = true
        waitForExpectations(timeout: 1, handler: nil)

        XCTAssertEqual(viewModel.filteredLogs, [log])

        viewModel.searchTerm = "example-log"
        viewModel.filterLogs()

        XCTAssertEqual(viewModel.filteredLogs, [])
    }

    @MainActor func test_filterLogs_filter() {
        XCTAssertEqual(viewModel.filteredLogs, [])

        let log =  LogModel(severity: .debug, message: "Test Data", category: "LogsViewModelTests")

        allLogsContinuation.yield([log])

        expectation(description: "logs").isInverted = true
        waitForExpectations(timeout: 1, handler: nil)

        XCTAssertEqual(viewModel.filteredLogs, [log])

        viewModel.filterType = [.info, .notice, .warning, .error, .critical, .fault]
        viewModel.filterLogs()

        XCTAssertEqual(viewModel.filteredLogs, [])
    }
}
