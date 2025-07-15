//
//  MockModelTests.swift
//  
//
//  Created by Yusuf Özgül on 31.08.2023.
//

import XCTest
import AnyCodable
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

// MARK: - MockModelBody Tests
final class MockModelBodyTests: XCTestCase {
    
    // MARK: - Factory Method Tests
    func test_MockModelBody_fromString_null() throws {
        let emptyBody = try MockModelBody.from(string: "")
        let whitespaceBody = try MockModelBody.from(string: "   \n  \t  ")
        
        XCTAssertEqual(emptyBody.description, "")
        XCTAssertEqual(whitespaceBody.description, "")
        
        if case .null = emptyBody {
            // Success
        } else {
            XCTFail("Expected .null case for empty string")
        }
        
        if case .null = whitespaceBody {
            // Success  
        } else {
            XCTFail("Expected .null case for whitespace string")
        }
    }
    
    func test_MockModelBody_fromString_json() throws {
        let jsonString = """
        {
            "name": "John",
            "age": 30,
            "active": true
        }
        """
        
        let jsonBody = try MockModelBody.from(string: jsonString)
        
        if case .json = jsonBody {
            XCTAssertTrue(jsonBody.description.contains("John"))
            XCTAssertTrue(jsonBody.description.contains("30"))
            XCTAssertTrue(jsonBody.description.contains("true"))
        } else {
            XCTFail("Expected .json case for JSON string")
        }
    }
    
    func test_MockModelBody_fromString_html() throws {
        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Test Page</title>
        </head>
        <body>
            <h1>Hello World</h1>
        </body>
        </html>
        """
        
        let htmlBody = try MockModelBody.from(string: htmlString)
        
        if case .html(let content) = htmlBody {
            XCTAssertEqual(content, htmlString)
            XCTAssertEqual(htmlBody.description, htmlString)
        } else {
            XCTFail("Expected .html case for HTML string")
        }
    }
    
    func test_MockModelBody_fromString_xml() throws {
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <note>
            <to>Tove</to>
            <from>Jani</from>
            <heading>Reminder</heading>
            <detail>Don't forget me this weekend!</detail>
        </note>
        """
        
        let xmlBody = try MockModelBody.from(string: xmlString)
        
        if case .xml(let content) = xmlBody {
            XCTAssertEqual(content, xmlString)
            XCTAssertEqual(xmlBody.description, xmlString)
        } else {
            XCTFail("Expected .xml case for XML string")
        }
    }
    
    func test_MockModelBody_fromString_graphql() throws {
        let graphqlString = """
        query GetUser($id: ID!) {
            user(id: $id) {
                name
                email
                posts {
                    title
                    content
                }
            }
        }
        """
        
        let graphqlBody = try MockModelBody.from(string: graphqlString)
        
        if case .graphql(let content) = graphqlBody {
            XCTAssertEqual(content, graphqlString)
            XCTAssertEqual(graphqlBody.description, graphqlString)
        } else {
            XCTFail("Expected .graphql case for GraphQL string")
        }
    }
    
    func test_MockModelBody_fromString_mutation() throws {
        let mutationString = """
        mutation CreateUser($input: UserInput!) {
            createUser(input: $input) {
                id
                name
                email
            }
        }
        """
        
        let mutationBody = try MockModelBody.from(string: mutationString)
        
        if case .graphql(let content) = mutationBody {
            XCTAssertEqual(content, mutationString)
        } else {
            XCTFail("Expected .graphql case for GraphQL mutation")
        }
    }
    
    func test_MockModelBody_fromString_text() throws {
        let textString = "This is just plain text content"
        
        let textBody = try MockModelBody.from(string: textString)
        
        if case .text(let content) = textBody {
            XCTAssertEqual(content, textString)
            XCTAssertEqual(textBody.description, textString)
        } else {
            XCTFail("Expected .text case for plain text string")
        }
    }
    
    // MARK: - Codable Tests
    func test_MockModelBody_codable_null() throws {
        let nullBody = MockModelBody.null
        
        let encoded = try JSONEncoder().encode(nullBody)
        let decoded = try JSONDecoder().decode(MockModelBody.self, from: encoded)
        
        if case .null = decoded {
            XCTAssertEqual(decoded.description, "")
        } else {
            XCTFail("Failed to encode/decode .null case")
        }
    }
    
    func test_MockModelBody_codable_json() throws {
        let jsonData = """
        {"name": "Test", "value": 42}
        """.data(using: .utf8)!
        
        let anyCodable = try JSONDecoder().decode(AnyCodableModel.self, from: jsonData)
        let jsonBody = MockModelBody.json(anyCodable)
        
        let encoded = try JSONEncoder().encode(jsonBody)
        let decoded = try JSONDecoder().decode(MockModelBody.self, from: encoded)
        
        if case .json = decoded {
            XCTAssertTrue(decoded.description.contains("Test"))
            XCTAssertTrue(decoded.description.contains("42"))
        } else {
            XCTFail("Failed to encode/decode .json case")
        }
    }
    
