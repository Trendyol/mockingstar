//
//  MockDetailInspectorView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 21.09.2023.
//

import CommonKit
import CommonViewsKit
import SwiftUI
import TipKit

struct MockDetailInspectorView: View {
    @Bindable var viewModel: MockDetailInspectorViewModel

    var body: some View {
        List {
            GroupBox {
                VStack {
                    LabeledContent("URL") {
                        VStack(alignment: .leading, spacing: .zero) {
                            TextField("URL", text: $viewModel.url, axis: .vertical)
                                .lineLimit(1...10)
                                .multilineTextAlignment(.leading)
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(viewModel.isUrlValid ? .clear : .red)
                        }
                    }
                    Divider()
                    LabeledContent("Path", value: viewModel.mockModel.metaData.url.path())
                    Divider()
                    LabeledContent("Query", value: viewModel.mockModel.metaData.url.query() ?? "")
                }
                .padding(6)
            } label: {
                Label("Overview", systemImage: "book.pages")
                    .labelStyle(.titleOnly)
                    .font(.title3)
            }
            .listRowSeparator(.hidden)

            GroupBox {
                VStack {
                    LabeledContent("Is Modified", value: viewModel.mockModel.metaData.appendTime == viewModel.mockModel.metaData.updateTime ? "No" : "Yes")
                    Divider()

                    LabeledContent("Mock Scenario") {
                        TextField("Mock Scenario", text: $viewModel.scenario, prompt: Text("Enter a scenario"), axis: .vertical)
                            .lineLimit(1...10)
                            .multilineTextAlignment(.trailing)
                    }

                    Divider()

                    LabeledContent("HTTP Status") {
                        TextField("HTTP Status", value: $viewModel.httpStatus, format: .httpStatus(), prompt: Text("HTTP Status Code"))
                            .multilineTextAlignment(.trailing)
                    }

                    Divider()

                    LabeledContent("Append Date", value: viewModel.mockModel.metaData.appendTime, format: .dateTime)
                    Divider()

                    if viewModel.mockModel.metaData.appendTime != viewModel.mockModel.metaData.updateTime {
                        LabeledContent("Update Date", value: viewModel.mockModel.metaData.updateTime, format: .dateTime)
                        Divider()
                    }

                    VStack(alignment: .leading) {
                        Text("Response Time")
                        Slider(value: $viewModel.responseTime, in: 0.0...30.0) {
                            TextField(String(), value: $viewModel.responseTime, format: .number.precision(.fractionLength(2)), prompt: Text("Response Time (Second)"))
                        }
                    }
                }
                .padding(6)
            } label: {
                Label("Mock State", systemImage: "book.pages")
                    .labelStyle(.titleOnly)
                    .font(.title3)
            }
            .listRowSeparator(.hidden)

            GroupBox {
                VStack {
                    ForEach(viewModel.pluginMessages, id: \.self) { message in
                        Text(LocalizedStringKey(message))
                            .textSelection(.enabled)

                        Divider()
                            .padding(.vertical, 6)
                    }

                    Button("Load async Plugin") {
                        Task { @MainActor in
                            await viewModel.loadPluginMessage(shouldLoadAsync: true)
                        }
                    }

                    TipView(PluginsDocumentTip())
                }
                .padding(6)
            } label: {
                Label("Plugin", systemImage: "book.pages")
                    .labelStyle(.titleOnly)
                    .font(.title3)
            }
            .listRowSeparator(.hidden)
        }
        .inspectorColumnWidth(min: 300, ideal: 400)
        .task(id: viewModel.httpStatus) { viewModel.sync() }
        .task(id: viewModel.scenario) { viewModel.sync() }
        .task(id: viewModel.responseTime) { viewModel.sync() }
        .task(id: viewModel.url) { viewModel.sync() }
        .task { await viewModel.loadPluginMessage() }
    }
}

#Preview {
    MockDetailInspectorView(viewModel: .init(mockDomain: "Dev",
                                             mockModel: MockModel(metaData: .init(url: URL(string: "https://www.trendyol.com/aboutus")!,
                                                                                  method: "GET",
                                                                                  appendTime: .init(),
                                                                                  updateTime: .init(),
                                                                                  httpStatus: 200,
                                                                                  responseTime: 0.15,
                                                                                  scenario: "",
                                                                                  id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                                                                  requestHeader: "",
                                                                  responseHeader: "",
                                                                  requestBody: "",
                                                                  responseBody: ""),
                                             onChange: {}))
}

struct PluginsDocumentTip: Tip {
    var title: Text {
        Text("Plugins")
    }

    var message: Text? {
        Text("You can review the documentation to learn how to use plugins.")
    }

    var image: Image? {
        Image(systemName: "sparkles.rectangle.stack.fill")
    }

    var actions: [Action] {
        Action(title: "Open Documentations") {
            NSWorkspace.shared.open(URL(string: "https://trendyol.github.io/mockingstar/documentation/mockingstar/meetplugins")!)
        }
    }
}
