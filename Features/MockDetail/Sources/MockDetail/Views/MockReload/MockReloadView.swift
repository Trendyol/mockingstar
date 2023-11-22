//
//  MockReloadView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 26.09.2023.
//

import CommonKit
import CommonViewsKit
import DiffEditor
import SwiftUI

enum MockReloadViewEditorSide: CaseIterable {
    case saved, both, new
    
    var title: String {
        switch self {
        case .saved: "Saved Mock"
        case .both: "Saved & New Mocks"
        case .new: "New Mock"
        }
    }
}

enum MockReloadViewEditorContentType: CaseIterable {
    case body, header
    
    var title: String {
        switch self {
        case .body: "Response Body"
        case .header: "Response Header"
        }
    }
}

enum MockReloadViewInspectorState: CaseIterable {
    case requestSummary, response
    var title: String {
        switch self {
        case .requestSummary: "Request Summary"
        case .response: "Response Details"
        }
    }
}

struct MockReloadView: View {
    @Bindable var viewModel: MockReloadViewModel
    @State private var shouldShowInspectorView: Bool = true
    @Environment(\.dismiss) var dismiss
    @AppStorage("SelectedShareStyle") var shareStyle: ShareStyle = .curl
    
    init(viewModel: MockReloadViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if viewModel.isReloadedMockReady {
                    DiffEditorCache.shared.editor
                } else {
                    ContentUnavailableView("Mock Reload", systemImage: "arrow.clockwise", description: Text("Send saved request to server and compare mock and new response"))
                }
            }
            .overlay {
                if viewModel.isMockReloadingProgress {
                    ProgressView()
                }
            }
            .inspector(isPresented: $shouldShowInspectorView) {
                VStack {
                    if viewModel.isReloadedMockReady {
                        Picker(selection: $viewModel.mockReloadSelectedInspectorState.animation(), content: {
                            ForEach(MockReloadViewInspectorState.allCases, id: \.self) { Text($0.title).tag($0) }
                        }, label: EmptyView.init)
                        .pickerStyle(.segmented)
                        .padding()
                    }
                    
                    switch viewModel.mockReloadSelectedInspectorState {
                    case .requestSummary:
                        Group {
                            if viewModel.didRequestUpdate {
                                Section {
                                    Picker(selection: $viewModel.showUpdatedRequest, content: {
                                        Text("Original Request").tag(false)
                                        Text("Updated Request").tag(true)
                                    }, label: EmptyView.init)
                                    .pickerStyle(.segmented)
                                    .padding([.horizontal, .top])
                                } footer: {
                                    Text("You have request reloader plugin and plugin modified original request")
                                        .padding(.horizontal)
                                }
                            }

                            RawRequestView(request: viewModel.showUpdatedRequest ? viewModel.updatedRequest() : viewModel.mockModel.asURLRequest)

                            Button {
                                viewModel.reloadMock()
                            } label: {
                                Text("Send Request")
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(Color.accentColor)
                                    .clipShape(.rect(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .padding()
                        }
                        .transition(.move(edge: .leading))
                        .animation(.linear, value: viewModel.mockReloadSelectedInspectorState)
                    case .response:
                        Form {
                            Section("Details") {
                                LabeledContent {
                                    Text("\(viewModel.mockModel.metaData.httpStatus)")
                                } label: {
                                    Text("Mock Status Code")
                                }
                                
                                if let statusCode = viewModel.reloadedMockResponse?.response.statusCode {
                                    LabeledContent {
                                        if viewModel.mockModel.metaData.httpStatus != statusCode {
                                            Text("\(statusCode)")
                                                .foregroundStyle(.red)
                                        } else {
                                            Text("\(statusCode)")
                                        }
                                    } label: {
                                        Text("Response Status Code")
                                    }
                                }
                                
                                LabeledContent {
                                    Text(DiffEditorCache.shared.content.diffCount)
                                } label: {
                                    Text("Diff Count")
                                }
                            }
                            
                            Section("Response Content") {
                                Picker(selection: $viewModel.mockReloadSelectedEditorContentType, content: {
                                    ForEach(MockReloadViewEditorContentType.allCases, id: \.self) { Text($0.title).tag($0) }
                                }, label: EmptyView.init)
                                .pickerStyle(.radioGroup)
                            }
                            
                            Section("Editor Data") {
                                Picker(selection: $viewModel.mockReloadSelectedEditorSide, content: {
                                    ForEach(MockReloadViewEditorSide.allCases, id: \.self) { Text($0.title).tag($0) }
                                }, label: EmptyView.init)
                                .pickerStyle(.radioGroup)
                            }
                            
                            VStack {
                                Button {
                                    viewModel.saveReloadedMock()
                                    dismiss()
                                } label: {
                                    Text("Save & Back")
                                        .frame(maxWidth: .infinity)
                                        .padding(8)
                                        .background(Color.accentColor)
                                        .clipShape(.rect(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.mockReloadSelectedEditorSide == .both)
                                
                                Button {
                                    viewModel.saveReloadedMock()
                                } label: {
                                    Text("Save")
                                }
                                .disabled(viewModel.mockReloadSelectedEditorSide == .both)
                                
                                if viewModel.mockReloadSelectedEditorSide == .both {
                                    Text("You should chose mock side or response side")
                                }
                            }
                        }
                        .transition(.move(edge: .trailing))
                        .animation(.linear, value: viewModel.mockReloadSelectedInspectorState)
                    }
                }
                .inspectorColumnWidth(min: geometry.size.width / 4, ideal: geometry.size.width / 3)
            }
            .toolbar {
                ToolbarItemGroup {
                    ActionSelectableButton(title: shareStyle.rawValue, icon: "square.and.arrow.up", backgroundColor: .green.opacity(0.7)) {
                        viewModel.shareButtonTapped(shareStyle: shareStyle)
                    } menuContent: {
                        Group {
                            ForEach(ShareStyle.allCases, id: \.self) { style in
                                Button(style.rawValue) {
                                    shareStyle = style
                                }
                            }
                        }
                    }
                }
                
                ToolbarItem {
                    Button {
                        shouldShowInspectorView = !shouldShowInspectorView
                    } label: {
                        Label("Hide Inspector", systemImage: "sidebar.trailing")
                    }
                }
            }
        }
        .background(.background)
        .navigationTitle("Reload \(viewModel.mockModel.metaData.url.path())")
        .modifier(ChangeConfirmationViewModifier(hasChange: .constant(false)) {})
    }
}

#Preview {
    NavigationStack {
        MockReloadView(viewModel: .init(mockModel: MockModel(metaData: .init(url: URL(string: "https://www.trendyol.com/aboutus")!,
                                                                             method: "GET",
                                                                             appendTime: .init(),
                                                                             updateTime: .init(),
                                                                             httpStatus: 200,
                                                                             responseTime: 0.15,
                                                                             scenario: "",
                                                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                                                             requestHeader: "",
                                                             responseHeader: "",
                                                             requestBody: .init(""),
                                                             responseBody: .init("")), 
                                        mockDomain: "Dev"))
    }
}
