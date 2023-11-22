//
//  DiagnosticViewModel.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import Foundation
import SwiftUI
import CommonKit

@Observable
final class DiagnosticViewModel {
    var diagnosticItems: [DiagnosticModel] = []
    @ObservationIgnored @UserDefaultStorage("httpServerPort") var httpServerPort: UInt16 = 8008
    @ObservationIgnored @UserDefaultStorage("mockFolderFilePath") var mockFolderFilePath: String = "/MockServer"

    init() {
        startDiagnostic()
    }

    func startDiagnostic() {
        diagnosticItems = [
            .init(type: .server, icon: "server.rack", name: "Server"),
            .init(type: .port, icon: "numbersign", name: "Port"),
            .init(type: .fileAccess, icon: "folder.badge.questionmark", name: "File Access"),
            .init(type: .fileWrite, icon: "square.and.pencil", name: "File Write"),
        ]

        Task {
            try await Task.sleep(for: .seconds(1))
            await checkServer()
            await checkPortUsage()
            await checkFileAccess()
            await checkFileWrite()
        }
    }

    @MainActor
    func checkServer() async {
        guard let index = diagnosticItems.firstIndex(where: { $0.type == .server }) else { return }
        diagnosticItems[index].isLoading = true

        guard let checkURL = URL(string: "http://localhost:\(httpServerPort)/hello") else {
            diagnosticItems[index].isLoading = false
            diagnosticItems[index].isSuccess = false
            diagnosticItems[index].errorMessage = "Server check url creation error"
            return
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: checkURL)
            if (response as? HTTPURLResponse)?.statusCode == 418 {
                diagnosticItems[index].isLoading = false
                diagnosticItems[index].isSuccess = true
            } else {
                diagnosticItems[index].isLoading = false
                diagnosticItems[index].isSuccess = false
                diagnosticItems[index].errorMessage = "Server not accessible"
            }
        } catch {
            diagnosticItems[index].isLoading = false
            diagnosticItems[index].isSuccess = false
            diagnosticItems[index].errorMessage = "Server access failed: \(error)"
        }
    }

    @MainActor
    private func checkPortUsage() async {
        guard let index = diagnosticItems.firstIndex(where: { $0.type == .port }) else { return }
        diagnosticItems[index].isLoading = true

        guard !(diagnosticItems.first(where: { $0.type == .server })?.isSuccess ?? false) else { 
            diagnosticItems[index].isLoading = false
            diagnosticItems[index].isSuccess = true
            return
        }

        if isPortOpen(port: in_port_t(httpServerPort)) {
            diagnosticItems[index].isLoading = false
            diagnosticItems[index].isSuccess = false
            diagnosticItems[index].errorMessage = "Port using another application"
        } else {
            diagnosticItems[index].isLoading = false
            diagnosticItems[index].isSuccess = true
        }
    }

    @MainActor
    private func checkFileAccess() {
        guard let index = diagnosticItems.firstIndex(where: { $0.type == .fileAccess }) else { return }
        diagnosticItems[index].isLoading = true

        let url = URL(filePath: mockFolderFilePath)

        do {
            if try url.checkResourceIsReachable() {
                diagnosticItems[index].isLoading = false
                diagnosticItems[index].isSuccess = true
            } else {
                diagnosticItems[index].isLoading = false
                diagnosticItems[index].isSuccess = false
                diagnosticItems[index].errorMessage = "Folder not accessible"
            }
        } catch {
            diagnosticItems[index].isLoading = false
            diagnosticItems[index].isSuccess = false
            diagnosticItems[index].errorMessage = "Folder not accessible, error: \(error)"
        }
    }

    @MainActor
    private func checkFileWrite() {
        guard let index = diagnosticItems.firstIndex(where: { $0.type == .fileWrite }) else { return }
        diagnosticItems[index].isLoading = true

        if FileManager.default.isWritableFile(atPath: mockFolderFilePath) {
            diagnosticItems[index].isLoading = false
            diagnosticItems[index].isSuccess = true
        } else {
            diagnosticItems[index].isLoading = false
            diagnosticItems[index].isSuccess = false
            diagnosticItems[index].errorMessage = "Folder not writable"
        }
    }

    private func isPortOpen(port: in_port_t) -> Bool {
        let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        if socketFileDescriptor == -1 {
            return false
        }

        var addr = sockaddr_in()
        let sizeOfSockkAddr = MemoryLayout<sockaddr_in>.size
        addr.sin_len = __uint8_t(sizeOfSockkAddr)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = Int(OSHostByteOrder()) == OSLittleEndian ? _OSSwapInt16(port) : port
        addr.sin_addr = in_addr(s_addr: inet_addr("0.0.0.0"))
        addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        var bind_addr = sockaddr()
        memcpy(&bind_addr, &addr, Int(sizeOfSockkAddr))

        if Darwin.bind(socketFileDescriptor, &bind_addr, socklen_t(sizeOfSockkAddr)) == -1 {
            return false
        }
        let isOpen = listen(socketFileDescriptor, SOMAXCONN ) != -1
        Darwin.close(socketFileDescriptor)
        return isOpen
    }
}

struct DiagnosticModel: Hashable {
    let type: CheckType
    let icon: String
    let name: String
    var errorMessage: String
    var isLoading: Bool
    var isSuccess: Bool

    init(type: CheckType,
         icon: String,
         name: String,
         errorMessage: String = "",
         isLoading: Bool = false,
         isSuccess: Bool = false) {
        self.type = type
        self.icon = icon
        self.name = name
        self.errorMessage = errorMessage
        self.isLoading = isLoading
        self.isSuccess = isSuccess
    }

    enum CheckType {
        case server, port, fileAccess, fileWrite
    }
}
