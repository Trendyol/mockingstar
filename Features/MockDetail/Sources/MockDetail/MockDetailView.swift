//
//  MockDetailView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 20.09.2023.
//

import CommonKit
import CommonViewsKit
import JSONEditor
import MockingStarCore
import SwiftUI
import TipKit

public struct MockDetailView: View {
    @Bindable private var viewModel: MockDetailViewModel
    @State private var shouldShowInspectorView: Bool = true
    @State private var shouldShowMockReloadView: Bool = false
    @AppStorage("SelectedShareStyle") private var shareStyle: ShareStyle = .curl
    @Environment(NavigationStore.self) private var navigationStore: NavigationStore
    @Environment(MockDomainDiscover.self) private var domainDiscover: MockDomainDiscover
    private let inspectorViewModel: MockDetailInspectorViewModel

    public init(viewModel: MockDetailViewModel) {
        self.viewModel = viewModel
        inspectorViewModel = .init(mockDomain: viewModel.mockDomain, mockModel: viewModel.mockModel) { viewModel.checkUnsavedChanges() }
    }

    public var body: some View {
        VStack(spacing: .zero) {
            MockDetailEditorTypeButton(selectedEditorType: $viewModel.selectedEditorType)
            JsonEditorCache.shared.editor
        }
        .navigationTitle(viewModel.mockModel.metaData.url.path())
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                if viewModel.jsonValidationMessage != nil {
                    Label("JSON Validation Error", systemImage: "text.badge.xmark")
                        .foregroundStyle(Color.red)
                        .help(viewModel.jsonValidationMessage ?? "")
                }
            }

            ToolbarItemGroup {
                ToolBarButton(title: "Reload Mock", icon: "arrow.clockwise", backgroundColor: .gray) {
                    shouldShowMockReloadView = true
                }
                .keyboardShortcut("r")

                ToolBarButton(title: "Delete", icon: "trash", backgroundColor: .red) {
                    viewModel.shouldShowDeleteConfirmationAlert = true
                }

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

                ToolBarButton(title: "Save", icon: "tray.and.arrow.down", backgroundColor: .blue) {
                    viewModel.saveChanges()
                }
                .keyboardShortcut("s")
            }

            ToolbarItem {
                ControlGroup {
                    Button {
                        viewModel.openInFinder()
                    } label: {
                        Label("Open in Finder", systemImage: "text.viewfinder")
                    }

                    Menu("Duplicate...") {
                        Button {
                            Task {
                                await viewModel.newMock(mockDomain: viewModel.mockDomain, shouldMove: false)
                            }
                        } label: {
                            Label("Duplicate Mock", systemImage: "doc.on.doc.fill")
                        }
                    }

                    Menu("Copy to...") {
                        Button("Clipboard") {
                            viewModel.shareButtonTapped(shareStyle: .file)
                        }

                        Divider()

                        ForEach(domainDiscover.domains.filter { $0 != viewModel.mockDomain }, id: \.self) { mockDomain in
                            Button(mockDomain) {
                                Task {
                                    await viewModel.newMock(mockDomain: mockDomain, shouldMove: false)
                                }
                            }
                        }
                    }

                    Menu("Move to...") {
                        ForEach(domainDiscover.domains.filter { $0 != viewModel.mockDomain }, id: \.self) { mockDomain in
                            Button(mockDomain) {
                                Task {
                                    await viewModel.newMock(mockDomain: mockDomain, shouldMove: true)
                                }
                            }
                        }
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle.fill")
                }
                .controlGroupStyle(.compactMenu)
            }

            ToolbarItem {
                Button {
                    shouldShowInspectorView = !shouldShowInspectorView
                } label: {
                    Label("Hide Inspector", systemImage: "sidebar.trailing")
                }
            }
        }
        .confirmationDialog("Mock Will be Deleted, Are you sure", isPresented: $viewModel.shouldShowDeleteConfirmationAlert) {
            Button("Delete", role: .destructive, action: { viewModel.removeMock() })
            Button("Cancel", role: .cancel, action: { })
        }
        .alert(viewModel.alertMessage, isPresented: $viewModel.shouldShowAlert, actions: {
            if let action = viewModel.alertAction {
                Button(viewModel.alertActionTitle) { action() }
            }
            Button("Cancel", role: .cancel, action: { })
        })
        .alert("Warning", isPresented: $viewModel.shouldShowFilePathErrorAlert, actions: {
            Button("Fix File Path", role: .destructive, action: { viewModel.fixFilePath() })
                .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel, action: { })
        }, message: {
            Text("The file location is not where it should be, which causes the mock to not be used as a response. You can move this mock to its required location by tap Fix.")
        })
        .inspector(isPresented: $shouldShowInspectorView) {
            MockDetailInspectorView(viewModel: inspectorViewModel)
        }
        .navigationDestination(isPresented: $shouldShowMockReloadView) {
            MockReloadView(viewModel: .init(mockModel: viewModel.mockModel, mockDomain: viewModel.mockDomain))
        }
        .onChange(of: viewModel.shouldDismissView) { dismissIfNeeded() }
        .onChange(of: viewModel.shouldShowAlert) { dismissIfNeeded() }
        .task(id: viewModel.mockModel.responseBody) { viewModel.jsonEditorModelTypeChanged() }
        .task(id: viewModel.mockModel.responseHeader) { viewModel.jsonEditorModelTypeChanged() }
        .task(id: viewModel.mockModel.metaData) { viewModel.checkUnsavedChanges() }
        .task { viewModel.checkFilePath() }
        .background(.background)
        .modifier(ChangeConfirmationViewModifier(hasChange: $viewModel.shouldShowUnsavedIndicator) {
            viewModel.saveChanges()
        })
        .onReceive(NotificationCenter.default.publisher(for: .removeMock)) { _ in
            viewModel.shouldShowDeleteConfirmationAlert = true
        }
    }

    func dismissIfNeeded() {
        guard viewModel.shouldDismissView && !viewModel.shouldShowAlert else { return }
        withAnimation { navigationStore.pop() }
    }
}

#Preview {
    NavigationStack {
        MockDetailView(viewModel: .init(mockModel: MockModel(metaData: .init(url: URL(string: "https://www.trendyol.com/aboutus")!,
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
                                        mockDomain: ""))
    }
}
