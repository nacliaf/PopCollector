//
//  WidgetDataManager.swift
//  PopCollector
//
//  Manages data sharing between app and widget via App Group
//

import Foundation
import SwiftData
import WidgetKit

class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    // App Group identifier (you'll need to create this in Xcode)
    private let appGroupID = "group.com.popcollector.shared"
    
    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }
    
    private var widgetDataURL: URL? {
        sharedContainerURL?.appendingPathComponent("widgetData.json")
    }
    
    private init() {}
    
    // Update widget data from SwiftData
    func updateWidgetData(context: ModelContext) {
        let descriptor = FetchDescriptor<PopItem>()
        
        guard let pops = try? context.fetch(descriptor) else { return }
        
        let totalValue = pops.reduce(0) { $0 + $1.displayValue }
        let totalCount = pops.reduce(0) { $0 + $1.quantity }
        let uniqueCount = pops.count
        
        let mostValuable = pops.max(by: { $0.displayValue < $1.displayValue })
        let recentPops = Array(pops.sorted { $0.lastUpdated > $1.lastUpdated }.prefix(3))
        
        let widgetData = WidgetData(
            totalValue: totalValue,
            totalCount: totalCount,
            uniqueCount: uniqueCount,
            mostValuable: mostValuable.map {
                PopData(name: $0.name, value: $0.displayValue, imageURL: $0.imageURL)
            },
            recentPops: recentPops.map {
                PopData(name: $0.name, value: $0.displayValue, imageURL: $0.imageURL)
            },
            lastUpdated: Date()
        )
        
        saveWidgetData(widgetData)
    }
    
    // Save widget data to shared container
    private func saveWidgetData(_ data: WidgetData) {
        guard let url = widgetDataURL,
              let jsonData = try? JSONEncoder().encode(data) else { return }
        
        try? jsonData.write(to: url)
        
        // Reload widgets
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // Load widget data (used by widget extension)
    func loadWidgetData() -> WidgetData? {
        guard let url = widgetDataURL,
              let data = try? Data(contentsOf: url),
              let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return nil
        }
        
        return widgetData
    }
}

struct WidgetData: Codable {
    let totalValue: Double
    let totalCount: Int
    let uniqueCount: Int
    let mostValuable: PopData?
    let recentPops: [PopData]
    let lastUpdated: Date
}

struct PopData: Codable {
    let name: String
    let value: Double
    let imageURL: String
}

