//
//  QuickDemo.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 6.02.2024.
//

import SwiftUI
import TipKit

struct QuickDemo: View {
    @State private var result = """

                    1- Tap Send Request button
                    2- Return Mocking Star app window
                    3- Find and edit mock
                    4- Return playground and tap Send Request button and see changes
                    
                    """

    var body: some View {
        ScrollView {
            TipView(QuickDemoUsageTip())
                .padding(.horizontal)

            Text("URL: https://api.github.com/search/repositories?q=Apple")

            Button("Send Request") {
                Task {
                    var request = URLRequest(url: URL(string: "http://localhost:8008/mock")!)
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpMethod = "POST"
                    request.httpBody = """
{
    "url": "https://api.github.com/search/repositories?q=Apple",
    "method": "GET",
    "header": {
        "Platform": "iphone",
        "OSVersion": "17.0.1",
        "Content-Type": "application/json"
    }
}
""".data(using: .utf8)

                    let (data, _) = try await URLSession.shared.data(for: request)
                    result = String(data: data, encoding: .utf8) ?? ""
                }
            }

            TextEditor(text: .constant(result))
                .padding(.top)
        }
    }
}

#Preview {
    QuickDemo()
}

struct QuickDemoUsageTip: Tip {
    var title: Text {
        Text("Mocking Star Playground")
    }

    var message: Text? {
        Text("""
1- Tap Send Request button
2- Return Mocking Star app window
3- Find and edit mock
4- Return playground and tap Send Request button and see changes
""")
    }

    var image: Image? {
        Image(systemName: "dot.scope.laptopcomputer")
    }
}
