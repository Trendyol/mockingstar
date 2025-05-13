//
//  MockImportView.swift
//  MockList
//
//  Created by Yusuf Özgül on 7.03.2025.
//

import SwiftUI
import TipKit

struct MockImportView: View {
    @Bindable var viewModel: MockImportViewModel
    @AppStorage("mockDomain") var mockDomain: String = ""
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) var dismiss

    init(viewModel: MockImportViewModel = MockImportViewModel()) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack {
            Picker(selection: $viewModel.mockImportStyle, content: {
                ForEach(MockImportStyle.allCases, id: \.self) {
                    Text($0.title).tag($0)
                }
            }, label: EmptyView.init)
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)

            VStack {
                ScrollView {
                    TextField(text: $viewModel.importInput, prompt: Text(viewModel.mockImportStyle.placeholder), axis: .vertical, label: EmptyView.init)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.leading)
                        .focused($isInputFocused)
                }
                .frame(maxHeight: 350)

                PasteButton(payloadType: String.self) { strings in
                    guard let file = strings.first else { return }
                    viewModel.importInput = file
                }
                .padding(.horizontal)
                .buttonStyle(.plain)
            }
            .padding(6)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.tertiary, lineWidth: 2)
            }
            .padding(10)

            if !viewModel.importFailedMessage.isEmpty {
                Text(viewModel.importFailedMessage)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .textSelection(.enabled)
            }

            TipView(MockImportTip())
                .padding(.horizontal)

            TipView(MockImportNewStyleTip())
                .padding([.horizontal, .bottom])

            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .padding(7)
                        .padding(.horizontal, 40)
                        .padding(.bottom)
                }
                .padding(.horizontal)
                .buttonStyle(.plain)

                Button {
                    Task { await viewModel.importMock(for: mockDomain) }
                } label: {
                    Text("Import")
                        .foregroundColor(viewModel.isLoading ? .accentColor : .white)
                        .font(.headline)
                        .padding(7)
                        .padding(.horizontal, 40)
                        .background(Color.accentColor)
                        .clipShape(.rect(cornerRadius: 15))
                        .padding(.bottom)
                        .overlay {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .controlSize(.small)
                                    .padding(.bottom)
                            }
                        }
                }
                .padding(.horizontal)
                .buttonStyle(.plain)
                .disabled(viewModel.importInput.isEmpty)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1))
            isInputFocused = true
        }
        .onChange(of: viewModel.shouldShowImportDone) { _, newValue in
            guard newValue else { return }
            dismiss()
        }
        .onChange(of: viewModel.mockImportStyle) {
            viewModel.importInput = ""
        }
    }
}

#Preview {
    MockImportView()
}

struct MockImportTip: Tip {
    var title: Text {
        Text("Mock Import")
    }

    var message: Text? {
        Text("Now you can import mocks using cURL or URL. Mock'll import current selected mock domain.")
    }

    var image: Image? {
        Image(systemName: "square.and.arrow.down")
    }
}

struct MockImportNewStyleTip: Tip {
    var title: Text {
        Text("Do you want to import different way?")
    }

    var message: Text? {
        Text("Mocking Star is open source. You can contribute or create an issue.")
    }

    var actions: [Action] {
        Action(title: "Open Github") {
            NSWorkspace.shared.open(URL(string: "https://github.com/Trendyol/mockingstar")!)
        }
    }
}
