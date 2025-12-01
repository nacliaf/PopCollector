//
//  StatsTabView.swift
//  PopCollector
//
//  Statistics and insights about your collection
//

import SwiftUI
import SwiftData

struct StatsTabView: View {
    @Query private var pops: [PopItem]
    
    private var mostValuable: PopItem? {
        pops.max(by: { $0.displayValue < $1.displayValue })
    }
    
    private var biggestDrop: PopItem? {
        pops.filter { $0.trend < 0 }
            .max(by: { abs($0.trend) < abs($1.trend) })
    }
    
    private var totalValue: Double {
        pops.reduce(0) { $0 + $1.displayValue }
    }
    
    private var avgValue: Double {
        let uniquePops = pops.count
        return uniquePops > 0 ? totalValue / Double(uniquePops) : 0
    }
    
    private var seriesBreakdown: [(String, Int)] {
        Dictionary(grouping: pops, by: { $0.series.isEmpty ? "Unknown" : $0.series })
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { ($0.0, $0.1) }
    }
    
    private var signedCount: Int {
        pops.filter { $0.isSigned }.count
    }
    
    private var vaultedCount: Int {
        pops.filter { $0.isVaulted }.count
    }
    
    private var mostValuableSeries: String {
        let seriesValues = Dictionary(grouping: pops, by: { $0.series.isEmpty ? "Unknown" : $0.series })
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.displayValue }) }
            .sorted { $0.1 > $1.1 }
            .first
        
        return seriesValues?.0 ?? "None"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Overview Cards
                    HStack(spacing: 16) {
                        StatCard(title: "Total Value", value: "$\(Int(totalValue))", icon: "dollarsign.circle.fill", color: .green)
                        StatCard(title: "Total Pops", value: "\(pops.reduce(0) { $0 + $1.quantity })", icon: "figure", color: .blue)
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        StatCard(title: "Unique Pops", value: "\(pops.count)", icon: "square.stack.3d.up", color: .purple)
                        StatCard(title: "Avg Value", value: "$\(Int(avgValue))", icon: "chart.bar.fill", color: .orange)
                    }
                    .padding(.horizontal)
                    
                    // Detailed Stats
                    List {
                        if let pop = mostValuable {
                            StatRow(
                                title: "Most Valuable",
                                pop: pop,
                                value: String(format: "$%.0f", pop.displayValue)
                            )
                        }
                        
                        if let pop = biggestDrop, pop.trend < 0 {
                            StatRow(
                                title: "Biggest Drop",
                                pop: pop,
                                subtitle: String(format: "↓ %.1f%%", abs(pop.trend)),
                                value: String(format: "$%.2f", pop.value)
                            )
                        }
                        
                        Section("Collection Breakdown") {
                            StatRow(
                                title: "Signed Pops",
                                value: "\(signedCount)"
                            )
                            
                            StatRow(
                                title: "Vaulted Pops",
                                value: "\(vaultedCount)"
                            )
                            
                            StatRow(
                                title: "Most Valuable Series",
                                value: mostValuableSeries
                            )
                        }
                        
                        if !seriesBreakdown.isEmpty {
                            Section("Top Series") {
                                ForEach(seriesBreakdown, id: \.0) { series, count in
                                    StatRow(
                                        title: series,
                                        value: "\(count) Pops"
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Stats")
        }
    }
}

struct StatRow: View {
    let title: String
    var pop: PopItem?
    var subtitle: String?
    var value: String?
    
    var body: some View {
        HStack(spacing: 12) {
            if let pop = pop {
                AsyncImage(url: URL(string: pop.imageURL)) { phase in
                    switch phase {
                    case .empty:
                        Color.gray.opacity(0.3)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        Color.gray.opacity(0.3)
                    @unknown default:
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pop.name)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            } else {
                Text(title)
                    .font(.headline)
            }
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            } else if let pop = pop {
                Text(String(format: "$%.0f", pop.value))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    StatsTabView()
        .modelContainer(for: [PopItem.self, PopFolder.self], inMemory: true)
}

