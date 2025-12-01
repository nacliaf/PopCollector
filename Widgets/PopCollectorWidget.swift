//
//  PopCollectorWidget.swift
//  PopCollector
//
//  Widget extension with multiple sizes and customizable options
//

import WidgetKit
import SwiftUI
import Intents

struct PopCollectorWidget: Widget {
    let kind: String = "PopCollectorWidget"
    
    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: WidgetTypeIntent.self, provider: PopCollectorTimelineProvider()) { entry in
            PopCollectorWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("PopCollector")
        .description("Track your Funko Pop collection value and stats")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct PopCollectorWidgetEntry: TimelineEntry {
    let date: Date
    let totalValue: Double
    let totalCount: Int
    let uniqueCount: Int
    let mostValuable: PopData?
    let recentPops: [PopData]
    let widgetType: WidgetType
}

struct PopData {
    let name: String
    let value: Double
    let imageURL: String
}

struct PopCollectorTimelineProvider: IntentTimelineProvider {
    typealias Entry = PopCollectorWidgetEntry
    typealias Intent = WidgetTypeIntent
    
    func placeholder(in context: Context) -> PopCollectorWidgetEntry {
        PopCollectorWidgetEntry(
            date: Date(),
            totalValue: 12500.0,
            totalCount: 45,
            uniqueCount: 32,
            mostValuable: PopData(name: "Spider-Man", value: 250.0, imageURL: ""),
            recentPops: [],
            widgetType: .totalValue
        )
    }
    
    func getSnapshot(for configuration: WidgetTypeIntent, in context: Context, completion: @escaping (PopCollectorWidgetEntry) -> Void) {
        let entry = loadWidgetData(for: configuration.widgetType)
        completion(entry)
    }
    
    func getTimeline(for configuration: WidgetTypeIntent, in context: Context, completion: @escaping (Timeline<PopCollectorWidgetEntry>) -> Void) {
        let entry = loadWidgetData(for: configuration.widgetType)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
    
    private func loadWidgetData(for type: WidgetType?) -> PopCollectorWidgetEntry {
        let widgetType = type ?? .totalValue
        
        // Load from shared App Group container
        if let widgetData = WidgetDataManager.shared.loadWidgetData() {
            return PopCollectorWidgetEntry(
                date: Date(),
                totalValue: widgetData.totalValue,
                totalCount: widgetData.totalCount,
                uniqueCount: widgetData.uniqueCount,
                mostValuable: widgetData.mostValuable,
                recentPops: widgetData.recentPops,
                widgetType: widgetType
            )
        }
        
        // Fallback to placeholder if no data
        return PopCollectorWidgetEntry(
            date: Date(),
            totalValue: 0.0,
            totalCount: 0,
            uniqueCount: 0,
            mostValuable: nil,
            recentPops: [],
            widgetType: widgetType
        )
    }
}

struct PopCollectorWidgetEntryView: View {
    var entry: PopCollectorWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget (Total Value)

struct SmallWidgetView: View {
    let entry: PopCollectorWidgetEntry
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "figure.pop")
                    .font(.title2)
                    .foregroundColor(.blue)
                Spacer()
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Collection Value")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("$\(entry.totalValue, specifier: "%.0f")")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(entry.totalValue > 10000 ? .orange : .green)
            }
            
            Spacer()
            
            HStack {
                Text("\(entry.totalCount) Pops")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Medium Widget (Value + Stats)

struct MediumWidgetView: View {
    let entry: PopCollectorWidgetEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Total Value
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "figure.pop")
                        .font(.title3)
                        .foregroundColor(.blue)
                    Spacer()
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Collection Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("$\(entry.totalValue, specifier: "%.0f")")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(entry.totalValue > 10000 ? .orange : .green)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Right: Stats
            VStack(alignment: .leading, spacing: 12) {
                StatRow(icon: "square.stack.3d.up", label: "Unique", value: "\(entry.uniqueCount)")
                StatRow(icon: "figure", label: "Total", value: "\(entry.totalCount)")
                
                if let mostValuable = entry.mostValuable {
                    StatRow(icon: "star.fill", label: "Top Pop", value: "$\(Int(mostValuable.value))")
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 16)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Large Widget (Full Stats + Recent)

struct LargeWidgetView: View {
    let entry: PopCollectorWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "figure.pop")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("PopCollector")
                    .font(.headline)
                
                Spacer()
            }
            
            Divider()
            
            // Main Value
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Collection Value")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("$\(entry.totalValue, specifier: "%.2f")")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(entry.totalValue > 10000 ? .orange : .green)
            }
            
            // Stats Grid
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.totalCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Total Pops")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.uniqueCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Unique")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Most Valuable
            if let mostValuable = entry.mostValuable {
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Most Valuable")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(mostValuable.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("$\(mostValuable.value, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                }
            }
            
            // Recent Pops
            if !entry.recentPops.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Additions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(entry.recentPops.prefix(3).enumerated()), id: \.offset) { _, pop in
                        HStack {
                            Text(pop.name)
                                .font(.caption)
                            Spacer()
                            Text("$\(pop.value, specifier: "%.0f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Widget Type Intent

enum WidgetType: String, CaseIterable {
    case totalValue = "Total Value"
    case stats = "Stats"
    case recent = "Recent Additions"
    case mostValuable = "Most Valuable"
}

// This would normally use App Intents framework
// Simplified version for structure
class WidgetTypeIntent {
    var widgetType: WidgetType = .totalValue
}

// MARK: - Widget Bundle

// NOTE: This @main should ONLY be in the Widget Extension target, NOT the main app target
// If you see build errors, make sure this file is excluded from the PopCollector app target
// and only included in the PopCollectorWidget extension target

struct PopCollectorWidgetBundle: WidgetBundle {
    var body: some Widget {
        PopCollectorWidget()
    }
}

// Uncomment this ONLY when creating the Widget Extension target:
// @main
// struct PopCollectorWidgetBundle: WidgetBundle {
//     var body: some Widget {
//         PopCollectorWidget()
//     }
// }

#Preview(as: .systemSmall) {
    PopCollectorWidget()
} timeline: {
    PopCollectorWidgetEntry(
        date: Date(),
        totalValue: 12500.0,
        totalCount: 45,
        uniqueCount: 32,
        mostValuable: PopData(name: "Spider-Man", value: 250.0, imageURL: ""),
        recentPops: [],
        widgetType: .totalValue
    )
}

#Preview(as: .systemMedium) {
    PopCollectorWidget()
} timeline: {
    PopCollectorWidgetEntry(
        date: Date(),
        totalValue: 12500.0,
        totalCount: 45,
        uniqueCount: 32,
        mostValuable: PopData(name: "Spider-Man", value: 250.0, imageURL: ""),
        recentPops: [],
        widgetType: .totalValue
    )
}

#Preview(as: .systemLarge) {
    PopCollectorWidget()
} timeline: {
    PopCollectorWidgetEntry(
        date: Date(),
        totalValue: 12500.0,
        totalCount: 45,
        uniqueCount: 32,
        mostValuable: PopData(name: "Spider-Man Signed", value: 750.0, imageURL: ""),
        recentPops: [
            PopData(name: "Batman", value: 45.0, imageURL: ""),
            PopData(name: "Iron Man", value: 60.0, imageURL: "")
        ],
        widgetType: .totalValue
    )
}

