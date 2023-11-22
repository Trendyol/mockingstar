//
//  SwiftUIView.swift
//
//
//  Created by Yusuf Özgül on 2.11.2023.
//

import SwiftUI

struct PluginConfigItemView: View {
    @Binding var configUIModel: PluginConfigurationUIModel
    @State private var textValue: String = ""
    @State private var numberValue: Double = 0.0
    @State private var boolValue: Bool = false
    @State private var textArrayItem: [PluginConfigArrayItemModel<String>] = []
    @State private var numberArrayItem: [PluginConfigArrayItemModel<Double>] = []

    init(configUIModel: Binding<PluginConfigurationUIModel>) {
        self._configUIModel = configUIModel
    }

    var body: some View {
        Group {
            switch configUIModel.valueType {
            case .bool:
                Toggle(configUIModel.key, isOn: $boolValue)
                    .toggleStyle(.switch)
            case .text:
                TextField(configUIModel.key, text: $textValue, prompt: Text("Value"), axis: .vertical)
                    .lineLimit(1...10)
                    .textFieldStyle(.roundedBorder)
            case .number:
                TextField(configUIModel.key, value: $numberValue, format: .number, prompt: Text("Value"))
                    .lineLimit(1...10)
                    .textFieldStyle(.roundedBorder)
            case .textArray:
                LabeledContent(configUIModel.key) {
                    VStack {
                        ForEach($textArrayItem) { $text in
                            HStack {
                                TextField(text: $text.value, prompt: Text("Value"), axis: .vertical, label: EmptyView.init)
                                    .lineLimit(1...10)
                                    .textFieldStyle(.roundedBorder)

                                Button {
                                    withAnimation {
                                        textArrayItem.removeAll(where: { $0.id == $text.wrappedValue.id })
                                    }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }

                    Button {
                        withAnimation {
                            textArrayItem.append(.init(value: ""))
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.leading, 4)
                }
            case .numberArray:
                LabeledContent(configUIModel.key) {
                    VStack {
                        ForEach($numberArrayItem) { $number in
                            HStack {
                                TextField(value: $number.value, format: .number, prompt: Text("Value"), label: EmptyView.init)
                                    .lineLimit(1...10)
                                    .textFieldStyle(.roundedBorder)

                                Button {
                                    withAnimation {
                                        numberArrayItem.removeAll(where: { $0.id == $number.wrappedValue.id })
                                    }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }

                    Button {
                        withAnimation {
                            numberArrayItem.append(.init(value: 0.0))
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.leading, 4)
                }
            }
        }
        .onChange(of: textValue, sync)
        .onChange(of: numberValue, sync)
        .onChange(of: boolValue, sync)
        .onChange(of: textArrayItem, sync)
        .onChange(of: numberArrayItem, sync)
        .onAppear {
            switch configUIModel.value {
            case .text(let string): textValue = string
            case .number(let double): numberValue = double
            case .bool(let bool): boolValue = bool
            case .textArray(let array): textArrayItem = array.map(PluginConfigArrayItemModel.init)
            case .numberArray(let array): numberArrayItem = array.map(PluginConfigArrayItemModel.init)
            }
        }
    }

    private func sync() {
        configUIModel.value = switch configUIModel.valueType {
        case .text: .text(textValue)
        case .number: .number(numberValue)
        case .bool: .bool(boolValue)
        case .textArray: .textArray(textArrayItem.map(\.value))
        case .numberArray: .numberArray(numberArrayItem.map(\.value))
        }
    }
}

#Preview {
    Form {
        PluginConfigItemView(configUIModel: .constant(.init(key: "deneme",  valueType: .textArray)))

    }.padding()
}
