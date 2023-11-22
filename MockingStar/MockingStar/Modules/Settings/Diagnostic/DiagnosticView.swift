//
//  DiagnosticView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import SwiftUI

struct DiagnosticView: View {
    let viewModel = DiagnosticViewModel()

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(viewModel.diagnosticItems, id: \.self) { item in
                DiagnosticItem(icon: item.icon,
                               name: item.name,
                               errorMessage: item.errorMessage,
                               isLoading: item.isLoading,
                               isSuccess: item.isSuccess)
            }

            Button("Check") {
                viewModel.startDiagnostic()
            }
        }
        .padding()
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
    }
}

#Preview {
    DiagnosticView()
}
