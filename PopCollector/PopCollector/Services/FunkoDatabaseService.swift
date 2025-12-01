//
//  FunkoDatabaseService.swift
//  PopCollector
//
//  Service for searching Funko Pop database from multiple sources
//

import Foundation
import SwiftSoup
import UIKit
import SwiftData
import Combine

struct FunkoDatabaseResult: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let number: String
    let series: String
    let imageURL: String
    let productURL: String?  // Direct URL to the product page
    let upc: String?
    let releaseDate: String?
    let category: String?
    let exclusiveTo: String?  // Retailer exclusivity from Excel exclusiveTo field
    let source: String
    let hdbid: String?  // Database ID for deduplication
    let productionStatus: String?  // Chase, Common, Metallic, Glow, etc.
    
    static func == (lhs: FunkoDatabaseResult, rhs: FunkoDatabaseResult) -> Bool {
        lhs.name == rhs.name && lhs.number == rhs.number
    }
}

class FunkoDatabaseService: ObservableObject {
    static let shared = FunkoDatabaseService()
    
    private init() {}
    
    // CSV Database Cache
    // Known autographed hdbids (manually curated for entries that don't have "signed" in text fields)
    // These are entries where images show autographs but CSV doesn't have explicit markers
    private let knownAutographedHDBIDs: Set<String> = [
        "1762254", // Sung Jinwoo (E-Rank) #1941 - autographed image
        "1731836", // Sung Jinwoo (E-Rank) #1941 - autographed image (high value: 630.0)
    ]
    
    private var csvDatabase: [CSVRow] = []
    private var csvLoadDate: Date?
    private let csvCacheExpiration: TimeInterval = 24 * 60 * 60 // 24 hours
    private let csvURL = "https://raw.githubusercontent.com/nacliaf/PopCollector/main/data/database/funko_pops.csv"
    
    // Update checking
    @Published var isUpdatingDatabase = false
    @Published var lastUpdateCheck: Date?
    @Published var databaseUpdateAvailable = false
    @Published var databaseLastModified: Date?
    
    // Use a simple publisher for SwiftUI
    static let databaseUpdatePublisher = NotificationCenter.default.publisher(for: NSNotification.Name("DatabaseUpdateStatusChanged"))
    
    // CSV Row Structure
    private struct CSVRow {
        let hdbid: String
        let name: String
        let number: String
        let series: String
        let imageURL: String
        let upc: String
        let releaseDate: String
        let prodStatus: String
        let slug: String
        let category: String
        let isAutographed: Bool
        // New fields for variant handling
        let isMasterVariant: Bool
        let masterVariantHDBID: String
        let variantType: String  // "master" or "subvariant"
        let stickers: String  // Pipe-separated list
        let exclusivity: String
        let signedBy: String
        let features: String  // Alias for stickers
    }
    
    // MARK: - CSV Subvariants (No API calls needed!)
    
