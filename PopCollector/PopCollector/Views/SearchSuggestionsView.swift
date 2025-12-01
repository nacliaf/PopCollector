//
//  SearchSuggestionsView.swift
//  PopCollector
//
//  Search suggestions and recent searches
//

import SwiftUI

struct SearchSuggestionsView: View {
    @Binding var searchText: String
    let allPops: [PopItem]
    @AppStorage("recentSearches") private var recentSearchesData: Data = Data()
    
    private var recentSearches: [String] {
        if let decoded = try? JSONDecoder().decode([String].self, from: recentSearchesData) {
            return Array(decoded.prefix(5))
        }
        return []
    }
    
    private var popularSeries: [String] {
        Array(Set(allPops.map { $0.series }.filter { !$0.isEmpty }))
            .sorted()
            .prefix(5)
            .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Searches")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ForEach(recentSearches, id: \.self) { search in
                        Button {
                            searchText = search
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                Text(search)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            
            if !popularSeries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Popular Series")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ForEach(popularSeries, id: \.self) { series in
                        Button {
                            searchText = series
                        } label: {
                            HStack {
                                Image(systemName: "tag")
                                    .foregroundColor(.secondary)
                                Text(series)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

