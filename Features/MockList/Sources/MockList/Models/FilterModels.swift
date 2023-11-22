////
////  FilterModels.swift
////  MockingStar
////
////  Created by Yusuf Özgül on 22.09.2023.
////
//
//import Foundation
//
//enum FilterType: String, Codable, CaseIterable {
//    case all
//    case path, query
//    case scenario
//    //case requestHeader, responseHeader
//    case method
//    //    case responseBody
//
//    var title: String {
//        switch self {
//        case .all: "All"
//        case .path: "Path"
//        case .query: "Query"
//        case .scenario: "Scenario"
//        case .method: "Method"
//        }
//    }
//}
//
//enum FilterStyle: String, Codable, CaseIterable {
//    case contains, notContains
//    case startWith, endWith
//    case equal, notEqual
//
//    var title: String {
//        switch self {
//        case .contains: "Contains"
//        case .notContains: "Not Contains"
//        case .startWith: "Starts With"
//        case .endWith: "End With"
//        case .equal: "Equal"
//        case .notEqual: "Not Equal"
//        }
//    }
//}
