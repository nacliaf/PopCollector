//
//  PopItem.swift
//  PopCollector
//
//  Core model for a Funko Pop
//  Includes quantity, signed status, vaulted, pricing, and relationships
//

import Foundation
import SwiftData

@Model
final class PopItem {
    var id: UUID
    var name: String
    var number: String  // Pop number like "#01"
    var series: String   // Series like "Marvel", "DC Heroes"
    var value: Double
    var imageURL: String
    var upc: String
    var lastUpdated: Date
    var source: String
    var trend: Double  // % change from last fetch (for alerts)
    var orderInFolder: Int = 0  // For drag reorder within folder
    var quantity: Int = 1  // How many of this Pop (for duplicates)
    var targetPrice: Double? = nil  // User's wish price for alerts
    var notifiedPrice: Double? = nil  // Tracks last notified price
    var isAlertEnabled: Bool = false  // Toggle price alerts on/off
    var isVaulted: Bool = false  // Mark as vaulted/retired
    var isSigned: Bool = false  // Mark as signed/autographed
    var signedBy: String = ""  // e.g. "Tom Holland"
    var hasCOA: Bool = false  // Certificate of Authenticity
    var signedValueMultiplier: Double = 3.0  // 3× normal value by default
    var folder: PopFolder?
    var isInWishlist: Bool
    var dateAdded: Date
    
    // Computed signed value
    var displayValue: Double {
        let base = value * Double(quantity)
        return isSigned ? base * signedValueMultiplier : base
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        number: String = "",
        series: String = "",
        value: Double = 0.0,
        imageURL: String = "",
        upc: String = "",
        lastUpdated: Date = Date(),
        source: String = "",
        trend: Double = 0.0,
        orderInFolder: Int = 0,
        quantity: Int = 1,
        targetPrice: Double? = nil,
        notifiedPrice: Double? = nil,
        isAlertEnabled: Bool = false,
        isVaulted: Bool = false,
        isSigned: Bool = false,
        signedBy: String = "",
        hasCOA: Bool = false,
        signedValueMultiplier: Double = 3.0,
        folder: PopFolder? = nil,
        isInWishlist: Bool = false,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.number = number
        self.series = series
        self.value = value
        self.imageURL = imageURL
        self.upc = upc
        self.lastUpdated = lastUpdated
        self.source = source
        self.trend = trend
        self.folder = folder
        self.isInWishlist = isInWishlist
        self.dateAdded = dateAdded
    }
}

