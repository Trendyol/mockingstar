//
//  OnboardingView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import SwiftUI

struct OnboardingView: View {
    @State private var isWelcomeView = true
    @AppStorage("isOnboardingDone") private var isOnboardingDone: Bool = false

    var body: some View {
        Group {
            if isWelcomeView {
                WelcomeView() {
                    withAnimation {
                        isWelcomeView = false
                    }
                }
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .leading))
                .animation(.linear, value: isWelcomeView)
            } else {
                InitialSettingsView() {
                    isOnboardingDone = true
                }
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .trailing))
                .animation(.linear, value: isWelcomeView)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
