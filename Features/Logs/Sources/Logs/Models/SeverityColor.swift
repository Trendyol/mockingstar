//
//  SeverityColor.swift
//
//
//  Created by Yusuf Özgül on 14.11.2023.
//

import CommonKit
import Foundation
import SwiftUI

extension LogSeverity {
    var color: Color {
        switch self {
        case .debug: Color.secondary
        case .info: Color.secondary
        case .notice: Color.secondary
        case .warning: Color.yellow
        case .error: Color.red.opacity(0.8)
        case .critical: Color.red.opacity(0.9)
        case .fault: Color.red
        }
    }
}
