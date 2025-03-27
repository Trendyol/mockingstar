//
//  OnboardingCompleted.swift
//  CommonKit
//
//  Created by Yusuf Özgül on 27.03.2025.
//

#if os(macOS)
import SwiftUI

@Observable public class OnboardingCompleted {
    public static let shared = OnboardingCompleted()
    public var completed: Bool = false
}
#endif
