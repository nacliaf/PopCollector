//
//  HomeTabView.swift
//  PopCollector
//
//  Home screen with total collection value and stats
//

import SwiftUI
import SwiftData

struct HomeTabView: View {
    @Query private var allPops: [PopItem]
    @Query private var folders: [PopFolder]
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingOnlineSearch = false
    @State private var onlineSearchQuery = ""
    @State private var onlineSearchResults: [PopLookupResult] = []
    @State private var isSearching = false
    
    private var totalValue: Double {
        allPops.reduce(0) { $0 + $1.displayValue }
    }
    
    private var totalCount: Int {
        allPops.reduce(0) { $0 + $1.quantity }
    }
    
    private var uniqueCount: Int {
        allPops.count
    }
    
    private var uniqueFolders: Int {
        Set(allPops.compactMap { $0.folder?.name }).count
    }
    
    // MARK: - Recently Added Shelf
    
    private var recentPops: [PopItem] {
        Array(allPops
            .sorted { $0.lastUpdated > $1.lastUpdated }
            .prefix(8))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Total Value Display
                    VStack(spacing: 10) {
                        Text("$\(totalValue, specifier: "%.0f")")
                            .font(.system(size: 80, weight: .bold, design: .rounded))
                            .foregroundColor(totalValue > 10000 ? .orange : .green)
                            .contentTransition(.numericText())
                            .animation(.spring, value: totalValue)
                        
                        Text("Total Collection Value")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Recently Added Shelf
                    if !recentPops.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recently Added")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 20) {
                                    ForEach(recentPops) { pop in
                                        VStack(spacing: 8) {
                                            AsyncImage(url: URL(string: pop.imageURL)) { phase in
                                                switch phase {
                                                case .empty:
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .overlay {
                                                            ProgressView()
                                                        }
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFit()
                                                case .failure:
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .overlay {
                                                            Image(systemName: "photo")
                                                                .foregroundColor(.gray)
                                                        }
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                            .frame(width: 110, height: 110)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                            
                                            Text(pop.name)
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                                .frame(width: 110)
                                            
                                            if pop.quantity > 1 {
                                                Text("×\(pop.quantity)")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 4)
                                                    .background(Color.blue.opacity(0.2))
                                                    .cornerRadius(8)
                                            }
                                            
                                            if pop.value > 0 {
                                                Text("$\(pop.displayValue, specifier: "%.0f")")
                                                    .font(.caption2)
                                                    .foregroundColor(pop.isSigned ? .purple : .green)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                        .padding(4)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Stats Cards
                    HStack(spacing: 16) {
                        StatCard(
                            title: "Total Pops",
                            value: "\(totalCount)",
                            icon: "figure",
                            color: .blue
                        )
                        
                        StatCard(
                            title: "Unique Pops",
                            value: "\(uniqueCount)",
                            icon: "square.stack.3d.up",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        StatCard(
                            title: "Bins",
                            value: "\(uniqueFolders)",
                            icon: "tray.full",
                            color: .orange
                        )
                        
                        StatCard(
                            title: "Avg Value",
                            value: uniqueCount > 0 ? "$\(Int(totalValue / Double(uniqueCount)))" : "$0",
                            icon: "dollarsign.circle",
                            color: .green
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("PopCollector")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingOnlineSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingOnlineSearch) {
                OnlineSearchSheet(
                    searchQuery: $onlineSearchQuery,
                    searchResults: $onlineSearchResults,
                    isSearching: $isSearching,
                    folders: folders
                )
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

#Preview {
    HomeTabView()
        .modelContainer(for: [PopItem.self, PopFolder.self], inMemory: true)
}

