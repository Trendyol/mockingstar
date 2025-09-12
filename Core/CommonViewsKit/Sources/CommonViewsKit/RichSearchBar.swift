//
//  RichSearchBar.swift
//  CommonViewsKit
//
//  Created by Yusuf Özgül on 11.09.2025.
//

import CommonKit
import SwiftUI

public struct RichSearchBar: View {
    private let filterTypeDisabled: Bool
    @Binding private var filterType: FilterType
    @Binding private var filterStyle: FilterStyle
    @Binding private var searchTerm: String
    @Binding private var placeHolderCount: Int
    @Binding private var isSearchActive: Bool

    public init(filterType: Binding<FilterType>? = nil,
                filterStyle: Binding<FilterStyle>,
                searchTerm: Binding<String>,
                placeHolderCount: Binding<Int>,
                isSearchActive: Binding<Bool>) {
        self.filterTypeDisabled = filterType == nil
        self._filterType = filterType ?? .constant(.all)
        self._filterStyle = filterStyle
        self._searchTerm = searchTerm
        self._placeHolderCount = placeHolderCount
        self._isSearchActive = isSearchActive
    }

    public var body: some View {
        HStack(spacing: .zero) {
            VStack(spacing: .zero) {
                Menu {
                    ForEach(FilterType.allCases, id: \.self) { type in
                        Button {
                            filterType = type
                        } label: {
                            Text(type.title)
                        }
                    }
                } label: {
                    Text(filterType.title)
                        .font(.caption2)
                }
                .disabled(filterTypeDisabled)

                Menu {
                    ForEach(FilterStyle.allCases, id: \.self) { type in
                        Button {
                            filterStyle = type
                        } label: {
                            Text(type.title)
                        }
                    }
                } label: {
                    Text(filterStyle.title)
                        .font(.caption2)
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)
            .padding(.vertical, 2)

            Divider()
                .padding(.trailing, 6)

            CustomSearchbar(text: $searchTerm, isSearchActive: $isSearchActive, placeholderCount: $placeHolderCount)
                .frame(width: 200)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(searchTerm.isEmpty ? Color.secondary : Color.accentColor, lineWidth: 1)
        )
    }
}
