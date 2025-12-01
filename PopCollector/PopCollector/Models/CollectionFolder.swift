//
//  PopFolder.swift
//  PopCollector
//
//  Custom folder/bin for organizing Pops
//

import Foundation
import SwiftData

@Model
final class PopFolder: Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var order: Int = 0  // For reordering folders
    
    // Relationship: one folder has many pops
    @Relationship(deleteRule: .cascade, inverse: \PopItem.folder)
    var pops: [PopItem] = []
    
    // Auto thumbnail = first Pop's image (or placeholder)
    var thumbnailURL: String {
        pops.first?.imageURL ?? "https://via.placeholder.com/80/444/fff?text=📦"
    }
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
        self.createdAt = Date()
    }
}

