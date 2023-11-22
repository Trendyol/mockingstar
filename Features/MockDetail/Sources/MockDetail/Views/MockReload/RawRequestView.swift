//
//  RawRequestView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 26.09.2023.
//

import SwiftUI

struct RawRequestView: View {
    var request: URLRequest

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 6) {
                Text(request.httpMethod ?? "")
                    .foregroundColor(.green)
                    .fontWeight(.bold)
                +
                Text(" ")
                +
                Text((request.url?.path ?? ""))
                    .fontWeight(.semibold) +
                Text((request.url?.query ?? "").isEmpty ? "" : "?\((request.url?.query ?? ""))")
                    .fontWeight(.regular)

                ForEach(request.httpHeadersModel) { header in
                    Text(header.key)
                        .foregroundColor(.blue.opacity(0.8))
                    +
                    Text(": ")
                    +
                    Text(header.value)
                }

                Text("Host")
                    .foregroundColor(.blue.opacity(0.8))
                +
                Text(": ")
                +
                Text(request.url?.host ?? "")

                Text(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")
                    .opacity(0.8)
                    .multilineTextAlignment(.leading)
            }
            .textSelection(.enabled)
        }
        .contentMargins(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RawRequestView_Previews: PreviewProvider {
    static var previews: some View {
        var request = URLRequest(url: URL(string: "https://www.trendyol.com/aboutus")!)

        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("17.0", forHTTPHeaderField: "OSVersion")
        request.addValue("31C65757-BA8F-45AD-ADAE-F3A32DB5B7C4", forHTTPHeaderField: "DeviceId")
        request.addValue("iphone", forHTTPHeaderField: "Platform")
        request.addValue("tr-TR", forHTTPHeaderField: "Accept-Language")

        request.httpBody = """
{
    "platform": "IOS",
    "project": "iOS",
    "value": "true",
    "tag": "",
    "enable": true
}
""".data(using: .utf8)

        return RawRequestView(request: request)
            .frame(width: 500, height: 500)
    }
}

private struct HeaderModel: Hashable, Identifiable, Encodable {
    let id = UUID()
    let key: String
    let value: String

    enum CodingKeys: CodingKey {
        case key
        case value
    }
}

private extension URLRequest {
    var httpHeadersModel: [HeaderModel] {
        allHTTPHeaderFields?.map({ .init(key: $0.key, value: $0.value)}) ?? []
    }
}
