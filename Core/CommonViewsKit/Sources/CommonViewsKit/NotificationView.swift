//
//  SwiftUIView.swift
//  
//
//  Created by Yusuf Özgül on 8.11.2023.
//

import SwiftUI

public protocol NotificationManagerInterface {
    func show(title: String, color: Color, dismissTime: TimeInterval)
    func show(title: String, color: Color)
}

extension NotificationManagerInterface {
    public func show(title: String, color: Color) {
        show(title: title, color: color, dismissTime: 6)
    }
}

@Observable
public final class NotificationManager: NotificationManagerInterface {
    public static let shared = NotificationManager()
    public var notifications: [NotificationModel] = []

    private init() {}

    public func show(title: String, color: Color, dismissTime: TimeInterval = 6) {
        let alert: NotificationModel = .init(title: title, color: color)
        withAnimation {
            notifications.append(alert)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissTime) {
            withAnimation {
                self.notifications.removeAll(where: { $0.id == alert.id })
            }
        }
    }
}

public struct NotificationModel: Identifiable, Hashable {
    public var id: UUID = .init()
    public let title: String
    public let color: Color

    public init(title: String, color: Color) {
        self.title = title
        self.color = color
    }
}

public struct NotificationBannerView: View {
    @State private var onHover: Bool = false
    @Environment(NotificationManager.self) private var manager: NotificationManager
    private let notification: NotificationModel

    public init(notification: NotificationModel) {
        self.notification = notification
    }

    public var body: some View {
        Group {
            Text(notification.title)
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
        }
        .overlay {
            if onHover {
                VStack {
                    HStack {
                        Spacer()

                        Button {
                            manager.notifications.removeAll(where: { $0.id == notification.id })
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15)
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
        }
        .onHover { hovering in
            onHover = hovering
        }
        .background(Color.green)
        .clipShape(.rect(cornerRadius: 10))
    }
}
