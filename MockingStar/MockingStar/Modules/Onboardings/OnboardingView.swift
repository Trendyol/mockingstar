//
//  OnboardingView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import SwiftUI

struct OnboardingView: View {
    @State private var state: OnboardingState = .welcomeView
    @AppStorage("isOnboardingDone") private var isOnboardingDone: Bool = false

    var body: some View {
        Group {
            switch state {
            case .welcomeView:
                WelcomeView {
                    withAnimation { state = .folderSelection }
                }
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .leading))
                .animation(.linear, value: state)
            case .folderSelection:
                InitialSettingsView() {
                    withAnimation { state = .privacyInfo }
                }
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .trailing))
                .animation(.linear, value: state)
            case .privacyInfo:
                PrivacyAlertView() {
                    withAnimation { state = .done }
                }
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .trailing))
                .animation(.linear, value: state)
            case .done:
                WelcomeView {}
                    .task { isOnboardingDone = true }
            }
        }
    }
}

#Preview {
    OnboardingView()
}

enum OnboardingState {
    case welcomeView
    case folderSelection
    case privacyInfo
    case done
}