    func test_MockModelBody_codable_html() throws {
        let htmlContent = "<html><body>Test</body></html>"
        let htmlBody = MockModelBody.html(htmlContent)
        
        let encoded = try JSONEncoder().encode(htmlBody)
        let decoded = try JSONDecoder().decode(MockModelBody.self, from: encoded)
        
        if case .html(let content) = decoded {
            XCTAssertEqual(content, htmlContent)
        } else {
            XCTFail("Failed to encode/decode .html case")
        }
    }
    
    // MARK: - MockModel Integration Tests
    func test_MockModel_withNullBodies() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/test"))
        
        let model = MockModel(
            metaData: .init(url: url, method: "POST", appendTime: Date(), updateTime: Date(), 
                          httpStatus: 200, responseTime: 0.1, scenario: "test"),
            requestHeader: "{}",
            responseHeader: "{}",
            requestBody: "",  // Empty should become null
            responseBody: ""  // Empty should become null
        )
        
        // Test encoding/decoding
        let encoded = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(MockModel.self, from: encoded)
        
        XCTAssertEqual(decoded.requestBody, "")
        XCTAssertEqual(decoded.responseBody, "")
    }
    
    func test_MockModel_withJsonBodies() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/test"))
        let requestJson = """
        {"username": "test", "password": "secret"}
        """
        let responseJson = """
        {"id": 123, "token": "abc123", "success": true}
        """
        
        let model = MockModel(
            metaData: .init(url: url, method: "POST", appendTime: Date(), updateTime: Date(), 
                          httpStatus: 200, responseTime: 0.1, scenario: "login"),
            requestHeader: "{}",
            responseHeader: "{}",
            requestBody: requestJson,
            responseBody: responseJson
        )
        
        // Test encoding/decoding
        let encoded = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(MockModel.self, from: encoded)
        
        XCTAssertTrue(decoded.requestBody.contains("username"))
        XCTAssertTrue(decoded.responseBody.contains("token"))
    }
    
    func test_MockModel_withHtmlResponse() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/page"))
        let htmlResponse = """
        <!DOCTYPE html>
        <html>
        <head><title>Test Page</title></head>
        <body><h1>Hello World</h1></body>
        </html>
        """
        
        let model = MockModel(
            metaData: .init(url: url, method: "GET", appendTime: Date(), updateTime: Date(), 
                          httpStatus: 200, responseTime: 0.2, scenario: "html"),
            requestHeader: "{}",
            responseHeader: "{}",
            requestBody: "",
            responseBody: htmlResponse
        )
        
        // Test encoding/decoding
        let encoded = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(MockModel.self, from: encoded)
        
        XCTAssertEqual(decoded.responseBody, htmlResponse)
        XCTAssertTrue(decoded.responseBody.contains("Hello World"))
    }
    
    func test_MockModel_withXmlResponse() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/xml"))
        let xmlResponse = """
        <?xml version="1.0"?>
        <response>
            <status>success</status>
            <data>Test data</data>
        </response>
        """
        
        let model = MockModel(
            metaData: .init(url: url, method: "GET", appendTime: Date(), updateTime: Date(), 
                          httpStatus: 200, responseTime: 0.15, scenario: "xml"),
            requestHeader: "{}",
            responseHeader: "{}",
            requestBody: "",
            responseBody: xmlResponse
        )
        
        // Test encoding/decoding
        let encoded = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(MockModel.self, from: encoded)
        
        XCTAssertEqual(decoded.responseBody, xmlResponse)
        XCTAssertTrue(decoded.responseBody.contains("success"))
    }
    
    func test_MockModel_withGraphqlRequest() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/graphql"))
        let graphqlRequest = """
        query GetUsers {
            users {
                id
                name
                email
            }
        }
        """
        
        let model = MockModel(
            metaData: .init(url: url, method: "POST", appendTime: Date(), updateTime: Date(), 
                          httpStatus: 200, responseTime: 0.3, scenario: "graphql"),
            requestHeader: "{}",
            responseHeader: "{}",
            requestBody: graphqlRequest,
            responseBody: "{\"data\": {\"users\": []}}"
        )
        
        // Test encoding/decoding
        let encoded = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(MockModel.self, from: encoded)
        
        XCTAssertEqual(decoded.requestBody, graphqlRequest)
        XCTAssertTrue(decoded.requestBody.contains("GetUsers"))
    }
}