    // Find subvariants from CSV database (same number, similar name)
    // This avoids API calls since CSV has all the data
    func findSubvariantsFromCSV(hdbid: String? = nil, number: String? = nil, name: String? = nil, includeAutographed: Bool = true) -> [HobbyDBVariant] {
        guard !csvDatabase.isEmpty else {
            print("⚠️ CSV database is empty, cannot find subvariants")
            return []
        }
        
        var matchingRows: [CSVRow] = []
        
        // Strategy 1: If we have hdbid, find all entries with same number AND similar name (variants share number and character)
        if let hdbid = hdbid, !hdbid.isEmpty {
            // First, find the entry with this hdbid to get its number and name
            if let baseEntry = csvDatabase.first(where: { $0.hdbid == hdbid }) {
                let baseNumber = baseEntry.number
                let baseName = baseEntry.name.lowercased()
                // Extract character name (remove variant info like "(E-Rank)", "Chase", etc.)
                let cleanBaseName = baseName
                    .replacingOccurrences(of: #"\(.*?\)"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "chase", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "glow", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "metallic", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
                
                if !baseNumber.isEmpty && !cleanBaseName.isEmpty {
                    // Find all entries with the same number AND similar character name
                    // This ensures we only get variants of the same character, not different characters with same number
                    // IMPORTANT: Filter out autographed entries unless explicitly requested
                    matchingRows = csvDatabase.filter { row in
                        // First filter: Must have same number
                        guard row.number == baseNumber else { return false }
                        
                        // Show all entries - no filtering by autographed status
                        
                        let rowName = row.name.lowercased()
                        let cleanRowName = rowName
                            .replacingOccurrences(of: #"\(.*?\)"#, with: "", options: .regularExpression)
                            .replacingOccurrences(of: "chase", with: "", options: .caseInsensitive)
                            .replacingOccurrences(of: "glow", with: "", options: .caseInsensitive)
                            .replacingOccurrences(of: "metallic", with: "", options: .caseInsensitive)
                            .trimmingCharacters(in: .whitespaces)
                        
                        // Check if names match (at least 50% character overlap or one contains the other)
                        return cleanRowName.contains(cleanBaseName) || cleanBaseName.contains(cleanRowName) ||
                               (cleanRowName.count > 0 && cleanBaseName.count > 0 && 
                                Double(Set(cleanRowName).intersection(Set(cleanBaseName)).count) / Double(max(cleanRowName.count, cleanBaseName.count)) > 0.5)
                    }
                } else {
                    // If no number, just return the base entry
                    matchingRows = [baseEntry]
                }
            }
        }
        
        // Strategy 2: If we have number and name, find entries with that number AND similar name
        if matchingRows.isEmpty, let number = number, !number.isEmpty, let name = name, !name.isEmpty {
            let cleanName = name.lowercased()
                .replacingOccurrences(of: #"\(.*?\)"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: "chase", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "glow", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "metallic", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)
            
            matchingRows = csvDatabase.filter { row in
                // First filter: Must have same number
                guard row.number == number else { return false }
                
                    // Show all entries - no filtering by autographed status
                
                let rowName = row.name.lowercased()
                let cleanRowName = rowName
                    .replacingOccurrences(of: #"\(.*?\)"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "chase", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "glow", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "metallic", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
                
                return cleanRowName.contains(cleanName) || cleanName.contains(cleanRowName) ||
                       (cleanRowName.count > 0 && cleanName.count > 0 && 
                        Double(Set(cleanRowName).intersection(Set(cleanName)).count) / Double(max(cleanRowName.count, cleanName.count)) > 0.5)
            }
        }
        
        // Strategy 3: If we have name, find entries with similar name and same number
        if matchingRows.isEmpty, let name = name, !name.isEmpty {
            let nameLower = name.lowercased()
            // Try to extract number from name first
            if let extractedNumber = extractPopNumberFromName(name) {
                matchingRows = csvDatabase.filter { row in
                    // Must have same number
                    guard row.number == extractedNumber else { return false }
                        // Show all entries - no filtering by autographed status
                    return row.name.lowercased().contains(nameLower.prefix(10)) // Match first part of name
                }
            } else {
                // No number found, match by name similarity (but still filter autographed unless requested)
                matchingRows = csvDatabase.filter { row in
                    // Show all entries - no filtering by autographed status
                    return row.name.lowercased().contains(nameLower.prefix(10))
                }
            }
        }
        
        guard !matchingRows.isEmpty else {
            print("⚠️ No subvariants found in CSV for hdbid: \(hdbid ?? "nil"), number: \(number ?? "nil")")
            return []
        }
        
        // Filter out entries that differ ONLY by features (chase, glow, metallic, etc.)
        // Subvariants should only be for entries with different exclusivity/stickers, not different features
        // Features like chase, glow, metallic should show as separate search results, not subvariants
        let filteredMatchingRows = filterSubvariantsByExclusivity(matchingRows)
        
        guard !filteredMatchingRows.isEmpty else {
            print("⚠️ No subvariants found after filtering (only feature differences, not exclusivity differences)")
            return []
        }
        
        // Convert CSV rows to variant format
        // Note: Autographed variants are already filtered above unless includeAutographed is true
        var variants: [HobbyDBVariant] = []
        for row in filteredMatchingRows {
            // Extract features from prod_status and name
            var features: [String] = []
            let nameLower = row.name.lowercased()
            let prodStatusLower = row.prodStatus.lowercased()
            
            if nameLower.contains("chase") || prodStatusLower.contains("chase") {
                features.append("Chase")
            }
            if nameLower.contains("glow") || nameLower.contains("gitd") || prodStatusLower.contains("glow") {
                features.append("Glow in the Dark")
            }
            if nameLower.contains("metallic") || prodStatusLower.contains("metallic") {
                features.append("Metallic")
            }
            if nameLower.contains("flocked") || prodStatusLower.contains("flocked") {
                features.append("Flocked")
            }
            if nameLower.contains("chrome") || prodStatusLower.contains("chrome") {
                features.append("Chrome")
            }
            if nameLower.contains("blacklight") || nameLower.contains("black light") {
                features.append("Blacklight")
            }
            
            // Extract exclusivity from series or name
            var exclusivity: String? = nil
            let searchText = "\(row.name) \(row.series)".lowercased()
            
            let exclusivityPatterns = [
                "hot topic", "gamestop", "target", "walmart", "walmart exclusive",
                "amazon", "amazon exclusive", "barnes & noble", "barnes and noble",
                "boxlunch", "funko shop", "funko shop exclusive",
                "sdcc", "san diego comic con", "nycc", "new york comic con",
                "eccc", "emerald city comic con", "anime expo", "ax",
                "spring convention", "fall convention", "summer convention",
                "shared exclusive", "convention exclusive", "convention shared",
                "ccxp", "comic con"
            ]
            
            for pattern in exclusivityPatterns {
                if searchText.contains(pattern) {
                    exclusivity = pattern.capitalized
                    break
                }
            }
            
            // Check for autographed/signed
            // Use the row's isAutographed flag (set during CSV parsing based on slug/image URL/description)
            // Also check name as a fallback
            var isAutographed = row.isAutographed
            var signedBy: String? = nil
            
            // If not already marked as autographed, check name
            if !isAutographed && (nameLower.contains("autograph") || nameLower.contains("signed")) {
                isAutographed = true
            }
            
            // Try to extract signer name from name if autographed
            if isAutographed {
                if let regex = try? NSRegularExpression(pattern: #"signed\s+by\s+([^,()]+)"#, options: []) {
                    let nsRange = NSRange(nameLower.startIndex..., in: nameLower)
                    if let match = regex.firstMatch(in: nameLower, range: nsRange),
                       match.numberOfRanges > 1,
                       match.range(at: 1).location != NSNotFound,
                       let signerRange = Range(match.range(at: 1), in: nameLower) {
                        signedBy = String(nameLower[signerRange]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
            
            let variant = HobbyDBVariant(
                id: row.hdbid,
                name: row.name,
                number: row.number.isEmpty ? nil : row.number,
                imageURL: row.imageURL.isEmpty ? nil : row.imageURL,
                exclusivity: exclusivity,
                features: features,
                isAutographed: isAutographed,
                signedBy: signedBy,
                upc: row.upc.isEmpty ? nil : row.upc,
                releaseDate: row.releaseDate.isEmpty ? nil : row.releaseDate
            )
            
            variants.append(variant)
        }
        
        print("✅ Found \(variants.count) subvariants from CSV database (hdbid: \(hdbid ?? "nil"), number: \(number ?? "nil"))")
        return variants
    }
    
    // Helper: Filter subvariants to only include entries with different exclusivity/stickers
    // Exclude entries that differ ONLY by features (chase, glow, metallic, etc.)
    // Features should show as separate search results, not subvariants
    private func filterSubvariantsByExclusivity(_ rows: [CSVRow]) -> [CSVRow] {
        guard rows.count > 1 else {
            // If only one row, no subvariants to filter
            return rows
        }
        
        // Extract exclusivity for each row
        var rowsWithExclusivity: [(row: CSVRow, exclusivity: String?)] = []
        for row in rows {
            let searchText = "\(row.name) \(row.series)".lowercased()
            var exclusivity: String? = nil
            
            // Check for exclusivity patterns (conventions, retailers, etc.)
            let exclusivityPatterns = [
                "hot topic", "gamestop", "target", "walmart", "walmart exclusive",
                "amazon", "amazon exclusive", "barnes & noble", "barnes and noble",
                "boxlunch", "funko shop", "funko shop exclusive",
                "sdcc", "san diego comic con", "nycc", "new york comic con",
                "eccc", "emerald city comic con", "anime expo", "ax",
                "spring convention", "fall convention", "summer convention",
                "shared exclusive", "convention exclusive", "convention shared",
                "ccxp", "comic con", "limited edition supreme", "limited edition"
            ]
            
            for pattern in exclusivityPatterns {
                if searchText.contains(pattern) {
                    exclusivity = pattern.capitalized
                    break
                }
            }
            
            rowsWithExclusivity.append((row: row, exclusivity: exclusivity))
        }
        
        // Group by exclusivity
        var exclusivityGroups: [String?: [CSVRow]] = [:]
        for (row, exclusivity) in rowsWithExclusivity {
            if exclusivityGroups[exclusivity] == nil {
                exclusivityGroups[exclusivity] = []
            }
            exclusivityGroups[exclusivity]?.append(row)
        }
        
        // If all rows have the same exclusivity (or all have nil), they're not subvariants
        // Subvariants must have different exclusivity/stickers
        if exclusivityGroups.count <= 1 {
            // All entries have the same exclusivity (or none), so they're not subvariants
            // They differ only by features, which should show as separate search results
            print("⚠️ filterSubvariantsByExclusivity: All entries have same exclusivity, not subvariants (differ only by features)")
            return []
        }
        
        // Return all rows that have different exclusivity (these are true subvariants)
        return rows
    }
    
    // Helper to extract Pop number from name (e.g., "Sung Jinwoo #1941" -> "1941")
    private func extractPopNumberFromName(_ name: String) -> String? {
        // Try pattern: #123
        if let regex = try? NSRegularExpression(pattern: "#(\\d{3,4})", options: []) {
            let nsRange = NSRange(name.startIndex..., in: name)
            if let match = regex.firstMatch(in: name, range: nsRange),
               match.range(at: 1).location != NSNotFound,
               let range = Range(match.range(at: 1), in: name) {
                return String(name[range])
            }
        }
        
        // Try pattern: 123 (standalone number)
        if let regex = try? NSRegularExpression(pattern: "\\b(\\d{3,4})\\b", options: []) {
            let nsRange = NSRange(name.startIndex..., in: name)
            if let match = regex.firstMatch(in: name, range: nsRange),
               match.range(at: 1).location != NSNotFound,
               let range = Range(match.range(at: 1), in: name) {
                return String(name[range])
            }
        }
        
        return nil
    }
    
    // Helper: Check if a result is actually a Funko Pop figure (not podcast, show, etc.)
    private func isValidPopItem(name: String, source: String? = nil) -> Bool {
        let nameLower = name.lowercased()
        
        // Must contain "pop" or "funko pop" (but not just "funko" alone)
        let hasPopKeyword = nameLower.contains("pop") || nameLower.contains("funko pop")
        
        // For official sources (Funko.com, Funko App, Excel Database, CSV Database), check for non-Pop items first
        // These are trusted sources but can still return podcasts, shows, accessories, etc.
        let isTrustedSource = source == "Funko.com" || source == "Funko App API" || source == "Funko Fandom Wiki" || source == "Excel Database" || source == "CSV Database"
        
        // Check for obvious non-Pop items (applies to all sources)
        // Use word boundaries to avoid false positives (e.g., "hattori" shouldn't match "hat")
        let nonPopKeywords = [
            "podcast", "pop talk", "talk:", "s3e", "s2e", "s1e", "episode", "recap",
            "digital pop", "nft", "blockchain", "droppp",
            "tv show", "movie", "film", "documentary", "special", "series premiere",
            "apparel", "shirt", "hoodie", " hat ", " hat,", " hat.", " hat)", " hat(", " bag ", " bag,", " bag.", " bag)", " bag(", "backpack", "t-shirt", "tshirt", "sweatshirt", " tee ", " tee,", " tee.", " tee)", " tee(",
            "pin", "vinyl pin", "lanyard", "sticker", "patch", "mug", "bottle", "water bottle", 
            "keychain", "mystery box", "plush", "beanbag", "funkast",
            "ornament", "wallet", "zip around", "boxed tee", "kamehameha boxed",
            "coming soon", "pre-order", "preorder",
            // Promotional/event items
            "rally", "funzone", "kansas city", "do your homework", "honor teacher", "teacher appreciation",
            "returning:", "yourself", "custom", "halloween", "unique & custom",
            "chalkboard", "baseball", "#1 teacher", "#1 dad"
        ]
        
        // Check if name starts with or contains the keyword as a whole word
        let hasNonPopKeyword = nonPopKeywords.contains { keyword in
            // Add spaces/word boundaries to avoid substring matches
            let keywordWithSpaces = " \(keyword) "
            return nameLower == keyword || 
                   nameLower.hasPrefix("\(keyword) ") || 
                   nameLower.hasSuffix(" \(keyword)") ||
                   nameLower.contains(keywordWithSpaces) ||
                   nameLower.contains("\(keyword),") ||
                   nameLower.contains("\(keyword).") ||
                   nameLower.contains("(\(keyword)") ||
                   nameLower.contains("\(keyword))")
        }
        if hasNonPopKeyword {
            return false
        }
        
        // For trusted sources, be lenient if no exclusion keywords found
        // This helps catch items where "Pop!" was removed during name cleaning
        if isTrustedSource {
            return true
        }
        
        guard hasPopKeyword else { return false }
        
        // Additional exclusion checks for non-trusted sources
        // (Trusted sources already handled above)
        let additionalExclusions = [
            "show", "television", "tv show", "tv series", "series premiere",
            "season", "broadcast", "streaming", "video",
            "event", "conference", "panel", "interview", "webinar",
            "livestream", "watch", "viewing"
        ]
        
        for keyword in additionalExclusions {
            if nameLower.contains(keyword) {
                // Allow "pop series" (like "Star Wars Pop Series") but not "tv series"
                if keyword == "series" {
                    if nameLower.contains("tv series") || nameLower.contains("show series") || 
                       nameLower.contains("television series") {
                        return false
                    }
                    // Allow "series" if it's clearly part of "Pop Series" or has Pop number
                    if nameLower.contains("pop series") || nameLower.range(of: #"#\d+"#, options: .regularExpression) != nil {
                        return true
                    }
                } else {
                    return false
                }
            }
        }
        
        // Additional check: if it contains "funko" but not "pop", exclude it (unless it's clearly a Pop variant)
        if nameLower.contains("funko") && !nameLower.contains("pop") {
            // Allow if it's a known Pop variant name
            let popVariants = ["vinyl", "figure", "collectible", "funko pop", "#"]
            let hasPopVariant = popVariants.contains { nameLower.contains($0) }
            if !hasPopVariant {
                return false
            }
        }
        
        return true
    }
    
    // Search Funko Pops from GitHub CSV database
    func searchPops(query: String, modelContext: ModelContext? = nil, includeAutographed: Bool = false) async -> [FunkoDatabaseResult] {
        let cleanQuery = query.trimmingCharacters(in: .whitespaces)
        guard !cleanQuery.isEmpty else { return [] }
        
        // Load CSV database if needed
        await loadCSVDatabaseIfNeeded()
        
        // Search CSV database
        let csvResults = searchCSVDatabase(query: cleanQuery, includeAutographed: includeAutographed)
        
        print("   ✅ CSV Database: Found \(csvResults.count) results for '\(cleanQuery)' (includeAutographed: \(includeAutographed))")
        
        // Sort by relevance: exact name matches first, then by name
        let sortedResults = csvResults.sorted { lhs, rhs in
            let lhsExact = lhs.name.localizedCaseInsensitiveContains(cleanQuery)
            let rhsExact = rhs.name.localizedCaseInsensitiveContains(cleanQuery)
            if lhsExact != rhsExact {
                return lhsExact
            }
            return lhs.name < rhs.name
        }
        
        return sortedResults
    }
    
    // Extract series names from search results to search collection pages
    private func extractSeriesFromResults(_ results: [FunkoDatabaseResult]) -> [String] {
        var seriesSet = Set<String>()
        
        for result in results {
            let series = result.series.trimmingCharacters(in: .whitespaces)
            // Only include meaningful series names (not empty, not generic "Funko Pop!")
            if !series.isEmpty && 
               series.lowercased() != "funko pop!" && 
               series.lowercased() != "funko pop" &&
               !series.lowercased().contains("unknown") {
                seriesSet.insert(series)
            }
        }
        
        // Also check if we can infer series from the query
        // Common patterns: "Solo Leveling", "Dragon Ball", etc.
        let commonSeries = ["Solo Leveling", "Dragon Ball", "Marvel", "DC", "Star Wars", "Disney"]
        for series in commonSeries {
            if results.contains(where: { $0.series.localizedCaseInsensitiveContains(series) }) {
                seriesSet.insert(series)
            }
        }
        
        return Array(seriesSet)
    }
    
    // Generate comprehensive search variations to find ALL variants
    private func generateSearchVariations(query: String) -> [String] {
        let cleanQuery = query.trimmingCharacters(in: .whitespaces)
        var variations: [String] = [cleanQuery] // Original query
        
        let queryLower = cleanQuery.lowercased()
        
        // Basic variations
        variations.append(cleanQuery.capitalized)
        variations.append(cleanQuery.uppercased())
        
        // Character-specific variations for popular characters
        addCharacterSpecificVariations(query: cleanQuery, queryLower: queryLower, variations: &variations)
        
        // Add "Funko Pop" prefix if not already present
        if !queryLower.contains("funko") && !queryLower.contains("pop") {
            variations.append("Funko Pop \(cleanQuery)")
            variations.append("Funko Pop! \(cleanQuery)")
            variations.append("Pop! \(cleanQuery)")
            variations.append("POP! \(cleanQuery.uppercased())")
        }
        
        // Hyphenated variations (common in Funko naming)
        variations.append(cleanQuery.replacingOccurrences(of: " ", with: "-"))
        variations.append(cleanQuery.replacingOccurrences(of: "-", with: " "))
        
        // Common character name patterns
        // If query is a single name, try adding common patterns
        let parts = cleanQuery.components(separatedBy: .whitespaces)
        if parts.count == 1 {
            // Single word - might be character name
            variations.append(cleanQuery.capitalized)
            variations.append("\(cleanQuery) Funko Pop")
            variations.append("Pop! \(cleanQuery.capitalized)")
        } else if parts.count == 2 {
            // Two words - might be first and last name
            variations.append(parts[0].capitalized + " " + parts[1].capitalized)
            variations.append(parts[1].capitalized + " " + parts[0].capitalized)
        }
        
        // Search for specific variant types (important for finding all variants)
        // Include vaulted/retired keywords to find items not currently for sale
        let variantTypes = ["Chase", "Glow", "Metallic", "Flocked", "Chrome", "Black Light", "Blacklight", "Limited Edition", "Exclusive", "10 inch", "10\"", "18 inch", "18\"", "Deluxe", "Two Pack", "Three Pack", "Rides", "E-Rank", "Upgrade", "SUPREME", "Golden", "Vaulted", "Retired", "Out of Stock", "Pre-Order", "Pending"]
        for variant in variantTypes {
            variations.append("\(cleanQuery) \(variant)")
            variations.append("\(variant) \(cleanQuery)")
            variations.append("Pop! \(cleanQuery) \(variant)")
            variations.append("Funko Pop \(cleanQuery) \(variant)")
        }
        
        // Try with series names if we detected a popular character
        if let seriesVariations = getSeriesVariations(for: queryLower) {
            for seriesVar in seriesVariations {
                variations.append("\(seriesVar) \(cleanQuery)")
                variations.append("Pop! \(seriesVar) \(cleanQuery)")
                variations.append("Funko Pop \(seriesVar) \(cleanQuery)")
            }
        }
        
        // Remove duplicates but preserve order
        var seen = Set<String>()
        var uniqueVariations: [String] = []
        for variation in variations {
            let normalized = variation.lowercased().trimmingCharacters(in: .whitespaces)
            if !seen.contains(normalized) {
                seen.insert(normalized)
                uniqueVariations.append(variation)
            }
        }
        
        return uniqueVariations
    }
    
    // Add character-specific search variations for popular characters
    private func addCharacterSpecificVariations(query: String, queryLower: String, variations: inout [String]) {
        // Goku variations
        if queryLower == "goku" || queryLower.contains("goku") {
            variations.append("Son Goku")
            variations.append("Dragon Ball Goku")
            variations.append("Dragon Ball Z Goku")
            variations.append("Dragon Ball Super Goku")
            variations.append("DBZ Goku")
            variations.append("DBS Goku")
            variations.append("Pop! Dragon Ball Goku")
            variations.append("Pop! Dragon Ball Z Goku")
            variations.append("Pop! Dragon Ball Super Goku")
        }
        
        // Jinwoo variations - add specific variant searches
        if queryLower == "jinwoo" || queryLower.contains("jinwoo") {
            variations.append("Sung Jinwoo")
            variations.append("Solo Leveling Jinwoo")
            variations.append("Solo Leveling Sung Jinwoo")
            variations.append("Pop! Sung Jinwoo")
            variations.append("Pop! Solo Leveling Jinwoo")
            variations.append("Funko Pop Sung Jinwoo")
            variations.append("Funko Pop Solo Leveling")
            
            // Add specific variant searches for Jinwoo
            variations.append("Sung Jinwoo E-Rank")
            variations.append("Sung Jinwoo E-Rank with Inventory")
            variations.append("Sung Jinwoo Upgrade")
            variations.append("Sung Jinwoo SUPREME")
            variations.append("Sung Jinwoo Golden")
            variations.append("Sung Jinwoo Chase")
            variations.append("Sung Jinwoo Glow")
            variations.append("Pop! & Buddy Sung Jinwoo")
            variations.append("Sung Jinwoo AX")
            variations.append("Sung Jinwoo Exclusive")
        }
        
        // Add more character-specific patterns here as needed
    }
    
    // Get series variations for a character query
    private func getSeriesVariations(for queryLower: String) -> [String]? {
        if queryLower.contains("goku") || queryLower.contains("vegeta") || queryLower.contains("piccolo") {
            return ["Dragon Ball", "Dragon Ball Z", "Dragon Ball Super", "DBZ", "DBS"]
        }
        if queryLower.contains("naruto") || queryLower.contains("sasuke") || queryLower.contains("kakashi") {
            return ["Naruto", "Naruto Shippuden"]
        }
        if queryLower.contains("luffy") || queryLower.contains("zoro") || queryLower.contains("nami") {
            return ["One Piece"]
        }
        if queryLower.contains("jinwoo") || queryLower.contains("solo leveling") {
            return ["Solo Leveling"]
        }
        if queryLower.contains("tanjiro") || queryLower.contains("nezuko") || queryLower.contains("demon slayer") {
            return ["Demon Slayer", "Kimetsu no Yaiba"]
        }
        return nil
    }
    
    // REMOVED: All unused search functions - now using CSV database only
    // Deleted: searchHobbyDB, searchHobbyDB_API, searchFunkoAppAPI, searchFunkoComSingleQuery,
    // searchFunkoComPage, searchFunkoCollectionPage, searchGitHubDatabase, searchFandomWiki
    
    // Quick search: Use CSV database
    func searchLocalDatabase(query: String, modelContext: ModelContext? = nil, includeAutographed: Bool = false) async -> [FunkoDatabaseResult] {
        return await searchPops(query: query, modelContext: modelContext, includeAutographed: includeAutographed)
    }
    
    // MARK: - CSV Database Loading
    
    // Load CSV database from GitHub if needed
    private func loadCSVDatabaseIfNeeded() async {
        // Check if cache is still valid
        if let loadDate = csvLoadDate,
           Date().timeIntervalSince(loadDate) < csvCacheExpiration,
           !csvDatabase.isEmpty {
            print("📦 Using cached CSV database (\(csvDatabase.count) entries)")
            return
        }
        
        await loadCSVDatabase(forceUpdate: false)
    }
    
    // Load CSV database from GitHub (public for manual updates)
    func loadCSVDatabase(forceUpdate: Bool = false) async {
        guard !isUpdatingDatabase else {
            print("⚠️ Database update already in progress")
            return
        }
        
        // Check if cache is still valid (unless forcing update)
        if !forceUpdate,
           let loadDate = csvLoadDate,
           Date().timeIntervalSince(loadDate) < csvCacheExpiration,
           !csvDatabase.isEmpty {
            print("📦 Using cached CSV database (\(csvDatabase.count) entries)")
            // Debug: Check if known autographed entries are marked correctly
            let autographedCount = csvDatabase.filter { $0.isAutographed }.count
            let knownAutographedInCache = csvDatabase.filter { knownAutographedHDBIDs.contains($0.hdbid) }
            print("📊 Cache stats: \(autographedCount) autographed entries, \(knownAutographedInCache.count) known autographed HDBIDs in cache")
            for row in knownAutographedInCache {
                print("   - hdbid \(row.hdbid): \(row.name) - isAutographed: \(row.isAutographed)")
            }
            return
        }
        
        await MainActor.run {
            isUpdatingDatabase = true
        }
        
        print("📥 Loading CSV database from GitHub...")
        
        guard let url = URL(string: csvURL) else {
            print("❌ Invalid CSV URL: \(csvURL)")
            await MainActor.run {
                isUpdatingDatabase = false
            }
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("PopCollector/1.0", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Failed to load CSV: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                await MainActor.run {
                    isUpdatingDatabase = false
                }
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                print("❌ Failed to load CSV: HTTP \(httpResponse.statusCode)")
                await MainActor.run {
                    isUpdatingDatabase = false
                }
                return
            }
            
            // Check Last-Modified header for update detection
            if let lastModifiedString = httpResponse.value(forHTTPHeaderField: "Last-Modified"),
               let lastModified = parseHTTPDate(lastModifiedString) {
                await MainActor.run {
                    databaseLastModified = lastModified
                }
            }
            
            guard let csvString = String(data: data, encoding: .utf8) else {
                print("❌ Failed to decode CSV data")
                await MainActor.run {
                    isUpdatingDatabase = false
                }
                return
            }
            
            print("📥 Received CSV data: \(data.count) bytes, string length: \(csvString.count) characters")
            if csvString.count < 100 {
                print("   CSV content (short): \(csvString)")
            } else {
                print("   CSV first 200 chars: \(String(csvString.prefix(200)))")
            }
            
            // Parse CSV
            csvDatabase = parseCSV(csvString: csvString)
            csvLoadDate = Date()
            
            await MainActor.run {
                isUpdatingDatabase = false
                lastUpdateCheck = Date()
                databaseUpdateAvailable = false
            }
            
            NotificationCenter.default.post(name: NSNotification.Name("DatabaseUpdateStatusChanged"), object: nil)
            
            print("✅ Loaded CSV database: \(csvDatabase.count) entries")
        } catch {
            print("❌ Error loading CSV database: \(error.localizedDescription)")
            await MainActor.run {
                isUpdatingDatabase = false
            }
        }
    }
    
    // Check for database updates on GitHub
    func checkForDatabaseUpdates() async {
        await MainActor.run {
            lastUpdateCheck = Date()
        }
        
        print("🔍 Checking for database updates...")
        
        guard let url = URL(string: csvURL) else {
            print("❌ Invalid CSV URL: \(csvURL)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD" // Only get headers, not the full file
        request.setValue("PopCollector/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("⚠️ Failed to check for updates: HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
                return
            }
            
            // Check Last-Modified header
            if let lastModifiedString = httpResponse.value(forHTTPHeaderField: "Last-Modified"),
               let lastModified = parseHTTPDate(lastModifiedString) {
                
                await MainActor.run {
                    databaseLastModified = lastModified
                    
                    // Check if update is available (newer than our cache)
                    if let cacheDate = csvLoadDate {
                        databaseUpdateAvailable = lastModified > cacheDate
                    } else {
                        // No cache, so update is "available" (we should load it)
                        databaseUpdateAvailable = true
                    }
                    
                    let hasUpdate = databaseUpdateAvailable
                    NotificationCenter.default.post(name: NSNotification.Name("DatabaseUpdateStatusChanged"), object: nil)
                    
                    if hasUpdate {
                        print("🔄 Database update available (last modified: \(lastModified))")
                    } else {
                        print("✅ Database is up to date")
                    }
                }
            }
        } catch {
            print("⚠️ Error checking for updates: \(error.localizedDescription)")
        }
    }
    
    // Update database (download and reload CSV)
    func updateDatabase() async {
        await loadCSVDatabase(forceUpdate: true)
    }
    
    // Clear CSV cache to force reload (useful for debugging autographed detection)
    func clearCSVCache() {
        csvDatabase = []
        csvLoadDate = nil
        print("🗑️ CSV cache cleared - will reload on next search")
    }
    
    // Parse HTTP date string (RFC 7231 format)
    private func parseHTTPDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        // Try common HTTP date formats
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss zzz",  // RFC 7231
            "EEEE, dd-MMM-yy HH:mm:ss zzz",   // RFC 850
            "EEE MMM dd HH:mm:ss yyyy"        // ANSI C
        ]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    // Parse CSV string into rows (handles multi-line quoted fields)
    private func parseCSV(csvString: String) -> [CSVRow] {
        var rows: [CSVRow] = []
        
        print("📊 CSV string length: \(csvString.count) characters")
        
        // Parse CSV properly handling multi-line quoted fields
        let records = parseCSVRecords(csvString)
        
        print("📊 Parsed \(records.count) raw records from CSV")
        
        guard records.count > 1 else {
            print("⚠️ CSV parsing returned \(records.count) records (need at least 2)")
            if let firstRecord = records.first {
                print("   First record has \(firstRecord.count) fields")
            }
            return rows
        }
        
        // Skip header line
        let dataRecords = Array(records.dropFirst())
        print("📊 Processing \(dataRecords.count) data records (after removing header)")
        
        var skippedCount = 0
        let hasNewFormat = records.first?.count ?? 0 >= 27  // New format has 27 columns
        
        for fields in dataRecords {
            guard fields.count >= 14 else {
                skippedCount += 1
                if skippedCount <= 3 {
                    print("   ⚠️ Skipping record with \(fields.count) columns (need >= 14): \(fields.first ?? "empty")")
                }
                continue
            } // Need at least 14 columns (up to slug)
            
            let hdbid = fields[0].trimmingCharacters(in: .whitespaces)
            let nameLower = fields[1].lowercased()
            let slugLower = fields.count > 13 ? fields[13].trimmingCharacters(in: .whitespaces).lowercased() : ""
            let imageURLLower = fields[4].lowercased()
            let description = fields.count > 5 ? fields[5].lowercased() : ""
            
            // Determine if autographed - use CSV field if available, otherwise detect
            var isAutographed = false
            if hasNewFormat && fields.count > 24 {
                // New format: use is_autographed field (index 24)
                let autographedValue = fields[24].trimmingCharacters(in: .whitespaces).lowercased()
                isAutographed = autographedValue == "1" || autographedValue == "true"
            } else {
                // Old format: detect from fields
                let slugIndicatesAutographed = slugLower.contains("signed") || 
                                              slugLower.contains("autograph") ||
                                              slugLower.contains("signed-by") ||
                                              slugLower.contains("signed-by-")
                
                let imageURLIndicatesAutographed = imageURLLower.contains("signed") ||
                                                   imageURLLower.contains("autograph") ||
                                                   imageURLLower.contains("autographed") ||
                                                   imageURLLower.contains("signed-by") ||
                                                   imageURLLower.contains("signed-by-") ||
                                                   imageURLLower.contains("autographed-by") ||
                                                   imageURLLower.contains("autographed-by-")
                
                let hasAutographText = nameLower.contains("signed") || 
                                       nameLower.contains("autograph") ||
                                       description.contains("signed by") ||
                                       description.contains("signed") ||
                                       description.contains("autograph") ||
                                       description.contains("autographed") ||
                                       description.contains("jsa certified") ||
                                       description.contains("certified") ||
                                       description.contains("signature") ||
                                       description.contains("signed pop") ||
                                       description.contains("autographed pop")
                
                let isKnownAutographed = knownAutographedHDBIDs.contains(hdbid)
                isAutographed = slugIndicatesAutographed || imageURLIndicatesAutographed || hasAutographText || isKnownAutographed
            }
            
            // Extract new fields if available
            let isMasterVariant = hasNewFormat && fields.count > 19 ? (fields[19].trimmingCharacters(in: .whitespaces) == "1") : true  // Default to master if unknown
            let masterVariantHDBID = hasNewFormat && fields.count > 20 ? fields[20].trimmingCharacters(in: .whitespaces) : ""
            let variantType = hasNewFormat && fields.count > 21 ? fields[21].trimmingCharacters(in: .whitespaces) : "master"
            let stickers = hasNewFormat && fields.count > 22 ? fields[22].trimmingCharacters(in: .whitespaces) : ""
            let exclusivity = hasNewFormat && fields.count > 23 ? fields[23].trimmingCharacters(in: .whitespaces) : ""
            let signedBy = hasNewFormat && fields.count > 25 ? fields[25].trimmingCharacters(in: .whitespaces) : ""
            let features = hasNewFormat && fields.count > 26 ? fields[26].trimmingCharacters(in: .whitespaces) : stickers
            
            let row = CSVRow(
                hdbid: hdbid,
                name: fields[1].trimmingCharacters(in: .whitespaces),
                number: fields[2].trimmingCharacters(in: .whitespaces),
                series: fields[3].trimmingCharacters(in: .whitespaces),
                imageURL: fields[4].trimmingCharacters(in: .whitespaces),
                upc: fields[8].trimmingCharacters(in: .whitespaces),
                releaseDate: fields[9].trimmingCharacters(in: .whitespaces),
                prodStatus: fields[10].trimmingCharacters(in: .whitespaces),
                slug: fields[13].trimmingCharacters(in: .whitespaces),
                category: fields[6].trimmingCharacters(in: .whitespaces),
                isAutographed: isAutographed,
                isMasterVariant: isMasterVariant,
                masterVariantHDBID: masterVariantHDBID,
                variantType: variantType,
                stickers: stickers,
                exclusivity: exclusivity,
                signedBy: signedBy,
                features: features
            )
            
            // Include all entries - filtering happens at the search/display layer
            rows.append(row)
        }
        
        if skippedCount > 0 {
            print("   ⚠️ Total skipped records (wrong column count): \(skippedCount)")
        }
        print("📊 Final CSV parse result: \(rows.count) valid rows")
        
        return rows
    }
    
    // Parse entire CSV string into records, handling multi-line quoted fields
    // Uses a simpler line-based approach that's more robust for hobbyDB data
    private func parseCSVRecords(_ csvString: String) -> [[String]] {
        var records: [[String]] = []
        
        // Split by lines first, then handle quoted fields that span lines
        let lines = csvString.components(separatedBy: "\n")
        var currentLineBuffer = ""
        var insideQuotes = false
        
        for line in lines {
            // Remove \r if present
            let cleanLine = line.hasSuffix("\r") ? String(line.dropLast()) : line
            
            if currentLineBuffer.isEmpty {
                currentLineBuffer = cleanLine
            } else {
                currentLineBuffer += "\n" + cleanLine
            }
            
            // Count unescaped quotes to determine if we're inside a quoted field
            // Escaped quotes ("") count as 0, single quotes count as 1
            var quoteCount = 0
            var i = 0
            let chars = Array(currentLineBuffer)
            while i < chars.count {
                if chars[i] == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        i += 2  // Skip escaped quote
                        continue
                    }
                    quoteCount += 1
                }
                i += 1
            }
            
            insideQuotes = (quoteCount % 2) == 1
            
            // If we have an even number of quotes, the line is complete
            if !insideQuotes {
                if let record = parseCSVLine(currentLineBuffer) {
                    records.append(record)
                }
                currentLineBuffer = ""
            }
        }
        
        // Handle any remaining buffer
        if !currentLineBuffer.isEmpty {
            if let record = parseCSVLine(currentLineBuffer) {
                records.append(record)
            }
        }
        
        return records
    }
    
    // Parse a single CSV line into fields
    private func parseCSVLine(_ line: String) -> [String]? {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        let chars = Array(line)
        var i = 0
        
        while i < chars.count {
            let char = chars[i]
            
            if char == "\"" {
                if insideQuotes {
                    // Check for escaped quote
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        insideQuotes = false
                    }
                } else {
                    insideQuotes = true
                }
            } else if char == "," && !insideQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
            
            i += 1
        }
        
        // Add last field
        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        
        // Skip empty lines
        if fields.count == 1 && fields[0].isEmpty {
            return nil
        }
        
        return fields
    }
    
    // Search CSV database
    private func searchCSVDatabase(query: String, includeAutographed: Bool = false) -> [FunkoDatabaseResult] {
        guard !csvDatabase.isEmpty else {
            print("⚠️ CSV database is empty")
            return []
        }
        
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespaces)
        var results: [FunkoDatabaseResult] = []
        var matchCount = 0
        
        // Check if query is a number (for searching by Pop number)
        let isNumberQuery = queryLower.allSatisfy { $0.isNumber } || 
                           (queryLower.hasPrefix("#") && queryLower.dropFirst().allSatisfy { $0.isNumber })
        let queryNumber = queryLower.replacingOccurrences(of: "#", with: "")
        
        for row in csvDatabase {
            // Filter out autographed pops - only show master/unique variants
            if row.isAutographed {
                let rowNameLower = row.name.lowercased()
                if rowNameLower.contains("jinwoo") || row.number == "1982" || row.number == "2037" {
                    print("🚫 Filtered out autographed: \(row.name) #\(row.number) (hdbid: \(row.hdbid))")
                }
                continue
            }
            
            let nameLower = row.name.lowercased()
            let seriesLower = row.series.lowercased()
            let slugLower = row.slug.lowercased()
            
            // Search logic:
            // - If query is a number, match by Pop number
            // - Otherwise match by name, series, slug, or UPC (NOT by number alone)
            var isMatch = false
            
            if isNumberQuery {
                // Number query: match exact Pop number
                isMatch = row.number == queryNumber
            } else {
            // Text query: match name, series, or slug (NOT number or UPC to avoid false matches)
            // Only match UPC if query looks like a UPC (12-13 digits)
            let queryIsUPC = queryLower.range(of: #"^\d{12,13}$"#, options: .regularExpression) != nil
            isMatch = nameLower.contains(queryLower) ||
                     seriesLower.contains(queryLower) ||
                     slugLower.contains(queryLower) ||
                     (queryIsUPC && row.upc.lowercased().contains(queryLower))
            }
            
            if isMatch {
                matchCount += 1
                
                // Extract features from name and prod_status
                var features: [String] = []
                let nameLower = row.name.lowercased()
                let prodStatusLower = row.prodStatus.lowercased()
                
                if nameLower.contains("chase") || prodStatusLower.contains("chase") {
                    features.append("Chase")
                }
                if nameLower.contains("glow") || nameLower.contains("gitd") || prodStatusLower.contains("glow") {
                    features.append("Glow in the Dark")
                }
                if nameLower.contains("metallic") || prodStatusLower.contains("metallic") {
                    features.append("Metallic")
                }
                if nameLower.contains("gold") && !nameLower.contains("golden") {
                    features.append("Gold")
                }
                if nameLower.contains("flocked") || prodStatusLower.contains("flocked") {
                    features.append("Flocked")
                }
                if nameLower.contains("chrome") || prodStatusLower.contains("chrome") {
                    features.append("Chrome")
                }
                if nameLower.contains("blacklight") || nameLower.contains("black light") {
                    features.append("Blacklight")
                }
                if nameLower.contains("diamond") && !nameLower.contains("diamond select") {
                    features.append("Diamond")
                }
                
                // Combine prod_status and extracted features for productionStatus
                var productionStatus: String? = nil
                if !row.prodStatus.isEmpty {
                    productionStatus = row.prodStatus
                }
                // If we found features in the name that aren't in prod_status, add them
                if !features.isEmpty {
                    let featuresString = features.joined(separator: ", ")
                    if let existing = productionStatus, !existing.isEmpty {
                        // Check if features are already in prod_status
                        let existingLower = existing.lowercased()
                        let newFeatures = features.filter { !existingLower.contains($0.lowercased()) }
                        if !newFeatures.isEmpty {
                            productionStatus = "\(existing), \(newFeatures.joined(separator: ", "))"
                        } else {
                            productionStatus = existing
                        }
                    } else {
                        productionStatus = featuresString
                    }
                }
                
                // Extract exclusivity - FIRST use CSV's exclusivity column if available, then fall back to extraction
                var exclusivity: String? = nil
                
                // Use CSV's exclusivity column directly if it's not empty
                if !row.exclusivity.isEmpty {
                    exclusivity = row.exclusivity
                } else {
                    // Fall back to extracting from name/series if CSV column is empty
                    let nameAndSeries = "\(row.name) \(row.series)".lowercased()
                    
                    // Check for exclusivity patterns - order matters (more specific first)
                    // Conventions with shared vs exclusive
                    if nameAndSeries.contains("shared") || nameAndSeries.contains("convention shared") {
                    if nameAndSeries.contains("sdcc") || nameAndSeries.contains("san diego") {
                        exclusivity = "SDCC Shared"
                    } else if nameAndSeries.contains("nycc") || nameAndSeries.contains("new york") {
                        exclusivity = "NYCC Shared"
                    } else if nameAndSeries.contains("eccc") || nameAndSeries.contains("emerald city") {
                        exclusivity = "ECCC Shared"
                    } else if nameAndSeries.contains("anime expo") || nameAndSeries.contains(" ax ") || nameAndSeries.contains("[ax]") {
                        exclusivity = "Anime Expo Shared"
                    } else if nameAndSeries.contains("ccxp") {
                        exclusivity = "CCXP Shared"
                    } else if nameAndSeries.contains("spring convention") {
                        exclusivity = "Spring Convention Shared"
                    } else if nameAndSeries.contains("fall convention") {
                        exclusivity = "Fall Convention Shared"
                    } else if nameAndSeries.contains("summer convention") {
                        exclusivity = "Summer Convention Shared"
                    } else {
                        exclusivity = "Convention Shared"
                    }
                    } else if nameAndSeries.contains("limited edition") || nameAndSeries.contains("convention exclusive") {
                    if nameAndSeries.contains("sdcc") || nameAndSeries.contains("san diego") {
                        exclusivity = "SDCC Exclusive"
                    } else if nameAndSeries.contains("nycc") || nameAndSeries.contains("new york") {
                        exclusivity = "NYCC Exclusive"
                    } else if nameAndSeries.contains("eccc") || nameAndSeries.contains("emerald city") {
                        exclusivity = "ECCC Exclusive"
                    } else if nameAndSeries.contains("anime expo") || nameAndSeries.contains(" ax ") || nameAndSeries.contains("[ax]") {
                        exclusivity = "Anime Expo Exclusive"
                    } else if nameAndSeries.contains("ccxp") {
                        exclusivity = "CCXP Exclusive"
                    } else if nameAndSeries.contains("limited edition supreme") {
                        exclusivity = "Limited Edition Supreme"
                    } else if nameAndSeries.contains("limited edition") {
                        exclusivity = "Limited Edition"
                    }
                    }
                    
                    // Special exclusivity patterns (before retailers)
                    if exclusivity == nil {
                    if nameAndSeries.contains("anime of the year") {
                        exclusivity = "Anime of the Year"
                    } else if nameAndSeries.contains("supreme") {
                        exclusivity = "Supreme"
                    }
                    }
                    
                    // Retailers (if no convention match)
                    if exclusivity == nil {
                    let retailerPatterns: [(String, String)] = [
                        ("hot topic", "Hot Topic"),
                        ("gamestop", "GameStop"),
                        ("target", "Target"),
                        ("walmart", "Walmart"),
                        ("amazon", "Amazon"),
                        ("barnes & noble", "Barnes & Noble"),
                        ("barnes and noble", "Barnes & Noble"),
                        ("boxlunch", "BoxLunch"),
                        ("funko shop", "Funko Shop"),
                        ("entertainment earth", "Entertainment Earth"),
                        ("funko.com", "Funko.com"),
                        ("specialty series", "Specialty Series"),
                        ("chase", "") // Chase is a feature, not exclusivity
                    ]
                    
                    for (pattern, label) in retailerPatterns {
                        if nameAndSeries.contains(pattern) && !label.isEmpty {
                            exclusivity = label
                            break
                        }
                    }
                    }
                }
                
                let result = FunkoDatabaseResult(
                    name: row.name,
                    number: row.number,
                    series: row.series,
                    imageURL: row.imageURL,
                    productURL: nil, // CSV doesn't have product URLs
                    upc: row.upc.isEmpty ? nil : row.upc,
                    releaseDate: row.releaseDate.isEmpty ? nil : row.releaseDate,
                    category: row.category.isEmpty ? nil : row.category,
                    exclusiveTo: exclusivity,
                    source: "CSV Database",
                    hdbid: row.hdbid.isEmpty ? nil : row.hdbid, // Preserve hdbid for subvariants!
                    productionStatus: productionStatus
                )
                
                results.append(result)
            }
        }
        
        // Deduplicate by unique combination: number + name + exclusivity + features (productionStatus)
        // This allows showing different variants with same number (e.g., Standard #1982, Chase #1982, Gold #1982)
        // Also distinguishes variants with same number but different names (e.g., "E-Rank Version" vs "E-Rank w/ Inventory")
        var uniqueResults: [FunkoDatabaseResult] = []
        var seenKeys: Set<String> = []
        
        for result in results {
            // Create unique key: number + name + exclusivity + productionStatus (features)
            // Use normalized name (lowercase, trimmed) to handle minor variations
            let normalizedName = result.name.lowercased().trimmingCharacters(in: .whitespaces)
            let exclusivityKey = result.exclusiveTo ?? ""
            let featuresKey = result.productionStatus ?? ""
            let uniqueKey = "\(result.number)|\(normalizedName)|\(exclusivityKey)|\(featuresKey)"
            
            // Only add if we haven't seen this exact combination
            if !seenKeys.contains(uniqueKey) {
                uniqueResults.append(result)
                seenKeys.insert(uniqueKey)
                if normalizedName.contains("jinwoo") {
                    print("✅ Added variant: \(result.name) #\(result.number) | exclusivity: \(exclusivityKey) | features: \(featuresKey)")
                }
            } else {
                if normalizedName.contains("jinwoo") {
                    print("⚠️ Skipped duplicate: \(result.name) #\(result.number) | exclusivity: \(exclusivityKey) | features: \(featuresKey)")
                }
            }
        }
        
        print("🔍 CSV search: Found \(matchCount) matches, returning \(uniqueResults.count) unique variants for '\(query)' (searched \(csvDatabase.count) entries)")
        return uniqueResults
    }
    
    // Helper: Extract retailer name from dictionary string format
    func extractRetailerName(from exclusiveTo: String) -> String {
        guard !exclusiveTo.isEmpty else { return "" }
        
        // Check if it's a dictionary string format: {'name': 'Retailer Name', ...}
        // Handle both 'name': 'Retailer' and 'name': Retailer (without quotes around value)
        if let nameRange = exclusiveTo.range(of: "'name':") {
            let afterName = String(exclusiveTo[nameRange.upperBound...])
            // Skip whitespace
            let cleaned = afterName.trimmingCharacters(in: .whitespaces)
            
            if cleaned.hasPrefix("'") {
                // Format: 'name': 'Retailer' or 'name': 'Toys 'R' Us'
                // Find the closing quote that's followed by comma or closing brace
                var currentIndex = cleaned.index(after: cleaned.startIndex) // Skip opening quote
                
                while currentIndex < cleaned.endIndex {
                    if cleaned[currentIndex] == "'" {
                        // Check if next char is comma or closing brace (end of value)
                        let nextIndex = cleaned.index(after: currentIndex)
                        if nextIndex >= cleaned.endIndex {
                            // End of string - this is the closing quote
                            let value = String(cleaned[cleaned.index(after: cleaned.startIndex)..<currentIndex])
                            return value.trimmingCharacters(in: .whitespaces)
                        }
                        let nextChar = cleaned[nextIndex]
                        if nextChar == "," || nextChar == "}" {
                            // This is the closing quote
                            let value = String(cleaned[cleaned.index(after: cleaned.startIndex)..<currentIndex])
                            return value.trimmingCharacters(in: .whitespaces)
                        }
                        // Otherwise it's a quote within the value (like 'R' in "Toys 'R' Us")
                        // Continue searching
                    }
                    currentIndex = cleaned.index(after: currentIndex)
                }
            } else {
                // Format: 'name': Retailer (no quotes around value, like 'name': Toys 'R' Us)
                // Extract until comma or closing brace
                var result = ""
                var currentIndex = cleaned.startIndex
                
                while currentIndex < cleaned.endIndex {
                    let char = cleaned[currentIndex]
                    if char == "," || char == "}" {
                        break
                    }
                    result.append(char)
                    currentIndex = cleaned.index(after: currentIndex)
                }
                
                return result.trimmingCharacters(in: .whitespaces)
            }
        }
        
        // If not dictionary format, return as-is (might be plain text)
        return exclusiveTo.trimmingCharacters(in: .whitespaces)
    }
    
    // Extract all retailer names from exclusiveTo field (handles multiple retailers)
    func extractAllRetailerNames(from exclusiveTo: String) -> [String] {
        guard !exclusiveTo.isEmpty else { return [] }
        
        var retailers: [String] = []
        var searchStart = exclusiveTo.startIndex
        
        // Find all occurrences of 'name': in the string
        while searchStart < exclusiveTo.endIndex {
            if let nameRange = exclusiveTo.range(of: "'name':", range: searchStart..<exclusiveTo.endIndex) {
                let afterName = String(exclusiveTo[nameRange.upperBound...])
                let cleaned = afterName.trimmingCharacters(in: .whitespaces)
                
                var retailerName = ""
                
                if cleaned.hasPrefix("'") {
                    // Format: 'name': 'Retailer'
                    var currentIndex = cleaned.index(after: cleaned.startIndex) // Skip opening quote
                    
                    while currentIndex < cleaned.endIndex {
                        if cleaned[currentIndex] == "'" {
                            let nextIndex = cleaned.index(after: currentIndex)
                            if nextIndex >= cleaned.endIndex {
                                retailerName = String(cleaned[cleaned.index(after: cleaned.startIndex)..<currentIndex])
                                        break
                                    }
                            let nextChar = cleaned[nextIndex]
                            if nextChar == "," || nextChar == "}" {
                                retailerName = String(cleaned[cleaned.index(after: cleaned.startIndex)..<currentIndex])
                                    break
                                }
                                }
                        currentIndex = cleaned.index(after: currentIndex)
                    }
                            } else {
                    // Format: 'name': Retailer (no quotes)
                    var currentIndex = cleaned.startIndex
                    while currentIndex < cleaned.endIndex {
                        let char = cleaned[currentIndex]
                        if char == "," || char == "}" {
                                break
                            }
                        retailerName.append(char)
                        currentIndex = cleaned.index(after: currentIndex)
                    }
                }
                
                let trimmed = retailerName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && !retailers.contains(trimmed) {
                    retailers.append(trimmed)
                }
                
                // Move search start past this match
                searchStart = nameRange.upperBound
            } else {
                break
            }
        }
        
        return retailers
    }
    
    // Search by UPC - search CSV database by UPC
    func searchByUPC(upc: String) async -> FunkoDatabaseResult? {
        // Load CSV database if needed
        await loadCSVDatabaseIfNeeded()
        
        // Search CSV for exact UPC match (only master variants, no autographed)
        let upcLower = upc.lowercased()
        var matchingRows: [CSVRow] = []
        
        for row in csvDatabase {
            // Filter out autographed pops - only show master/unique variants
            if row.isAutographed {
                continue
            }
            
            if row.upc.lowercased() == upcLower {
                matchingRows.append(row)
            }
        }
        
        // Prefer entry without exclusivity (master variant)
        if let masterRow = matchingRows.first(where: { row in
            let nameAndSeries = "\(row.name) \(row.series)".lowercased()
            return !nameAndSeries.contains("exclusive") && 
                   !nameAndSeries.contains("shared") &&
                   !nameAndSeries.contains("limited edition")
        }) {
            return convertCSVRowToResult(masterRow)
        }
        
        // Otherwise return first match
        if let firstRow = matchingRows.first {
            return convertCSVRowToResult(firstRow)
        }
        
        // Fallback to general search (which will also filter autographed)
        let results = await searchPops(query: upc, includeAutographed: false)
        return results.first
    }
    
    // Search by UPC - returns only master/unique variants (no autographed, no subvariants)
    func searchAllByUPC(upc: String) async -> [FunkoDatabaseResult] {
        // Load CSV database if needed
        await loadCSVDatabaseIfNeeded()
        
        let upcLower = upc.lowercased()
        var results: [FunkoDatabaseResult] = []
        
        for row in csvDatabase {
            // Filter out autographed pops - only show master/unique variants
            if row.isAutographed {
                continue
            }
            
            if row.upc.lowercased() == upcLower {
                results.append(convertCSVRowToResult(row))
            }
        }
        
        // Deduplicate by unique combination: number + exclusivity + features (productionStatus)
        // This allows showing different variants with same number (e.g., Standard #1982, Chase #1982, Gold #1982)
        var uniqueResults: [FunkoDatabaseResult] = []
        var seenKeys: Set<String> = []
        
        for result in results {
            // Create unique key: number + exclusivity + productionStatus (features)
            let exclusivityKey = result.exclusiveTo ?? ""
            let featuresKey = result.productionStatus ?? ""
            let uniqueKey = "\(result.number)|\(exclusivityKey)|\(featuresKey)"
            
            // Only add if we haven't seen this exact combination
            if !seenKeys.contains(uniqueKey) {
                uniqueResults.append(result)
                seenKeys.insert(uniqueKey)
            }
        }
        
        return uniqueResults
    }
    
    // Convert CSV row to FunkoDatabaseResult
    private func convertCSVRowToResult(_ row: CSVRow) -> FunkoDatabaseResult {
        // Extract production status (variants) from prod_status
        var productionStatus: String? = nil
        if !row.prodStatus.isEmpty {
            productionStatus = row.prodStatus
        }
        
        // Extract exclusivity from name or series
        var exclusivity: String? = nil
        let nameAndSeries = "\(row.name) \(row.series)".lowercased()
        
        // Check for exclusivity patterns
        let exclusivityPatterns = [
            "hot topic", "gamestop", "target", "walmart", "walmart exclusive",
            "amazon", "amazon exclusive", "barnes & noble", "barnes and noble",
            "boxlunch", "funko shop", "funko shop exclusive",
            "sdcc", "san diego comic con", "nycc", "new york comic con",
            "eccc", "emerald city comic con", "anime expo", "ax",
            "spring convention", "fall convention", "summer convention",
            "shared exclusive", "convention exclusive", "convention shared"
        ]
        
        for pattern in exclusivityPatterns {
            if nameAndSeries.contains(pattern) {
                exclusivity = pattern.capitalized
                break
            }
        }
        
        return FunkoDatabaseResult(
            name: row.name,
            number: row.number,
            series: row.series,
            imageURL: row.imageURL,
            productURL: nil,
            upc: row.upc.isEmpty ? nil : row.upc,
            releaseDate: row.releaseDate.isEmpty ? nil : row.releaseDate,
            category: row.category.isEmpty ? nil : row.category,
            exclusiveTo: exclusivity,
            source: "CSV Database",
            hdbid: row.hdbid.isEmpty ? nil : row.hdbid, // Preserve hdbid for hobbyDB subvariants!
            productionStatus: productionStatus
        )
    }
    
    // Helper: Extract pop number from title
    private func extractPopNumberFromTitle(_ title: String) -> String? {
        // Try pattern: #123
        if let regex = try? NSRegularExpression(pattern: "#(\\d{3,4})", options: []),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           let range = Range(match.range(at: 1), in: title) {
            return String(title[range])
        }
        
        // Try pattern: Pop! 123
        if let regex = try? NSRegularExpression(pattern: "(?i)pop!?\\s*(?:#)?(\\d{3,4})", options: []),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           let range = Range(match.range(at: 1), in: title) {
            return String(title[range])
        }
        
        return nil
    }
    
    // Helper: Extract series from title
    private func extractSeriesFromTitle(_ title: String) -> String {
        let titleLower = title.lowercased()
        
        // Common series patterns
        if titleLower.contains("dragon ball") || titleLower.contains("dbz") || titleLower.contains("dbgt") {
            return "Dragon Ball"
        } else if titleLower.contains("solo leveling") {
            return "Solo Leveling"
        } else if titleLower.contains("demon slayer") {
            return "Demon Slayer"
        } else if titleLower.contains("naruto") {
            return "Naruto"
        } else if titleLower.contains("one piece") {
            return "One Piece"
        } else if titleLower.contains("marvel") {
            return "Marvel"
        } else if titleLower.contains("dc") || titleLower.contains("batman") || titleLower.contains("superman") {
            return "DC Comics"
        } else if titleLower.contains("star wars") {
            return "Star Wars"
        } else if titleLower.contains("disney") {
            return "Disney"
        }
        
        return "Funko Pop!"
    }
    
    // Detailed Pop information from product page
    struct EbayListing: Identifiable {
        let id: String
        let title: String
        let price: Double
        let imageURL: String
        let itemURL: String
        let condition: String?
    }
    
    // Sticker variant information
    struct StickerVariant: Identifiable {
        let id: String  // URL as ID
        let url: String
        let stickers: [String]
        let displayName: String  // e.g., "NYCC Exclusive", "Shared Exclusive", "Common"
        
        init(url: String, stickers: [String], displayName: String) {
            self.id = url
            self.url = url
            self.stickers = stickers
            self.displayName = displayName
        }
    }
    
    struct PopDetailInfo {
        let name: String
        let number: String
        let stickers: [String]  // Chase, Glows in the Dark, etc.
        let variations: Int
        let character: String
        let releaseDate: String
        let category: String
        let tvShowCollection: String
        let show: String
        let size: String
        let variationURLs: [String]  // URLs to other sticker variants
        let productURL: String  // Current product URL
        let vinylType: String  // Vinyl Figure or Bobble-Head
        let mediaFranchise: String
        let estimatedValue: Double?
        let priceTrend: String?
        let monthlyVolume: String?
        let imageURL: String
        let ebayListings: [EbayListing]  // Active eBay listings
        let recentSales: [SaleListing]?  // Recent completed sales
        
        // Check if this detail info has any meaningful data
        var hasData: Bool {
            return !stickers.isEmpty ||
                   variations > 0 ||
                   !character.isEmpty ||
                   !releaseDate.isEmpty ||
                   !category.isEmpty ||
                   !tvShowCollection.isEmpty ||
                   !show.isEmpty ||
                   !size.isEmpty ||
                   !vinylType.isEmpty ||
                   !mediaFranchise.isEmpty ||
                   estimatedValue != nil ||
                   priceTrend != nil ||
                   monthlyVolume != nil
        }
    }
    
    // Fetch Pop details from URL
    func fetchPopDetails(from url: String, displayName: String? = nil, skipEbay: Bool = false) async -> PopDetailInfo? {
        // print("🔍 Fetching Pop details from: \(url)")
        guard let productURL = URL(string: url) else {
            print("❌ Invalid URL: \(url)")
            return nil
        }
        
        var request = URLRequest(url: productURL)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        let acceptHeader = "text/html,application/xhtml+xml,application/xml;q=0.9," + "*" + "/" + "*;q=0.8"
        request.setValue(acceptHeader, forHTTPHeaderField: "Accept")
                request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://hobbydb.com", forHTTPHeaderField: "Referer")
                request.timeoutInterval = 15.0
                
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ No HTTP response")
                return nil
            }
            
            // print("📡 HTTP Status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                print("❌ Bad status code or no HTML")
                return nil
            }
            
            // print("✅ Got HTML, length: \(html.count)")
            
            let doc = try SwiftSoup.parse(html)
            
            // Extract name from title or h1
            var name = ""
            if let title = try? doc.select("title").first()?.text(), !title.isEmpty {
                // Clean title - remove site-specific suffixes
                name = title.replacingOccurrences(of: " | POP's Today", with: "")
                           .replacingOccurrences(of: " | Original Series", with: "")
                           .replacingOccurrences(of: " | Database", with: "")
                           .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if name.isEmpty {
                if let h1 = try? doc.select("h1").first()?.text(), !h1.isEmpty {
                    name = h1
                }
            }
            
            // Extract number from URL or title
            var number = ""
            if url.contains("/animation/") {
                let urlParts = url.components(separatedBy: "/animation/")
                if urlParts.count > 1 {
                    let slug = urlParts[1].components(separatedBy: "?")[0]
                    let slugParts = slug.components(separatedBy: "-")
                    if let firstPart = slugParts.first, let num = Int(firstPart) {
                        number = String(num)
                    }
                }
            }
            if number.isEmpty {
                if let numMatch = name.range(of: #"#(\d{3,4})"#, options: .regularExpression) {
                    let matchStr = String(name[numMatch])
                    if let numRange = matchStr.range(of: #"\d{3,4}"#, options: .regularExpression) {
                        number = String(matchStr[numRange])
                    }
                }
            }
            
            // Helper to find value in JSON structure
            func findValueInJSON(_ json: [String: Any], for label: String) -> String? {
                let labelLower = label.lowercased()
                
                // Common mappings
                let keyMappings: [String: [String]] = [
                    "character": ["character", "name", "characterName"],
                    "release date": ["releaseDate", "datePublished", "releaseDate"],
                    "category": ["category", "genre", "type"],
                    "show": ["show", "series", "tvShow"],
                    "size": ["size", "dimensions"],
                    "media franchise": ["franchise", "mediaFranchise", "brand"],
                ]
                
                // Try direct key match
                if let keys = keyMappings[labelLower] {
                    for key in keys {
                        if let value = json[key] as? String, !value.isEmpty {
                            return value
                        }
                    }
                }
                
                // Recursively search in nested dictionaries
                for (_, value) in json {
                    if let dict = value as? [String: Any],
                       let found = findValueInJSON(dict, for: label) {
                        return found
                    }
                }
                
                return nil
            }
            
            // Helper function to extract value from table row
            func extractTableValue(for label: String) -> String {
                print("   🔍 extractTableValue: Looking for '\(label)'")
                
                // Try table rows first - use the full document
                if let rows = try? doc.select("tr") {
                    print("   🔍 extractTableValue: Found \(rows.count) table rows")
                    for row in rows {
                        // Check all cells in the row
                        if let cells = try? row.select("td, th"), cells.count > 0 {
                            // Convert to array for easier indexing
                            let cellsArray = Array(cells)
                            for (index, cell) in cellsArray.enumerated() {
                                if let cellText = try? cell.text() {
                                    let cellTextLower = cellText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                                    let labelLower = label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                                    if cellTextLower == labelLower || cellTextLower.contains(labelLower) {
                                        print("   🔍 Table: Found label '\(label)' in cell \(index) with text: '\(cellText)'")
                                        // Value might be in next cell
                                        if index + 1 < cellsArray.count {
                                        let valueCell = cellsArray[index + 1]
                                        print("   🔍 Table: Checking next cell \(index + 1)")
                                        
                                        // Try span with itemprop="name" first (most specific)
                                        if let link = try? valueCell.select("a").first() {
                                            if let span = try? link.select("span[itemprop='name']").first(),
                                               let spanText = try? span.text(),
                                               !spanText.isEmpty {
                                                let cleaned = spanText.trimmingCharacters(in: .whitespacesAndNewlines)
                                                if !cleaned.isEmpty && cleaned.lowercased() != label.lowercased() {
                                                    print("   ✅ Found '\(label)' in table (span itemprop): '\(cleaned)'")
                                                    return cleaned
                                                }
                                            }
                                            // Fallback to link text
                                            if let linkText = try? link.text(),
                                               !linkText.isEmpty {
                                                let cleaned = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
                                                if !cleaned.isEmpty && cleaned.lowercased() != label.lowercased() {
                                                    print("   ✅ Found '\(label)' in table (link text): '\(cleaned)'")
                                                    return cleaned
                                                }
                                            }
                                        }
                                        
                                        // Try span directly in the cell (for cases like Release Date with just <span>2025</span>)
                                        if let span = try? valueCell.select("span").first(),
                                           let spanText = try? span.text(),
                                           !spanText.isEmpty {
                                            let cleaned = spanText.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if !cleaned.isEmpty && cleaned.lowercased() != label.lowercased() {
                                                print("   ✅ Found '\(label)' in table (span): '\(cleaned)'")
                                                return cleaned
                                            }
                                        }
                                        
                                        // Try to get text from the cell (which includes links)
                                        if let valueText = try? valueCell.text(),
                                           !valueText.isEmpty {
                                            let cleaned = valueText.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if !cleaned.isEmpty && cleaned.lowercased() != label.lowercased() {
                                                print("   ✅ Found '\(label)' in table (next cell text): '\(cleaned)'")
                                                return cleaned
                                            }
                                        }
                                        
                                        print("   ⚠️ Table: Could not extract value from next cell for '\(label)'")
                                        } else {
                                            print("   ⚠️ Table: No next cell available for '\(label)' (index \(index), total cells: \(cellsArray.count))")
                                        }
                                        // Or value might be in a link within the same cell
                                        if let link = try? cell.select("a").first(),
                                           let linkText = try? link.text(),
                                           !linkText.isEmpty && linkText.lowercased() != label.lowercased() {
                                            let cleaned = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if !cleaned.isEmpty {
                                                print("   ✅ Found '\(label)' in link (same cell): '\(cleaned)'")
                                                return cleaned
                        }
                      }
                    }
                  }
                }
              }
            }
                }
                
                // Try definition lists (dl/dt/dd)
                if let dts = try? doc.select("dt") {
                    for dt in dts {
                        if let labelText = try? dt.text(),
                           labelText.lowercased().contains(label.lowercased()) {
                            // Get next dd element
                            if let nextSibling = try? dt.nextElementSibling(),
                               nextSibling.tagName() == "dd",
                               let valueText = try? nextSibling.text() {
                                let cleaned = valueText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !cleaned.isEmpty {
                                    print("   ✅ Found '\(label)' in dl: '\(cleaned)'")
                                    return cleaned
                                }
                            }
                        }
                    }
                }
                
                // Try div-based structures - look for divs containing the label (exclude nav)
                if let elements = try? doc.select("div, span, p, li, strong, b, label") {
                    for element in elements {
                        // Skip navigation elements
                        if let className = try? element.className(),
                           className.contains("nav") || className.contains("dropdown") || 
                           className.contains("menu") || className.contains("navbar") {
                continue
            }
            
                        if let elementText = try? element.text(),
                           elementText.lowercased().contains(label.lowercased()) {
                            // Try to find value in the same element (after colon)
                            if let colonRange = elementText.range(of: ":"),
                               colonRange.upperBound < elementText.endIndex {
                                let afterColon = String(elementText[colonRange.upperBound...])
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                if !afterColon.isEmpty && afterColon != label && afterColon.count < 200 {
                                    print("   ✅ Found '\(label)' in same element: '\(afterColon)'")
                                    return afterColon
                                }
                            }
                            
                            // Look for value in next sibling (try multiple next siblings)
                            for _ in 1...3 {
                                if let nextSibling = try? element.nextElementSibling(),
                                   let valueText = try? nextSibling.text() {
                                    let cleaned = valueText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !cleaned.isEmpty && cleaned != elementText && cleaned.count < 200 {
                                        // Check if it's not just another label
                                        let commonLabels = ["character", "release date", "category", "show", "size", "variations"]
                                        if !commonLabels.contains(where: { cleaned.lowercased().contains($0) }) {
                                            print("   ✅ Found '\(label)' in next sibling: '\(cleaned)'")
                                            return cleaned
                                        }
                                    }
                                }
                            }
                            
                            // Look for value in a child element (like a link or span)
                            if let childLink = try? element.select("a").first(),
                               let linkText = try? childLink.text(),
                               !linkText.isEmpty && linkText.lowercased() != label.lowercased() && linkText.count < 200 {
                                print("   ✅ Found '\(label)' in child link: '\(linkText)'")
                                return linkText.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            
                            // Look for value in parent's next sibling
                            if let parent = element.parent(),
                               let parentNext = try? parent.nextElementSibling(),
                               let valueText = try? parentNext.text() {
                                let cleaned = valueText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !cleaned.isEmpty && cleaned.count < 200 {
                                    print("   ✅ Found '\(label)' in parent's next sibling: '\(cleaned)'")
                                    return cleaned
                                }
                            }
                        }
                    }
                }
                
                // Try looking for text patterns like "Character: Value" or "Release Date: Value"
                // Focus on main content area, not navigation
                var bodyTextToSearch = ""
                if let mainContent = try? doc.select("main, article, [role='main'], .content, .main-content, #content, #main, .container").first(),
                   let contentText = try? mainContent.text() {
                    bodyTextToSearch = contentText
                } else if let body = doc.body(),
                          let bodyText = try? body.text() {
                    bodyTextToSearch = bodyText
                }
                
                if !bodyTextToSearch.isEmpty {
                    // More specific pattern that looks for the label followed by colon and value
                    let patterns = [
                        "\(label)\\s*[:]\\s*([^\\n<]+?)(?:\\n|$)",  // Label: Value (same line, stop at newline or end)
                        "\(label)\\s*[:]\\s*([A-Za-z0-9\\s\\-]+)",  // Label: Value (alphanumeric with spaces/hyphens)
                    ]
                    
                    for pattern in patterns {
                        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                           let match = regex.firstMatch(in: bodyTextToSearch, range: NSRange(bodyTextToSearch.startIndex..., in: bodyTextToSearch)),
                           match.numberOfRanges > 1,
                           let valueRange = Range(match.range(at: 1), in: bodyTextToSearch) {
                            let value = String(bodyTextToSearch[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            // Filter out common false positives and validate
                            if !value.isEmpty && 
                               value.count > 1 &&
                               value.count < 200 &&
                               !value.lowercased().contains("checklist") &&
                               !value.lowercased().contains("show all") &&
                               !value.lowercased().contains("dropdown") &&
                               !value.lowercased().contains("menu") &&
                               !value.lowercased().contains("nav") &&
                               value.lowercased() != label.lowercased() {
                                // Additional validation - make sure it's not just navigation text
                                let invalidValues = ["categories", "shows", "movies", "franchises", "stickers", "explore", "all pop"]
                                if !invalidValues.contains(where: { value.lowercased().contains($0) }) {
                                    print("   ✅ Found '\(label)' via regex: '\(value)'")
                                    return value
                                }
                            }
                        }
                    }
                }
                
                // Try looking in the raw HTML for patterns
                if let body = doc.body(),
                   let bodyHtml = try? body.html() {
                    // Look for patterns like <strong>Character</strong>: <a>Value</a> or <td>Character</td><td>Value</td>
                    let htmlPatterns = [
                        "<[^>]*>\(label)[^<]*</[^>]*>\\s*[:]?\\s*<[^>]*>([^<]+)</[^>]*>",
                        "<td[^>]*>\(label)[^<]*</td>\\s*<td[^>]*>([^<]+)</td>",
                        "<dt[^>]*>\(label)[^<]*</dt>\\s*<dd[^>]*>([^<]+)</dd>",
                    ]
                    
                    for pattern in htmlPatterns {
                        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                            let nsRange = NSRange(location: 0, length: bodyHtml.utf16.count)
                            if let match = regex.firstMatch(in: bodyHtml, range: nsRange),
                               match.numberOfRanges > 1,
                               let valueRange = Range(match.range(at: 1), in: bodyHtml) {
                                var value = String(bodyHtml[valueRange])
                                // Remove any remaining HTML tags
                                value = value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                                value = value.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !value.isEmpty && value.count < 200 && value.lowercased() != label.lowercased() {
                                    print("   ✅ Found '\(label)' in HTML: '\(value)'")
                                    return value
                            }
                        }
                    }
                }
            }
            
                // Try to find data in script tags (JSON-LD or other structured data)
            if let scripts = try? doc.select("script[type='application/ld+json']") {
                for script in scripts {
                    if let jsonText = try? script.html(),
                       let jsonData = jsonText.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                            // Look for the label in the JSON structure
                            if let value = findValueInJSON(json, for: label) {
                                print("   ✅ Found '\(label)' in JSON-LD: '\(value)'")
                                return value
                            }
                        }
                    }
                }
                
                print("   ⚠️ Could not find '\(label)'")
                return ""
            }
            
            // Extract stickers (Chase, Glows in the Dark, etc.)
            var stickers: [String] = []
            print("   🔍 Looking for Stickers section...")
            
            // Look in the Stickers row - extract all stickers from badges and spans
            // Try multiple selectors to find the sticker row
            var stickerRow: Element? = nil
            var valueTd: Element? = nil
            
            // Try exact match first (escape apostrophe)
            if let row = try? doc.select("td:contains('POP\\'s Today Stickers')").first()?.parent() {
                stickerRow = row
                print("   ✅ Found sticker row using exact match")
            } else if let row = try? doc.select("td:contains('Stickers'), td:contains('Features'), td:contains('POP's Today Stickers')").first()?.parent() {
                stickerRow = row
                print("   ✅ Found sticker row using unescaped match")
            } else {
                // Try finding by searching all table rows
                if let rows = try? doc.select("tr") {
                    for row in rows {
                        if let rowText = try? row.text(), rowText.contains("POP") && rowText.contains("Stickers") {
                            stickerRow = row
                            print("   ✅ Found sticker row by searching all rows")
                            break
                        }
                    }
                }
            }
            
            if let row = stickerRow {
                if let cells = try? row.select("td"), cells.count >= 2 {
                    valueTd = cells.get(1)
                    print("   ✅ Found value cell with \(cells.count) cells")
                } else {
                    let cellCount = (try? row.select("td").count) ?? 0
                    print("   ⚠️ Could not find value cell in sticker row (cells: \(cellCount))")
                }
            } else {
                print("   ⚠️ Could not find sticker row")
            }
            
            if let valueTd = valueTd {
                print("   🔍 Extracting stickers from value cell...")
                
                // First, get all spans with itemprop="name" (these contain the full sticker names)
                // This should be done first because badges might contain abbreviated text
                if let spans = try? valueTd.select("span[itemprop='name']") {
                    print("   🔍 Found \(spans.count) spans with itemprop='name'")
                    for span in spans {
                        if let spanText = try? span.text(), !spanText.isEmpty {
                            let cleaned = spanText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !cleaned.isEmpty && cleaned.count < 100 && !stickers.contains(cleaned) {
                                stickers.append(cleaned)
                                print("   ✅ Added sticker from span: '\(cleaned)'")
                            }
                        }
                    }
                } else {
                    print("   ⚠️ No spans with itemprop='name' found")
                }
                
                // Then get all badge buttons (they contain sticker text, but might be abbreviated)
                // Only add if not already in stickers array
                if let badges = try? valueTd.select("button.badge") {
                    print("   🔍 Found \(badges.count) badge buttons")
                    for badge in badges {
                        if let badgeText = try? badge.text(), !badgeText.isEmpty {
                            let cleaned = badgeText.trimmingCharacters(in: .whitespacesAndNewlines)
                            // Skip if this badge text is already in stickers (might be from span)
                            if !cleaned.isEmpty && cleaned.count < 100 && !stickers.contains(cleaned) {
                                // Also check if any existing sticker contains this text (to avoid duplicates like "PLUS" vs "PLUS Exclusive")
                                let isDuplicate = stickers.contains { existing in
                                    existing.lowercased() == cleaned.lowercased() ||
                                    existing.lowercased().contains(cleaned.lowercased()) ||
                                    cleaned.lowercased().contains(existing.lowercased())
                                }
                                if !isDuplicate {
                                    stickers.append(cleaned)
                                    print("   ✅ Added sticker from badge: '\(cleaned)'")
                                }
                            }
                        }
                    }
                } else {
                    print("   ⚠️ No badge buttons found")
                }
                // Also check links for sticker text
                if let links = try? valueTd.select("a.sticker-link, a[href*='fstk=']") {
                    for link in links {
                        // Check title attribute for sticker name
                        if let title = try? link.attr("title"), !title.isEmpty {
                            // Extract sticker name from title (e.g., "View Fall Convention Limited Edition Funko POP! figures")
                            let titleLower = title.lowercased()
                            if titleLower.contains("view") && titleLower.contains("funko pop") {
                                // Try to extract the sticker name
                                if let range = title.range(of: "View ") {
                                    let afterView = String(title[range.upperBound...])
                                    if let endRange = afterView.range(of: " Funko POP") {
                                        let stickerName = String(afterView[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                                        if !stickerName.isEmpty && !stickers.contains(stickerName) {
                                            stickers.append(stickerName)
                                        }
                                    }
                                }
                            }
                        }
                        // Also check link text
                        if let linkText = try? link.text(), !linkText.isEmpty {
                            let cleaned = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !cleaned.isEmpty && cleaned.count < 100 && !stickers.contains(cleaned) {
                                stickers.append(cleaned)
                            }
                        }
                    }
                }
                // If still no stickers, try extracting from href parameters
                if stickers.isEmpty {
                    if let links = try? valueTd.select("a[href*='fstk=']") {
                        for link in links {
                            if let href = try? link.attr("href"), !href.isEmpty {
                                // Extract sticker from fstk parameter
                                if let fstkRange = href.range(of: "fstk=") {
                                    let afterFstk = String(href[fstkRange.upperBound...])
                                    if let endRange = afterFstk.range(of: "&") ?? afterFstk.range(of: "#") {
                                        let stickerParam = String(afterFstk[..<endRange.lowerBound])
                                        let decoded = stickerParam.replacingOccurrences(of: "+", with: " ")
                                            .replacingOccurrences(of: "%28", with: "(")
                                            .replacingOccurrences(of: "%29", with: ")")
                                            .removingPercentEncoding ?? stickerParam
                                        if !decoded.isEmpty && !stickers.contains(decoded) {
                                            stickers.append(decoded)
                                        }
                                    } else {
                                        let decoded = afterFstk.replacingOccurrences(of: "+", with: " ")
                                            .replacingOccurrences(of: "%28", with: "(")
                                            .replacingOccurrences(of: "%29", with: ")")
                                            .removingPercentEncoding ?? afterFstk
                                        if !decoded.isEmpty && !stickers.contains(decoded) {
                                            stickers.append(decoded)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // Also check title for common stickers
            let titleLower = name.lowercased()
            if titleLower.contains("chase") && !stickers.contains(where: { $0.lowercased().contains("chase") }) {
                stickers.append("Chase")
                print("   ✅ Added 'Chase' from title")
            }
            if (titleLower.contains("glows in the dark") || titleLower.contains("glow")) && !stickers.contains(where: { $0.lowercased().contains("glow") }) {
                stickers.append("Glows in the Dark")
                print("   ✅ Added 'Glows in the Dark' from title")
            }
            
            print("   📦 Final stickers array: \(stickers)")
            
            // Extract variations count and check for variation links
            var variations = 0
            var variationURLs: [String] = [] // URLs to other sticker variants
            
            let variationsText = extractTableValue(for: "Variations")
            if !variationsText.isEmpty {
                let cleaned = variationsText.replacingOccurrences(of: " Variants", with: "")
                                           .replacingOccurrences(of: " Variant", with: "")
                                           .trimmingCharacters(in: .whitespacesAndNewlines)
                if let count = Int(cleaned) {
                    variations = count
                }
                
                // Try to find variation links (different sticker variants)
                if let variationsRow = try? doc.select("td:contains('Variations')").first()?.parent(),
                   let valueTd = try? variationsRow.select("td").get(1) {
                    // Look for links to other variants
                    if let links = try? valueTd.select("a[href*='/animation/']") {
                        for link in links {
                            if let href = try? link.attr("href"), !href.isEmpty {
                                var fullURL = href
                                if fullURL.hasPrefix("/") {
                                    fullURL = "https://hobbydb.com" + fullURL
                                } else if !fullURL.hasPrefix("http") {
                                    fullURL = "https://hobbydb.com/" + fullURL
                                }
                                if !variationURLs.contains(fullURL) {
                                    variationURLs.append(fullURL)
                                }
                            }
                        }
                    }
                }
            }
            
            print("   📦 Found \(variations) variations, \(variationURLs.count) variation URLs")
            
            // Extract character
            var character = extractTableValue(for: "Character")
            // Remove HTML tags if any
            if character.contains("<") {
                if let charElement = try? doc.select("td:contains('Character')").first()?.parent()?.select("td").get(1),
                   let charLink = try? charElement.select("a").first(),
                   let charText = try? charLink.text() {
                    character = charText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Extract release date
            var releaseDate = extractTableValue(for: "Release Date")
            // Remove HTML tags if any
            if releaseDate.contains("<") {
                if let dateElement = try? doc.select("td:contains('Release Date')").first()?.parent()?.select("td").get(1),
                   let dateLink = try? dateElement.select("a").first(),
                   let dateText = try? dateLink.text() {
                    releaseDate = dateText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            // Also check meta tags
            if releaseDate.isEmpty {
                if let metaDate = try? doc.select("meta[property='twitter:data2']").first()?.attr("content"), !metaDate.isEmpty {
                    releaseDate = metaDate
                }
            }
            
            // Extract category
            var category = extractTableValue(for: "Category")
            // Remove HTML tags if any
            if category.contains("<") {
                if let catElement = try? doc.select("td:contains('Category')").first()?.parent()?.select("td").get(1),
                   let catLink = try? catElement.select("a").first(),
                   let catText = try? catLink.text() {
                    category = catText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            // Also check meta tags
            if category.isEmpty {
                if let metaCat = try? doc.select("meta[property='twitter:data1']").first()?.attr("content"), !metaCat.isEmpty {
                    category = metaCat
                }
            }
            
            // Extract TV Show Collection
            var tvShowCollection = extractTableValue(for: "TV Show Collection")
            // Remove HTML tags if any
            if tvShowCollection.contains("<") {
                if let collectionElement = try? doc.select("td:contains('TV Show Collection')").first()?.parent()?.select("td").get(1),
                   let collectionLink = try? collectionElement.select("a").first(),
                   let collectionText = try? collectionLink.text() {
                    tvShowCollection = collectionText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Extract show
            let show = extractTableValue(for: "Show")
            
            // Extract size
            let size = extractTableValue(for: "Size")
            
            // Extract UPC from barcode JavaScript or table
            var upc: String? = nil
            // Try to find UPC in barcode JavaScript: JsBarcode("#barcode_single_21129", "889698893237", {
            if let barcodeScript = try? doc.select("script:contains('JsBarcode')").first()?.html() {
                let upcPattern = #"JsBarcode\([^,]+,\s*"(\d{12})""#
                if let regex = try? NSRegularExpression(pattern: upcPattern),
                   let match = regex.firstMatch(in: barcodeScript, range: NSRange(barcodeScript.startIndex..., in: barcodeScript)),
                   let range = Range(match.range(at: 1), in: barcodeScript) {
                    upc = String(barcodeScript[range])
                    print("   📦 Found UPC in barcode script: \(upc ?? "")")
                }
            }
            // Also try table value
            if upc == nil || upc!.isEmpty {
                let upcTableValue = extractTableValue(for: "UPC")
                if !upcTableValue.isEmpty {
                    // Extract just the digits
                    let upcDigits = upcTableValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    if upcDigits.count >= 12 {
                        upc = upcDigits
                        print("   📦 Found UPC in table: \(upc ?? "")")
                    }
                }
            }
            
            // Extract vinyl type
            var vinylType = extractTableValue(for: "Vinyl Figure")
            if vinylType.isEmpty {
                vinylType = extractTableValue(for: "Bobble-Head")
            }
            
            // Extract media franchise
            let mediaFranchise = extractTableValue(for: "Media Franchise")
            
            // Calculate estimated value - use eBay API if credentials exist
            var estimatedValue: Double? = nil
            var priceTrend: String? = nil
            var monthlyVolume: String? = nil
            
            // Check if eBay API credentials are saved
            let keychain = KeychainHelper.shared
            let hasEbayCredentials = !(keychain.get(key: "ebay_client_id") ?? "").isEmpty &&
                                     !(keychain.get(key: "ebay_client_secret") ?? "").isEmpty
            
            if hasEbayCredentials && !skipEbay {
                // Use eBay API to get estimated value from sales
                print("   💰 eBay API credentials found - fetching from eBay sales")
                
                // Build search query for eBay - optimize for better matching
                var searchQuery = "funko pop"
                
                // Add character name if available (most specific)
                if !character.isEmpty {
                    searchQuery += " \(character)"
                } else {
                    // Fallback to name if no character
                    let cleanName = name.replacingOccurrences(of: "Funko Pop! ", with: "", options: .caseInsensitive)
                                       .replacingOccurrences(of: "Pop! ", with: "", options: .caseInsensitive)
                                       .replacingOccurrences(of: "Funko Pop ", with: "", options: .caseInsensitive)
                    searchQuery += " \(cleanName)"
                }
                
                // Add number if available for exact matching
                if !number.isEmpty {
                    searchQuery += " #\(number)"
                }
                
                print("   💰 Fetching eBay sales data for: '\(searchQuery)'")
                
                // Fetch average price from eBay sales
                let priceResult = await PriceFetcher().fetchAveragePrice(for: searchQuery, upc: nil, includeSales: false)
                
                if let result = priceResult {
                    estimatedValue = result.averagePrice
                    monthlyVolume = "\(result.saleCount) sales"
                    
                    // Format price trend
                    if result.trend != 0 {
                        let trendSign = result.trend > 0 ? "+" : ""
                        priceTrend = "\(trendSign)\(String(format: "%.1f", result.trend))%"
                    } else {
                        priceTrend = "No change"
                    }
                    
                    print("   ✅ eBay data: $\(String(format: "%.2f", result.averagePrice)) (from \(result.saleCount) sales)")
                } else {
                    print("   ⚠️ No eBay sales data found")
                    
                    // Fallback to HTML value if eBay API fails
                    let valueText = extractTableValue(for: "Estimated Value")
                    if !valueText.isEmpty {
                        let cleaned = valueText.replacingOccurrences(of: "$", with: "")
                                               .replacingOccurrences(of: ",", with: "")
                                               .replacingOccurrences(of: "(USD)", with: "", options: .caseInsensitive)
                                               .trimmingCharacters(in: .whitespacesAndNewlines)
                        estimatedValue = Double(cleaned)
                    }
                }
            } else {
                // No eBay credentials - use HTML value
                print("   💰 No eBay API credentials - using page value")
                
                let valueText = extractTableValue(for: "Estimated Value")
                if !valueText.isEmpty {
                    let cleaned = valueText.replacingOccurrences(of: "$", with: "")
                                           .replacingOccurrences(of: ",", with: "")
                                           .replacingOccurrences(of: "(USD)", with: "", options: .caseInsensitive)
                                           .trimmingCharacters(in: .whitespacesAndNewlines)
                    estimatedValue = Double(cleaned)
                }
                
                // Also get price trend and monthly volume from page
                let trendText = extractTableValue(for: "Price Trend")
                if !trendText.isEmpty {
                    priceTrend = trendText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                let volumeText = extractTableValue(for: "Monthly Volume")
                if !volumeText.isEmpty {
                    monthlyVolume = volumeText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            
            print("✅ Extracted details - Character: '\(character)', Category: '\(category)', Release Date: '\(releaseDate)', Variations: \(variations)")
            
            // Extract image URL
            var imageURL = ""
            if let ogImage = try? doc.select("meta[property='og:image']").first()?.attr("content"), !ogImage.isEmpty {
                imageURL = ogImage
            } else if let img = try? doc.select("img[src*='POP_ANIMATION'], img[src*='Animation'], img[src*='hobbydb']").first(), let src = try? img.attr("src"), !src.isEmpty {
                // Use absolute URL if available, otherwise construct from base URL
                if src.hasPrefix("http") {
                    imageURL = src
                } else if let baseURL = URL(string: url), let absoluteURL = URL(string: src, relativeTo: baseURL) {
                    imageURL = absoluteURL.absoluteString
                } else {
                    imageURL = src
                }
            }
            
            // Fetch eBay listings if credentials are available
            var ebayListings: [EbayListing] = []
            if hasEbayCredentials {
                print("   📦 Fetching active eBay listings...")
                // Use display name if provided (includes variant info), otherwise use extracted name + stickers
                var searchName = displayName ?? name
                if searchName == name && !stickers.isEmpty {
                    // Add sticker info to search query (e.g., "Chase", "Glows in the Dark")
                    let stickerKeywords = stickers.joined(separator: " ")
                    searchName = "\(name) \(stickerKeywords)"
                }
                ebayListings = await fetchEbayListings(for: searchName, number: number, character: character)
                print("   ✅ Found \(ebayListings.count) eBay listings for '\(searchName)'")
            }
            
            // Fetch variation URLs (other sticker variants) if found - DISABLED to prevent freezing
            // if !variationURLs.isEmpty {
            //     print("   🔍 Found \(variationURLs.count) variation URLs, fetching sticker variants...")
            //     // Note: We'll fetch these in the search function to add them as separate results
            // }
            
            return PopDetailInfo(
                name: name,
                number: number,
                stickers: stickers,
                variations: variations,
                character: character,
                releaseDate: releaseDate,
                category: category,
                tvShowCollection: tvShowCollection,
                show: show,
                size: size,
                variationURLs: variationURLs,
                productURL: url,
                vinylType: vinylType,
                mediaFranchise: mediaFranchise,
                estimatedValue: estimatedValue,
                priceTrend: priceTrend,
                monthlyVolume: monthlyVolume,
                imageURL: imageURL,
                ebayListings: ebayListings,
                recentSales: nil  // Not fetching sales for this legacy method
            )
        } catch {
            print("❌ Error fetching Pop details from \(url): \(error.localizedDescription)")
            return nil
        }
    }
    
    // Lightweight function to fetch only stickers from a URL (no eBay data)
    func fetchStickersOnly(from url: String) async -> [String] {
        do {
            // Check for cancellation
            try Task.checkCancellation()
            
            var request = URLRequest(url: URL(string: url)!)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10.0 // 10 second timeout
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }
            
            guard let html = String(data: data, encoding: .utf8),
                  let doc = try? SwiftSoup.parse(html) else {
                return []
            }
            
            // Extract stickers only (same logic as fetchPopDetails but without eBay)
            var stickers: [String] = []
            
            // Look for sticker row
            var stickerRow: Element? = nil
            if let row = try? doc.select("td:contains('POP\\'s Today Stickers')").first()?.parent() {
                stickerRow = row
            } else if let row = try? doc.select("td:contains('Stickers'), td:contains('Features'), td:contains('POP's Today Stickers')").first()?.parent() {
                stickerRow = row
            } else if let rows = try? doc.select("tr") {
                for row in rows {
                    if let rowText = try? row.text(), rowText.contains("POP") && rowText.contains("Stickers") {
                        stickerRow = row
                        break
                    }
                }
            }
            
            if let row = stickerRow,
               let cells = try? row.select("td"),
               cells.count >= 2 {
                let valueTd = cells.get(1)
                // Get spans with itemprop="name"
                if let spans = try? valueTd.select("span[itemprop='name']") {
                    for span in spans {
                        if let spanText = try? span.text(), !spanText.isEmpty {
                            let cleaned = spanText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !cleaned.isEmpty && cleaned.count < 100 && !stickers.contains(cleaned) {
                                stickers.append(cleaned)
                            }
                        }
                    }
                }
                // Get badge buttons
                if let badges = try? valueTd.select("button.badge") {
                    for badge in badges {
                        if let badgeText = try? badge.text(), !badgeText.isEmpty {
                            let cleaned = badgeText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !cleaned.isEmpty && cleaned.count < 100 && !stickers.contains(cleaned) {
                                let isDuplicate = stickers.contains { existing in
                                    existing.lowercased() == cleaned.lowercased() ||
                                    existing.lowercased().contains(cleaned.lowercased()) ||
                                    cleaned.lowercased().contains(existing.lowercased())
                                }
                                if !isDuplicate {
                                    stickers.append(cleaned)
                                }
                            }
                        }
                    }
                }
            }
            
            return stickers
        } catch {
            print("   ⚠️ Error fetching stickers from \(url): \(error.localizedDescription)")
            return []
        }
    }
    
    // Fetch all sticker variants for a Pop (including current one) - DISABLED: no variants needed
    func fetchAllStickerVariants(for popNumber: String, currentURL: String) async -> [StickerVariant] {
        // Return empty array immediately - variants are not needed
        return []
    }
    
    
    // Fetch active eBay listings for a Pop
    private func fetchEbayListings(for name: String, number: String, character: String) async -> [EbayListing] {
        guard let accessToken = await EbayOAuthService.shared.getAccessToken() else {
            print("   ⚠️ No eBay token available for listings")
            return []
        }
        
        // Build search query - ALWAYS use the name parameter (includes variant info like "Chase", "Glows in the Dark")
        // The name parameter is the full display name with variant info, which is what we want
        var searchQuery = "funko pop"
        
        // Clean the name (remove "Funko Pop!" prefixes if any)
        var cleanName = name.replacingOccurrences(of: "Funko Pop! ", with: "", options: .caseInsensitive)
                           .replacingOccurrences(of: "Pop! ", with: "", options: .caseInsensitive)
                           .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove parentheses and replace with spaces for better eBay search
        // eBay search works better with "Chase" instead of "(Chase)"
        cleanName = cleanName.replacingOccurrences(of: "(", with: " ")
                            .replacingOccurrences(of: ")", with: " ")
                            .replacingOccurrences(of: "  ", with: " ") // Remove double spaces
                            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Use the full name (includes variant info like "Chase", "Glows in the Dark")
        searchQuery += " \(cleanName)"
        
        // Add number for exact matching
        if !number.isEmpty {
            searchQuery += " #\(number)"
        }
        
        print("   🔍 eBay search query: '\(searchQuery)'")
        
        guard let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }
        
        // Use correct API endpoint - get ACTIVE listings (not sold)
        let baseURL = EbayOAuthService.shared.getBaseAPIURL()
        let urlString = "\(baseURL)/buy/browse/v1/item_summary/search?q=\(encodedQuery)&limit=20&filter=priceCurrency:USD&sort=price"
        
        guard let url = URL(string: urlString) else { return [] }
            
            var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("EBAY-US", forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")
        request.timeoutInterval = 15
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                if let httpResponse = response as? HTTPURLResponse {
                    print("   ⚠️ eBay listings API error: \(httpResponse.statusCode)")
                } else {
                    print("   ⚠️ eBay listings API error: No HTTP response")
                }
                return []
            }
            
            // Parse listings
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["itemSummaries"] as? [[String: Any]] else {
                return []
            }
            
            var listings: [EbayListing] = []
                
                for item in items {
                guard let itemId = item["itemId"] as? String,
                      let title = item["title"] as? String,
                      let price = item["price"] as? [String: Any],
                      let valueStr = price["value"] as? String,
                      let value = Double(valueStr),
                      let itemWebUrl = item["itemWebUrl"] as? String else {
                    continue
                }
                
                // Get image URL
                var imageURL = ""
                if let image = item["image"] as? [String: Any],
                   let imageUrl = image["imageUrl"] as? String {
                    imageURL = imageUrl
                }
                
                // Get condition
                let condition = item["condition"] as? String
                
                listings.append(EbayListing(
                    id: itemId,
                    title: title,
                    price: value,
                    imageURL: imageURL,
                    itemURL: itemWebUrl,
                    condition: condition
                ))
            }
            
            // Sort by price (cheapest first)
            return listings.sorted { $0.price < $1.price }
            
        } catch {
            print("   ❌ Error fetching eBay listings: \(error.localizedDescription)")
            return []
        }
    }
    
    // Fetch signers from eBay signed listings
    func fetchSignersFromEbay(for popName: String, popNumber: String? = nil) async -> [String] {
        guard let accessToken = await EbayOAuthService.shared.getAccessToken() else {
            return []
        }
        
        var allSigners: Set<String> = []
        
        // Search for signed versions of this specific pop
        var searchQuery = "funko pop \(popName)"
        if let number = popNumber, !number.isEmpty {
            searchQuery += " #\(number)"
        }
        searchQuery += " signed"
        
        // Also search for any variant of this character (remove number to get all variants)
        let characterQuery = "funko pop \(popName) signed"
        
        let queries = [searchQuery, characterQuery]
        
        for query in queries {
            guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                continue
            }
            
            // Search eBay for signed listings
            let baseURL = EbayOAuthService.shared.getBaseAPIURL()
            let urlString = "\(baseURL)/buy/browse/v1/item_summary/search?q=\(encodedQuery)&limit=100&filter=priceCurrency:USD"
            
            guard let url = URL(string: urlString) else { continue }
            
                var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("EBAY-US", forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")
            request.timeoutInterval = 15
                
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    continue
                }
                
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let items = json["itemSummaries"] as? [[String: Any]] else {
                        continue
                    }
                    
                    // Extract signers from listing titles
                    for item in items {
                        guard let title = item["title"] as? String else { continue }
                        
                        let titleLower = title.lowercased()
                        
                        // Extract from "signed by X" pattern
                        if let signerRange = titleLower.range(of: "signed by ") {
                            let start = signerRange.upperBound
                            let signerText = String(title[start...])
                            
                            // Extract signer name (stop at common suffixes)
                            let stopWords = [" w/", " with ", " jsa", " coa", " authenticated", " autograph", " funko", " pop", " graded", " psa", " cgc"]
                            var signerName = signerText
                            for stopWord in stopWords {
                                if let stopRange = signerName.lowercased().range(of: stopWord) {
                                    signerName = String(signerName[..<stopRange.lowerBound])
                                    break
                                }
                            }
                            
                            // Clean up and extract name parts
                            let signerParts = signerName.components(separatedBy: CharacterSet(charactersIn: " ,&"))
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty && $0.count > 1 }
                                .filter { part in
                                    // Filter out common false positives
                                    let partLower = part.lowercased()
                                    return !partLower.contains("graded") && 
                                           !partLower.contains("psa") && 
                                           !partLower.contains("cgc") &&
                                           !partLower.contains("authenticated") &&
                                           !partLower.contains("coa") &&
                                           partLower != "va" &&
                                           partLower != "by"
                                }
                            
                            // Take first 2-3 words as signer name (must be at least 2 words for a real name)
                            if signerParts.count >= 2 {
                                let fullName = signerParts.prefix(2).joined(separator: " ")
                                if fullName.count > 3 && !fullName.lowercased().contains("graded") {
                                    allSigners.insert(fullName.capitalized)
                                }
                            } else if let firstPart = signerParts.first, firstPart.count > 3 {
                                // Single word names are less common, but allow if long enough
                                allSigners.insert(firstPart.capitalized)
                            }
                            
                            // Check for multiple signers (separated by & or and)
                            if signerText.contains("&") || signerText.contains(" and ") {
                                let parts = signerText.components(separatedBy: CharacterSet(charactersIn: "&"))
                                for part in parts {
                                    let names = part.components(separatedBy: " ")
                                        .prefix(2)
                                        .joined(separator: " ")
                                        .trimmingCharacters(in: .whitespaces)
                                    if names.count > 3 && !names.lowercased().contains("graded") {
                                        allSigners.insert(names.capitalized)
                                    }
                                }
                            }
                        }
                    }
            } catch {
                    // JSON parsing error, continue to next query
                    continue
                }
            } catch {
                // Network error, continue to next query
                continue
            }
        }
        
        return Array(allSigners).sorted()
    }
}


