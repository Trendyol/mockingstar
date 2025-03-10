//
//  InitializeAppOnboardingView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 21.09.2023.
//

import SwiftUI
import CommonKit

struct InitializeAppOnboardingView: View {
    private let logger = Logger(category: "InitializeAppOnboardingView")
    private let onboardingDone: () -> Void
    private let fileStructureHelper: FileStructureHelperInterface = FileStructureHelper()
    @State private var onboardingMessage: String = "loading"
    @State private var onboardingFailed: Bool = false
    @AppStorage("isOnboardingDone") private var isOnboardingDone: Bool = false
    @UserDefaultStorage("mockFolderFileBookMark") var mockFolderFileBookMark: Data? = nil
    @SceneStorage("mockDomain") private var mockDomain: String = ""

    init(onboardingDone: @escaping () -> Void) {
        self.onboardingDone = onboardingDone
    }

    var body: some View {
        VStack {
            Spacer()

            if onboardingFailed {
                Button {
                    isOnboardingDone = false
                } label: {
                    Text("Reset Mocking Star")
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding()
                        .padding(.horizontal, 40)
                        .background(Color.accentColor)
                        .clipShape(.rect(cornerRadius: 15))
                        .padding(.bottom)
                }
                .padding(.horizontal)
                .buttonStyle(.plain)

                Text("Mocking Star encountered a problem while starting. You can try resetting the app to fix the problem.")
                    .font(.callout)
                    .foregroundStyle(.red)
            } else {
                ProgressView().progressViewStyle(.circular)
            }

            Spacer()

            Text(onboardingMessage)
                .padding()
                .textSelection(.enabled)
        }
        .task(priority: .userInitiated) { await initiate() }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial.opacity(0.8))
    }

    private func updateMessage(text: String) async {
        logger.debug(text)
        DispatchQueue.main.async {
            self.onboardingMessage = text
        }
    }

    private func initiate() async {
        await updateMessage(text: "Initialize File Accessing...")
        try? await Task.sleep(for: .seconds(0.2))
        do {
            guard let fileBookMark = mockFolderFileBookMark else {
                await updateMessage(text: "File Access Failed, file bookmark not found")
                onboardingFailed = true
                return
            }

            try FilePermissionHelper(fileBookMark: fileBookMark).startAccessingSecurityScopedResource()
        } catch {
            onboardingFailed = true
            return await updateMessage(text: "File Access ERROR: \(error)")
        }

        await updateMessage(text: "Checking File Structure...")
        try? await Task.sleep(for: .seconds(0.2))

        if !fileStructureHelper.fileStructureCheck() {
            await updateMessage(text: "File Structure has problems, trying to fix...")
            try? await Task.sleep(for: .seconds(0.2))
            do {
                try fileStructureHelper.repairFileStructure()
            } catch {
                await updateMessage(text: "File Structure Repair ERROR: \(error)")
                try? await Task.sleep(for: .seconds(0.2))
                onboardingFailed = true
                return
            }
        }

        if !fileStructureHelper.domainFileStructureCheck(mockDomain: mockDomain) {
            await updateMessage(text: "File Structure has problems, trying to fix...")
            try? await Task.sleep(for: .seconds(0.2))
            do {
                try fileStructureHelper.repairDomainFileStructure(mockDomain: mockDomain)
            } catch {
                await updateMessage(text: "File Structure Repair ERROR: \(error)")
                try? await Task.sleep(for: .seconds(0.2))
                onboardingFailed = true
                return
            }
        }

        await updateMessage(text: "Ready")
        try? await Task.sleep(for: .seconds(0.2))

        onboardingDone()
    }
}

#Preview {
    InitializeAppOnboardingView { }
}
