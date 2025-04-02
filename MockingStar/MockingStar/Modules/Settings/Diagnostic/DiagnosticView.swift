//
//  DiagnosticView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import SwiftUI
import CommonKit

struct DiagnosticView: View {
    private let onboardingCompleted = OnboardingCompleted.shared
    let viewModel = DiagnosticViewModel()

    var body: some View {
        ScrollView {
            if !onboardingCompleted.completed {
                if #available(macOS 15.0, *) {
                    Image(systemName: "arrowshape.up")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .scaledToFit()
                        .symbolEffect(.breathe, options: .speed(0.4).repeat(10), value: Bool.random())
                }

                Text("Mocking Star couldn't start successfully. Please check Workspaces.")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .padding(.bottom)
            }

            ForEach(viewModel.diagnosticItems, id: \.self) { item in
                DiagnosticItem(icon: item.icon,
                               name: item.name,
                               errorMessage: item.errorMessage,
                               isLoading: item.isLoading,
                               isSuccess: item.isSuccess)
            }

            Button {
                viewModel.startDiagnostic()
            } label: {
                Text("Start Diagnostic")
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding(7)
                    .padding(.horizontal, 40)
                    .background(Color.accentColor)
                    .clipShape(.rect(cornerRadius: 15))
            }
            .padding(.horizontal)
            .buttonStyle(.plain)
        }
        .contentMargins(10, for: .scrollContent)
        .padding(.horizontal)
    }
}

struct DiagnosticItem: View {
    let icon: String
    let name: String
    let errorMessage: String
    var isLoading: Bool
    var isSuccess: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 25)
            Text(name)

            if isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
            } else if isSuccess {
                Text("Working")
                    .foregroundStyle(.green)
            } else {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    DiagnosticView()
}
