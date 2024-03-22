//
//  MockModelTests.swift
//  
//
//  Created by Yusuf Özgül on 31.08.2023.
//

import XCTest
@testable import CommonKit

final class MockModelTests: XCTestCase {
    var model: MockModel!

    override func setUpWithError() throws {
        try super.setUpWithError()
        try reCreate()
    }

    func reCreate(url: String = "https://www.trendyol.com/aboutus", scenario: String = "") throws {
        let url = try XCTUnwrap(URL(string: url))

        model = MockModel(metaData: .init(url: url,
                                          method: "GET",
                                          appendTime: .init(),
                                          updateTime: .init(),
                                          httpStatus: 200,
                                          responseTime: 0.15,
                                          scenario: scenario,
                                          id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                          requestHeader: "",
                          responseHeader: "",
                          requestBody: .init(""),
                          responseBody: .init(""))
    }

    func test_MockModel_fileName() {
        XCTAssertEqual(model.fileName, "aboutus_9271C0BE-9326-443F-97B8-1ECA29571FC3.json")
    }

    func test_MockModel_fileName_WithNoPath() throws {
        try reCreate(url: "https://www.trendyol.com")

        XCTAssertEqual(model.fileName, "www.trendyol.com_9271C0BE-9326-443F-97B8-1ECA29571FC3.json")
    }

    func test_MockModel_longFileName_WithNoPath() throws {
        try reCreate(url: "https://www.trendyol.com/aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus")

        XCTAssertEqual(model.fileName, "9271C0BE-9326-443F-97B8-1ECA29571FC3.json")
    }

    func test_MockModel_fileName_WithNoPathJustSlash() throws {
        try reCreate(url: "https://www.trendyol.com/")

        XCTAssertEqual(model.fileName, "www.trendyol.com_9271C0BE-9326-443F-97B8-1ECA29571FC3.json")
    }

    func test_MockModel_fileName_WithScenario() throws {
       try reCreate(scenario: "EmptyResponse")

        XCTAssertEqual(model.fileName, "aboutus_EmptyResponse_9271C0BE-9326-443F-97B8-1ECA29571FC3.json")
    }

    func test_MockModel_longfileName_WithScenario() throws {
        try reCreate(url: "https://www.trendyol.com/aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus", scenario: "EmptyResponse")

        XCTAssertEqual(model.fileName, "EmptyResponse_9271C0BE-9326-443F-97B8-1ECA29571FC3.json")
    }

    func test_MockModel_folderPath() {
        XCTAssertEqual(model.folderPath, "aboutus/GET")
    }

    func test_MockModel_filePath() {
        XCTAssertEqual(model.filePath, "aboutus/GET/aboutus_9271C0BE-9326-443F-97B8-1ECA29571FC3.json")
    }
}
