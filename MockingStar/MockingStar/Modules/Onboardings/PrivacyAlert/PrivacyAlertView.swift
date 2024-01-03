//
//  PrivacyAlertView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 3.01.2024.
//

import SwiftUI

struct PrivacyAlertView: View {
    var continueButtonTapped: () -> Void

    var body: some View {
        GeometryReader { geometryReader in
            ScrollView {
                VStack(alignment: .center) {
                    Spacer()
                    Image("mainAppIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 180, alignment: .center)
                        .accessibility(hidden: true)

                    Spacer(minLength: 30)
                    HStack {
                        Spacer()

                        VStack(alignment: .center) {
                            Text("For your privacy")
                                .font(.title)
                                .padding()

                            Text("SENSITIVE_INFO_ALERT")
                                .font(.title3)
                                .padding(.horizontal)
                                .frame(maxWidth: geometryReader.size.width / 2)
                        }

                        Spacer()
                    }

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
}

#Preview {
    PrivacyAlertView(continueButtonTapped: {})
}
