//
//  WelcomeView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import SwiftUI

struct WelcomeView: View {
    var continueButtonTapped: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .center) {
                Spacer()
                TitleView()
                InformationContainerView()
                Spacer(minLength: 30)

                Button(action: {
                    continueButtonTapped()
                }) {
                    Text("Continue")
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
            }
        }
    }
}

#Preview {
    WelcomeView() {}
}

struct InformationDetailView: View {
    var title: String
    var subTitle: String
    var imageName: String

    var body: some View {
        HStack(alignment: .center) {
            Image(systemName: imageName)
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
                .padding()
                .accessibility(hidden: true)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .accessibility(addTraits: .isHeader)

                Text(subTitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct InformationContainerView: View {
    var body: some View {
        VStack(alignment: .leading) {
            InformationDetailView(title: "Easy",
                                  subTitle: "Easily mock requests and test different cases with scenarios.",
                                  imageName: "figure.run.square.stack")

            InformationDetailView(title: "Powerful",
                                  subTitle: "Modify intercepted requests to test different edge cases, allowing you to assess your application's performance under different conditions.",
                                  imageName: "wand.and.stars")

            InformationDetailView(title: "And More",
                                  subTitle: "Integrate Mocking Star into your UI tests, creating a reliable and controlled testing environment to validate your application's functionality.",
                                  imageName: "pencil.and.outline")
        }
        .padding(.horizontal)
    }
}

struct TitleView: View {
    var body: some View {
        VStack {
            Image("mainAppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 180, alignment: .center)
                .accessibility(hidden: true)

            Text("Welcome to")
                .font(.largeTitle)

            Text("MockingStar")
                .font(.title)
                .foregroundStyle(Color.accentColor)
        }
    }
}

