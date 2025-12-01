//
//  UPCLookup.swift
//  PopCollector
//
//  Looks up Funko Pop details from UPC barcode
//  Auto-detects signed Pops and extracts actor names
//

import Foundation
import SwiftSoup
import SwiftData

struct PopLookupResult: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let number: String
    let series: String
    let imageURL: String
    let source: String
    var productURL: String? = nil  // Direct URL to product page
    var exclusivity: String = ""  // e.g. "Chase", "Hot Topic Exclusive", "Funko Shop Exclusive"
    var features: [String] = []  // e.g. ["Glow", "Metallic", "Flocked"]
    var releaseDate: String = ""
    var upc: String = ""
    var isSigned: Bool = false  // Whether this Pop is signed/autographed
    var signedBy: String = ""  // Name of the signer (extracted from title if available)
    var hdbid: String? = nil  // HobbyDB ID for deduplication
    
    static func == (lhs: PopLookupResult, rhs: PopLookupResult) -> Bool {
        lhs.name == rhs.name && lhs.number == rhs.number && lhs.series == rhs.series
    }
}

class UPCLookupService {
    static let shared = UPCLookupService()
    
    private init() {}
    
    // Helper: Check if a result is actually a Funko Pop figure (not podcast, show, etc.)
    // Also filters out unwanted items like "Pop me", "Pop yourself", etc.
    private func isValidPopItem(title: String) -> Bool {
        let titleLower = title.lowercased()
        
        // Must contain "pop" or "funko pop" (but not just "funko" alone)
        let hasPopKeyword = titleLower.contains("pop") || titleLower.contains("funko pop")
        guard hasPopKeyword else { return false }
        
        // Filter out unwanted patterns - focused list
        let unwantedPatterns = [
            "pop me",           // Pop Yourself type items
            "pop yourself",
            "make your own",
            "custom pop",
            "pop yourself",
            "digital pop",      // Digital items
            "nft pop",
            "pop podcast",      // Podcasts, shows
            "pop talk",         // "Funko Pop Talk" podcast
            "pop talk:",
            "talk s3",
            "s3e",              // Episode format
            "s2e",
            "s1e",
            "episode",
            "pop culture",      // Generic culture references
            "pop! culture",
            "pop show",         // TV shows
            "pop concert",      // Events
            "pop festival",
            "pop event",
            "pop radio",        // Radio/Media
            "pop tv",
            "pop station",
            "pop magazine",     // Publications
            "pop news",
            "pop blog"
        ]
        
        // Check if title matches any unwanted pattern
        for pattern in unwantedPatterns {
            if titleLower.contains(pattern) {
                return false
            }
        }
        
        // Additional check: if it contains "funko" but not "pop", exclude it (unless it's clearly a Pop variant)
        if titleLower.contains("funko") && !titleLower.contains("pop") {
            // Allow if it's a known Pop variant name
            let popVariants = ["vinyl", "figure", "collectible", "funko pop", "#"]
            let hasPopVariant = popVariants.contains { titleLower.contains($0) }
            if !hasPopVariant {
                return false
            }
        }
        
        return true
    }
    
    // Main lookup function - tries multiple sources
    func lookupPop(upc: String, context: ModelContext) async -> PopItem? {
        // Step 1: Check cache first (instant)
        let descriptor = FetchDescriptor<PopItem>(
            predicate: #Predicate<PopItem> { $0.upc == upc }
        )
        
        if let cached = try? context.fetch(descriptor).first {
            print("Cache hit for UPC: \(upc)")
            return cached
        }
        
        // Step 2: Search Excel database by UPC
        if let dbResult = await FunkoDatabaseService.shared.searchByUPC(upc: upc) {
            var result = PopLookupResult(
                name: dbResult.name,
                number: dbResult.number,
                series: dbResult.series,
                imageURL: dbResult.imageURL,
                source: dbResult.source
            )
            // Detect signed status from title
            let signedStatus = detectSignedStatus(from: dbResult.name)
            result.isSigned = signedStatus.isSigned
            result.signedBy = signedStatus.signedBy
            return createPopItem(from: result, upc: upc, context: context)
        }
        
        // Step 3: Try free UPC databases
        if let result = await lookupUPCItemDB(upc) {
            return createPopItem(from: result, upc: upc, context: context)
        }
        
        if let result = await lookupOpenFoodFacts(upc) {
            return createPopItem(from: result, upc: upc, context: context)
        }
        
        // Step 3: Fallback - Google image search
        if let result = await googleImageSearchFallback(upc) {
            let pop = PopItem(
                name: result.name,
                number: "",
                series: "",
                value: 0.0,
                imageURL: result.imageURL,
                upc: upc,
                source: "Google Search"
            )
            context.insert(pop)
            try? context.save()
            return pop
        }
        
        // Final fallback
        let pop = PopItem(
            name: "Unknown Pop (UPC: \(upc))",
            number: "",
            series: "",
            value: 0.0,
            imageURL: "https://via.placeholder.com/300/666/fff?text=?",
            upc: upc,
            source: "Unknown"
        )
        context.insert(pop)
        try? context.save()
        return pop
    }
    
    // Lookup all variants for a UPC - shows ALL results with the same UPC (different HDBIDs)
    func lookupVariants(upc: String) async -> [PopLookupResult] {
        // Step 1: Get ALL Pops with this UPC from Excel database
        let allUPCResults = await FunkoDatabaseService.shared.searchAllByUPC(upc: upc)
        
        var allResults: [PopLookupResult] = []
        
        // Convert all Excel results to PopLookupResult
        for dbResult in allUPCResults {
            var result = PopLookupResult(
                name: dbResult.name,
                number: dbResult.number,
                series: dbResult.series,
                imageURL: dbResult.imageURL,
                source: dbResult.source
            )
            result.exclusivity = extractExclusivity(from: dbResult.name)
            result.features = extractFeatures(from: dbResult.name)
            result.releaseDate = dbResult.releaseDate ?? ""
            result.upc = upc
            result.hdbid = dbResult.hdbid  // Include HDBID for deduplication
            
            // Detect signed status from title
            let signedStatus = detectSignedStatus(from: dbResult.name)
            result.isSigned = signedStatus.isSigned
            result.signedBy = signedStatus.signedBy
            
            allResults.append(result)
        }
        
        // If we found results from Excel, return them (all UPC matches)
        if !allResults.isEmpty {
            print("✅ Found \(allResults.count) result(s) with UPC: \(upc)")
            return allResults
        }
        
        // Fallback: Try other sources if CSV didn't have it
        if let dbResult = await FunkoDatabaseService.shared.searchByUPC(upc: upc) {
            var result = PopLookupResult(
                name: dbResult.name,
                number: dbResult.number,
                series: dbResult.series,
                imageURL: dbResult.imageURL,
                source: dbResult.source
            )
            result.exclusivity = extractExclusivity(from: dbResult.name)
            result.features = extractFeatures(from: dbResult.name)
            result.releaseDate = dbResult.releaseDate ?? ""
            result.upc = upc
            result.hdbid = dbResult.hdbid
            
            let signedStatus = detectSignedStatus(from: dbResult.name)
            result.isSigned = signedStatus.isSigned
            result.signedBy = signedStatus.signedBy
            
            return [result]
        }
        
        // Try UPCItemDB if database didn't work
        if let result = await lookupUPCItemDB(upc) {
            return [result]
        }
        
        // Try OpenFoodFacts as fallback
        if let result = await lookupOpenFoodFacts(upc) {
            return [result]
        }
        
        print("⚠️ Could not find any results for UPC: \(upc)")
        return []
    }
    
    // Get all variants from UPCItemDB
    private func lookupUPCItemDBVariants(_ upc: String) async -> [PopLookupResult]? {
        guard let url = URL(string: "https://api.upcitemdb.com/prod/trial/lookup?upc=\(upc)") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                return nil
            }
            
            var variants: [PopLookupResult] = []
            
            for item in items {
                guard let title = item["title"] as? String else { continue }
                
                let cleanName = title
                    .replacingOccurrences(of: "Funko POP! |Funko Pop! |\\(Chase\\)|\\(Exclusive\\)", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                
                let images = item["images"] as? [String] ?? []
                let imageURL = images.first ?? "https://via.placeholder.com/300"
                
                variants.append(PopLookupResult(
                    name: cleanName,
                    number: extractPopNumber(from: title) ?? "",
                    series: extractSeries(from: title),
                    imageURL: imageURL,
                    source: "UPCItemDB"
                ))
            }
            
            return variants.isEmpty ? nil : variants
        } catch {
            print("UPCItemDB variants error: \(error)")
            return nil
        }
    }
    
    // Free UPCItemDB lookup (best for Funko)
    private func lookupUPCItemDB(_ upc: String) async -> PopLookupResult? {
        guard let url = URL(string: "https://api.upcitemdb.com/prod/trial/lookup?upc=\(upc)") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]],
                  let item = items.first,
                  let title = item["title"] as? String else {
                return nil
            }
            
            let cleanName = title
                .replacingOccurrences(of: "Funko POP! |Funko Pop! |\\(Chase\\)|\\(Exclusive\\)", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            
            let images = item["images"] as? [String] ?? []
            let imageURL = images.first ?? "https://via.placeholder.com/300"
            
            return PopLookupResult(
                name: cleanName,
                number: extractPopNumber(from: title) ?? "",
                series: extractSeries(from: title),
                imageURL: imageURL,
                source: "UPCItemDB"
            )
        } catch {
            print("UPCItemDB error: \(error)")
            return nil
        }
    }
    
    // Backup: OpenFoodFacts (sometimes has Funko)
    private func lookupOpenFoodFacts(_ upc: String) async -> PopLookupResult? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(upc).json") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let product = json["product"] as? [String: Any],
                  let name = product["product_name"] as? String,
                  (name.contains("Funko") || name.contains("Pop")) else {
                return nil
            }
            
            let imageURL = product["image_front_url"] as? String ?? "https://via.placeholder.com/300"
            
            return PopLookupResult(
                name: name,
                number: extractPopNumber(from: name) ?? "",
                series: extractSeries(from: name),
                imageURL: imageURL,
                source: "OpenFoodFacts"
            )
        } catch {
            return nil
        }
    }
    
    // Google image search fallback
    private func googleImageSearchFallback(_ upc: String) async -> (name: String, imageURL: String)? {
        let query = "funko+pop+\(upc)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://www.google.com/search?q=\(query)&tbm=isch") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            let doc = try SwiftSoup.parse(html)
            
            if let firstImg = try doc.select("img").first(),
               let src = try? firstImg.attr("src"),
               src.contains("http"),
               let title = try? doc.title() {
                let name = title.components(separatedBy: "-").first?.trimmingCharacters(in: .whitespaces) ?? "Funko Pop"
                return (name, src)
            }
        } catch {
            print("Google search error: \(error)")
        }
        
        return nil
    }
    
    // Helper: Extract #123 from title - improved to catch more patterns
    private func extractPopNumber(from title: String) -> String? {
        // Try pattern: #123
        if let regex = try? NSRegularExpression(pattern: "#(\\d+)", options: []),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           let range = Range(match.range(at: 1), in: title) {
            return String(title[range])
        }
        
        // Try pattern: Pop! 123 or Pop 123
        if let regex = try? NSRegularExpression(pattern: "(?i)pop!?\\s*(?:#)?(\\d{3,4})", options: []),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           let range = Range(match.range(at: 1), in: title) {
            return String(title[range])
        }
        
        // Try pattern: just numbers at the start (like "123 - Name")
        if let regex = try? NSRegularExpression(pattern: "^\\s*(\\d{3,4})\\s*[-:]", options: []),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           let range = Range(match.range(at: 1), in: title) {
            return String(title[range])
        }
        
        // Try pattern: (123) or [123]
        if let regex = try? NSRegularExpression(pattern: "[\\[\\(](\\d{3,4})[\\]\\)]", options: []),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           let range = Range(match.range(at: 1), in: title) {
            return String(title[range])
        }
        
        return nil
    }
    
    // Helper: Detect if a Pop is signed/autographed and extract signer name
    private func detectSignedStatus(from title: String) -> (isSigned: Bool, signedBy: String) {
        let titleLower = title.lowercased()
        
        // Check for signed/autograph keywords
        let signedKeywords = [
            "signed",
            "autograph",
            "autographed",
            "signed by",
            "autographed by",
            "signed with",
            "signed quote",
            "signed and quoted",
            "authenticated signature",
            "coa",  // Certificate of Authenticity
            "certificate of authenticity",
            "psa/dna",
            "psa dna",
            "jsa authenticated",
            "bas authenticated",
            "beckett authenticated"
        ]
        
        var isSigned = false
        var signedBy = ""
        
        // Check if title contains signed keywords
        for keyword in signedKeywords {
            if titleLower.contains(keyword) {
                isSigned = true
                break
            }
        }
        
        // If signed, try to extract signer name
        if isSigned {
            // Pattern: "signed by [Name]" or "autographed by [Name]"
            let patterns = [
                "signed by\\s+([^,]+)",
                "autographed by\\s+([^,]+)",
                "autograph by\\s+([^,]+)",
                "signed\\s+([^,]+)\\s+autograph",
                "\\*signed\\*\\s+([^,]+)",
                "signed:\\s+([^,]+)"
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: title, options: [], range: NSRange(location: 0, length: title.utf16.count)),
                   match.numberOfRanges > 1,
                   let signerRange = Range(match.range(at: 1), in: title) {
                    signedBy = String(title[signerRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Clean up common patterns
                    signedBy = signedBy.replacingOccurrences(of: "with quote", with: "", options: .caseInsensitive)
                    signedBy = signedBy.replacingOccurrences(of: "w/ jsa", with: "", options: .caseInsensitive)
                    signedBy = signedBy.replacingOccurrences(of: "w/coa", with: "", options: .caseInsensitive)
                    signedBy = signedBy.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !signedBy.isEmpty {
                        break
                    }
                }
            }
            
            // Fallback: try to extract from parentheses or quotes
            if signedBy.isEmpty {
                let parentheticalPattern = "\\(([^)]*signed[^)]*)\\)"
                if let regex = try? NSRegularExpression(pattern: parentheticalPattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: title, options: [], range: NSRange(location: 0, length: title.utf16.count)),
                   match.numberOfRanges > 1,
                   let signerRange = Range(match.range(at: 1), in: title) {
                    let matchText = String(title[signerRange])
                    // Extract name if it contains "by" or actor initials
                    if matchText.contains("by") {
                        let parts = matchText.components(separatedBy: "by")
                        if parts.count > 1 {
                            signedBy = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                }
            }
        }
        
        return (isSigned, signedBy)
    }
    
    // Helper: Extract exclusivity from title
    private func extractExclusivity(from title: String) -> String {
        let titleLower = title.lowercased()
        
        // Define known retailers and conventions - ONLY these should be recognized as exclusivity
        let knownRetailers: [String: String] = [
            "hot topic": "Hot Topic Exclusive",
            "target": "Target Exclusive",
            "walmart": "Walmart Exclusive",
            "amazon": "Amazon Exclusive",
            "gamestop": "GameStop Exclusive",
            "boxlunch": "BoxLunch Exclusive",
            "funko shop": "Funko Shop Exclusive",
            "entertainment earth": "Entertainment Earth Exclusive",
            "fugitive toys": "Fugitive Toys Exclusive",
            "bam!": "BAM! Exclusive",
            "bam": "BAM! Exclusive",
            "books a million": "BAM! Exclusive",
            "chalice collectibles": "Chalice Collectibles Exclusive",
            "chalice": "Chalice Collectibles Exclusive",
            "toys r us": "Toys R Us Exclusive",
            "toysrus": "Toys R Us Exclusive",
            "toys 'r' us": "Toys R Us Exclusive",
            "walgreens": "Walgreens Exclusive",
            "cvs": "CVS Exclusive",
            "7-eleven": "7-Eleven Exclusive",
            "7 eleven": "7-Eleven Exclusive",
            "thinkgeek": "ThinkGeek Exclusive",
            "specialty series": "Specialty Series Exclusive",
            "px previews": "PX Previews Exclusive",
            "previews exclusive": "PX Previews Exclusive",
            "px": "PX Previews Exclusive",
            "previews": "PX Previews Exclusive",
            "lootcrate": "Lootcrate Exclusive",
            "loot crate": "Lootcrate Exclusive",
            "loot": "Lootcrate Exclusive",
            "midtown comics": "Midtown Comics Exclusive",
            "toy tokyo": "Toy Tokyo Exclusive",
            "barnes and noble": "Barnes & Noble Exclusive",
            "barnes & noble": "Barnes & Noble Exclusive",
            "dc legion collectors": "DC Legion Collectors Exclusive",
            "fye": "FYE Exclusive",
            "f.y.e.": "FYE Exclusive",
            "fanatics": "Fanatics Exclusive",
            "best buy": "Best Buy Exclusive",
            "bestbuy": "Best Buy Exclusive",
            "gemini collectibles": "Gemini Collectibles Exclusive",
            "gemini": "Gemini Collectibles Exclusive",
            "popcultcha": "Popcultcha Exclusive",
            "pop in a box": "Pop in a Box Exclusive",
            "popinabox": "Pop in a Box Exclusive",
            "sam's club": "Sam's Club Exclusive",
            "sams club": "Sam's Club Exclusive",
            "baskin robbins": "Baskin Robbins Exclusive",
            "coca-cola store": "Coca-Cola Store Exclusive",
            "coca cola": "Coca-Cola Store Exclusive"
        ]
        
        let knownConventions: [String: String] = [
            "nycc": "NYCC Exclusive",
            "new york comic con": "NYCC Exclusive",
            "sdcc": "SDCC Exclusive",
            "san diego comic con": "SDCC Exclusive",
            "san diego comic-con": "SDCC Exclusive",
            "eccc": "ECCC Exclusive",
            "emerald city comic con": "ECCC Exclusive",
            "c2e2": "C2E2 Exclusive",
            "fan expo": "Fan Expo Exclusive",
            "dallas comic con": "Dallas Comic Con Exclusive",
            "dallas comic-con": "Dallas Comic Con Exclusive",
            "dcc": "Dallas Comic Con Exclusive",
            "wondercon": "WonderCon Exclusive",
            "wonder con": "WonderCon Exclusive",
            "mefcc": "MEFCC Exclusive",
            "middle east film & comic con": "MEFCC Exclusive",
            "anime expo": "Anime Expo Exclusive",
            "ax exclusive": "Anime Expo Exclusive",
            "ccxp": "CCXP Exclusive",
            "spring convention": "Spring Convention",
            "fall convention": "Fall Convention",
            "summer convention": "Summer Convention",
            "limited edition supreme": "Limited Edition Supreme",
            "limited edition": "Limited Edition",
            "convention shared": "Convention Shared",
            "shared exclusive": "Convention Shared",
            "convention exclusive": "Convention Exclusive"
        ]
        
        // First, check for exclusivity in brackets [SDCC], [NYCC], etc.
        if let bracketRange = title.range(of: "[") {
            let afterBracket = String(title[bracketRange.upperBound...])
            if let closeBracket = afterBracket.firstIndex(of: "]") {
                let bracketText = String(afterBracket[..<closeBracket]).trimmingCharacters(in: .whitespaces)
                let bracketLower = bracketText.lowercased()
                
                for (keyword, exclusivity) in knownConventions {
                    if bracketLower.contains(keyword) {
                        return exclusivity
                    }
                }
            }
        }
        
        // Then check ALL parentheses in the title for known retailers/conventions
        // Use regex to find all parentheses content
        let pattern = "\\(([^)]+)\\)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = title as NSString
            let matches = regex.matches(in: title, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                if match.numberOfRanges > 1 {
                    let range = match.range(at: 1)
                    let parenText = nsString.substring(with: range).trimmingCharacters(in: .whitespaces)
                    let parenLower = parenText.lowercased()
                    
                    // Check if this parentheses contains a known retailer
                    for (keyword, exclusivity) in knownRetailers {
                        if parenLower.contains(keyword) {
                            return exclusivity
                        }
                    }
                    
                    // Check if this parentheses contains a known convention
                    for (keyword, exclusivity) in knownConventions {
                        if parenLower.contains(keyword) {
                            return exclusivity
                        }
                    }
                }
            }
        }
        
        // Finally, check the entire title for retailer/convention keywords
        // Check conventions first (more specific)
        for (keyword, exclusivity) in knownConventions {
            if titleLower.contains(keyword) {
                return exclusivity
            }
        }
        
        // Then check retailers
        for (keyword, exclusivity) in knownRetailers {
            if titleLower.contains(keyword) {
                return exclusivity
            }
        }
        
        // If no known retailer/convention found, return empty (don't create fake exclusivity)
        return ""
    }
    
    // Helper: Extract features from title
    private func extractFeatures(from title: String) -> [String] {
        let titleLower = title.lowercased()
        var features: [String] = []
        
        let featureKeywords: [String: String] = [
            // Chase variants (check first as it's most important)
            "chase": "Chase",
            "chase variant": "Chase",
            "chase edition": "Chase",
            // Glow variants
            "glow": "Glow-in-the-Dark",
            "glows in the dark": "Glow-in-the-Dark",
            "glow in the dark": "Glow-in-the-Dark",
            "gitd": "Glow-in-the-Dark",
            "glowing": "Glow-in-the-Dark",
            // Metallic variants
            "metallic": "Metallic",
            "metal": "Metallic",
            // Flocked variants
            "flocked": "Flocked",
            "fuzzy": "Flocked",
            // Chrome variants
            "chrome": "Chrome",
            "chromed": "Chrome",
            // Black Light variants
            "blacklight": "Black Light",
            "black light": "Black Light",
            "blacklight collection": "Black Light",
            // Glitter variants
            "glitter": "Glitter",
            "glittery": "Glitter",
            // Diamond Collection
            "diamond": "Diamond Collection",
            "diamond collection": "Diamond Collection",
            // Holographic
            "holo": "Holographic",
            "holographic": "Holographic",
            // Size variants
            "plus": "Pop! Plus (Oversized)",
            "pop! plus": "Pop! Plus (Oversized)",
            "oversized": "Oversized",
            "jumbo": "Jumbo",
            "super sized": "Super Sized",
            "6 inch": "6\"",
            "10 inch": "10\"",
            "18 inch": "18\"",
            "mini": "Mini",
            "pocket pop": "Pocket Pop!",
            "pocket": "Pocket Pop!",
            // Special collections
            "pop! rides": "Pop! Rides",
            "rides": "Pop! Rides",
            "pop! deluxe": "Pop! Deluxe",
            "deluxe": "Pop! Deluxe",
            "pop! two pack": "Pop! Two Pack",
            "pop! three pack": "Pop! Three Pack",
            "two pack": "Two Pack",
            "three pack": "Three Pack",
            "2 pack": "Two Pack",
            "3 pack": "Three Pack",
            "pop! moments": "Pop! Moments",
            "moments": "Pop! Moments",
            "pop! town": "Pop! Town",
            "town": "Pop! Town",
            "pop! keychain": "Pop! Keychain",
            "keychain": "Pop! Keychain",
            // Special editions
            "vaulted": "Vaulted",
            "retired": "Retired",
            "limited edition": "Limited Edition",
            "anniversary": "Anniversary Edition",
            "movie moment": "Movie Moment",
            "pop! movie moment": "Movie Moment"
        ]
        
        // Check for features in order (most specific first)
        for (keyword, feature) in featureKeywords {
            if titleLower.contains(keyword) && !features.contains(feature) {
                features.append(feature)
            }
        }
        
        return features
    }
    
    // Helper: Extract series from title
    private func extractSeries(from title: String) -> String {
        if title.contains("Heroes") || title.contains("DC") { return "DC Heroes" }
        if title.contains("Marvel") { return "Marvel" }
        if title.contains("Star Wars") { return "Star Wars" }
        if title.contains("Disney") { return "Disney" }
        if title.contains("Anime") { return "Anime" }
        if title.contains("Solo Leveling") { return "Solo Leveling" }
        if title.contains("Demon Slayer") { return "Demon Slayer" }
        if title.contains("My Hero Academia") { return "My Hero Academia" }
        if title.contains("Attack on Titan") { return "Attack on Titan" }
        if title.contains("One Piece") { return "One Piece" }
        if title.contains("Dragon Ball") { return "Dragon Ball" }
        if title.contains("Naruto") { return "Naruto" }
        return "Funko Pop!"
    }
    
    // Search for Pops by name/text query (online search)
    // Uses only official Funko sources (Funko.com, hobbyDB, Funko App API, GitHub database, Fandom Wiki)
    func searchPops(query: String, includeAutographed: Bool = false) async -> [PopLookupResult] {
        var results: [PopLookupResult] = []
        
        // Clean the query
        let cleanQuery = query.trimmingCharacters(in: .whitespaces)
        guard !cleanQuery.isEmpty else { return results }
        
        // Step 1: Search Funko database (most accurate) - but don't wait too long
        let databaseResults = await FunkoDatabaseService.shared.searchPops(query: cleanQuery, includeAutographed: includeAutographed)
        for dbResult in databaseResults {
            // NO FILTERING - Database results are trusted, show all results
            // Use the number from database result (don't try to extract from image URL - those are SKUs)
            var popNumber = dbResult.number
            
            // Only if still empty, try extracting from name one more time
            if popNumber.isEmpty {
                popNumber = extractPopNumber(from: dbResult.name) ?? ""
            }
            
            var result = PopLookupResult(
                name: dbResult.name,
                number: popNumber,
                series: dbResult.series,
                imageURL: dbResult.imageURL,
                source: dbResult.source
            )
            // Use exclusivity from database if available, otherwise extract from name
            if let dbExclusivity = dbResult.exclusiveTo, !dbExclusivity.isEmpty {
                result.exclusivity = dbExclusivity
            } else {
                result.exclusivity = extractExclusivity(from: "\(dbResult.name) \(dbResult.series)")
            }
            // Extract features from name AND production status
            var features = extractFeatures(from: dbResult.name)
            if let prodStatus = dbResult.productionStatus, !prodStatus.isEmpty {
                // Add production status features (Chase, Glow, etc.)
                let prodStatusLower = prodStatus.lowercased()
                if prodStatusLower.contains("chase") && !features.contains("Chase") {
                    features.append("Chase")
                }
                if (prodStatusLower.contains("glow") || prodStatusLower.contains("gitd")) && !features.contains("Glow") {
                    features.append("Glow")
                }
                if prodStatusLower.contains("metallic") && !features.contains("Metallic") {
                    features.append("Metallic")
                }
                if prodStatusLower.contains("flocked") && !features.contains("Flocked") {
                    features.append("Flocked")
                }
                if prodStatusLower.contains("diamond") && !features.contains("Diamond") {
                    features.append("Diamond")
                }
            }
            result.features = features
            result.releaseDate = dbResult.releaseDate ?? ""
            result.upc = dbResult.upc ?? ""
            result.hdbid = dbResult.hdbid  // Include HDBID for deduplication
            
            // Detect signed status from title
            let signedStatus = detectSignedStatus(from: dbResult.name)
            result.isSigned = signedStatus.isSigned
            result.signedBy = signedStatus.signedBy
            
            results.append(result)
        }
        
        // Only use official Funko sources (Funko.com, hobbyDB, Funko App API, etc.)
        // No marketplace searches for Pop information
        print("📊 Total results from Funko sources: \(results.count)")
        
        // Deduplicate by HDBID - same HDBID = same Pop, show only once
        var seenHDBIDs: Set<String> = []
        var uniqueResults: [PopLookupResult] = []
        
        for result in results {
            if let hdbid = result.hdbid, !hdbid.isEmpty {
                if seenHDBIDs.contains(hdbid) {
                    continue
                }
                seenHDBIDs.insert(hdbid)
            }
            uniqueResults.append(result)
        }
        
        print("📊 After HDBID deduplication: \(uniqueResults.count) unique results")
        
        // Sort: database results first, then by number if available, then by name
        uniqueResults.sort { lhs, rhs in
            let lhsIsDB = lhs.source.contains("Database") || lhs.source.contains("hobbyDB") || lhs.source.contains("Funko.com")
            let rhsIsDB = rhs.source.contains("Database") || rhs.source.contains("hobbyDB") || rhs.source.contains("Funko.com")
            
            if lhsIsDB != rhsIsDB {
                return lhsIsDB
            }
            
            // If both have numbers, sort by number first
            if !lhs.number.isEmpty && !rhs.number.isEmpty {
                if let lhsNum = Int(lhs.number), let rhsNum = Int(rhs.number) {
                    return lhsNum < rhsNum
                }
                return lhs.number < rhs.number
            }
            
            return lhs.name < rhs.name
        }
        
        return Array(uniqueResults.prefix(50)) // Return up to 50 results to show more variants
    }
    
    // Search eBay for Funko Pops using Official eBay API
    private func searchEbay(query: String) async -> [PopLookupResult]? {
        // Get OAuth token (automatically generates if needed)
        guard let accessToken = await EbayOAuthService.shared.getAccessToken() else {
            print("⚠️ eBay: No OAuth token available. Please add your eBay Client ID and Client Secret in Settings.")
            return nil
        }
        
        let searchQuery = "funko pop \(query)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        // Use eBay Browse API - detect sandbox vs production
        let baseURL = EbayOAuthService.shared.getBaseAPIURL()
        guard let url = URL(string: "\(baseURL)/buy/browse/v1/item_summary/search?q=\(searchQuery)&limit=50") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("EBAY-US", forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")
        request.timeoutInterval = 15
        
        print("🔍 eBay: Using official API to search")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ eBay API: No HTTP response")
                return nil
            }
            
            print("📡 eBay API HTTP Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode >= 400 {
                // Log the actual error response from eBay
                if let errorResponse = String(data: data, encoding: .utf8) {
                    print("❌ eBay API Error Response: \(errorResponse)")
                }
                if httpResponse.statusCode == 403 {
                    print("⚠️ eBay API 403 Forbidden: Your app doesn't have Browse API permissions.")
                    print("⚠️ Solution: Go to developer.ebay.com → My Account → Application Keys")
                    print("⚠️ Select your app → API Permissions → Enable 'Browse API'")
                    print("⚠️ Note: Sandbox may have limited API access. You may need Production credentials.")
                }
                return nil
            }
            
            // Log response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📦 eBay API Response (first 500 chars): \(String(responseString.prefix(500)))")
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ eBay API: Could not parse JSON response")
                return nil
            }
            
            // Check for itemSummaries or items (different APIs use different keys)
            var items: [[String: Any]] = []
            if let itemSummaries = json["itemSummaries"] as? [[String: Any]] {
                items = itemSummaries
            } else if let itemsArray = json["items"] as? [[String: Any]] {
                items = itemsArray
            } else if let total = json["total"] as? Int, total == 0 {
                // Empty result set - Sandbox typically has no test data
                print("✅ eBay API: No results found (Sandbox may have no test data. Use Production for real results.)")
                return []
            } else {
                print("❌ eBay API: Response doesn't contain itemSummaries or items")
                print("📦 Available keys in response: \(json.keys.joined(separator: ", "))")
                return nil
            }
            
            print("✅ eBay API: Found \(items.count) items")
            
            var results: [PopLookupResult] = []
            
            for item in items {
                // Extract title
                guard let title = item["title"] as? String, !title.isEmpty else {
                    continue
                }
                
                // Filter out non-Pop items
                guard isValidPopItem(title: title) else {
                    continue
                }
                
                // Extract image URL
                var imageURL = ""
                if let images = item["image"] as? [String: Any],
                   let imageUrlString = images["imageUrl"] as? String {
                    imageURL = imageUrlString
                }
                
                // Extract pop number from title
                let popNumber = extractPopNumber(from: title) ?? ""
                
                // Extract series (try category or brand)
                var series = "Funko Pop!"
                if let categoryPath = item["categoryPath"] as? String {
                    series = categoryPath
                } else if let brand = item["brand"] as? String {
                    series = brand
                }
                
                // Extract exclusivity and features from title
                let exclusivity = extractExclusivity(from: title)
                let features = extractFeatures(from: title)
                
                var result = PopLookupResult(
                    name: title,
                    number: popNumber,
                    series: series,
                    imageURL: imageURL,
                    source: "eBay (API)"
                )
                result.exclusivity = exclusivity
                result.features = features
                
                // Detect signed status from title
                let signedStatus = detectSignedStatus(from: title)
                result.isSigned = signedStatus.isSigned
                result.signedBy = signedStatus.signedBy
                
                results.append(result)
            }
            
            print("✅ eBay API: Returning \(results.count) valid Pop results")
            return results.isEmpty ? nil : results
            
        } catch {
            print("❌ eBay API error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Shared scraping logic for eBay pages
    private func scrapeEbayPage(url: URL, query: String) async -> [PopLookupResult]? {
        var request = URLRequest(url: url)
        // Better headers to mimic a real browser session
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("https://www.ebay.com/", forHTTPHeaderField: "Referer")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-User")
        request.timeoutInterval = 20.0
        
        do {
            // Add a small delay to appear more human-like
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ eBay: No HTTP response")
                return nil
            }
            
            print("📡 eBay HTTP Status: \(httpResponse.statusCode)")
            
            guard let html = String(data: data, encoding: .utf8) else {
                print("❌ eBay: Could not decode HTML")
                return nil
            }
            
            print("📄 eBay HTML length: \(html.count) characters")
            
            // Check if eBay is showing bot detection page
            if html.contains("Checking your browser") || html.contains("before you access") || html.contains("Reference ID:") || html.contains("ebay.security") {
                print("⚠️ eBay: Bot detection triggered. eBay is blocking automated requests.")
                print("💡 Trying alternative approach...")
                return nil
            }
            
            // Debug: check if HTML contains expected content
            let hasSrpResults = html.contains("srp-results") || html.contains("s-item")
            print("🔍 eBay HTML contains srp-results or s-item: \(hasSrpResults)")
            
            let doc = try SwiftSoup.parse(html)
            
            // Try multiple selector strategies - updated for current eBay structure
            var items: Elements?
            
            // Try most common selectors first
            let selectors = [
                ".s-item",
                "li.s-item",
                ".srp-results .s-item",
                "ul.srp-results > li",
                ".srp-results li",
                "li[class*='s-item']",
                "div[class*='s-item']",
                "[data-viewid]",
                ".s-item-wrapper",
                ".item",
                "article.s-item",
                ".s-item--large"
            ]
            
            for selector in selectors {
                items = try? doc.select(selector)
                if let items = items, !items.isEmpty {
                    print("✅ eBay: Found \(items.count) items with selector: \(selector)")
                    break
                }
            }
            
            // Last resort: look for links containing "itm" (eBay item ID pattern)
            if items == nil || items?.isEmpty() == true {
                if let links = try? doc.select("a[href*='itm']"), !links.isEmpty() {
                    print("🔍 eBay: Found \(links.count) links with 'itm' pattern, trying parent elements")
                    // Get unique parent elements
                    var parentItems = Set<Element>()
                    for link in links.prefix(50) {
                        if let parent = link.parent(),
                           let ancestor = parent.parent() {
                            parentItems.insert(ancestor)
                        }
                    }
                    items = Elements(parentItems.map { $0 })
                    print("✅ eBay: Extracted \(items?.count ?? 0) items from links")
                }
            }
            
            guard let items = items, !items.isEmpty() else {
                print("⚠️ eBay: No items found with any selector. HTML structure may have changed.")
                // Debug: Print a snippet of the HTML to see what's there
                if let body = try? doc.select("body").first(), let bodyText = try? body.text() {
                    let snippet = String(bodyText.prefix(500))
                    print("📋 eBay HTML body snippet: \(snippet)")
                }
                return nil
            }
            
            print("🔍 eBay found \(items.count) potential items")
            
            var results: [PopLookupResult] = []
            
            // Convert Elements to Array for iteration
            let itemsArray = Array(items).prefix(20)
            for item in itemsArray {
                // Try multiple title selectors - improved for current eBay structure
                var title = ""
                
                let titleSelectors = [
                    ".s-item__title",
                    ".s-item__title span", // eBay sometimes wraps in span
                    ".s-item__link",
                    "h3",
                    "h3 a",
                    "a[class*='title']",
                    "[class*='title']",
                    ".item-title",
                    "span[class*='title']"
                ]
                for selector in titleSelectors {
                    if let element = try? item.select(selector).first(),
                       let text = try? element.text(),
                       !text.isEmpty && text != "New Listing" {
                        title = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !title.isEmpty {
                            break
                        }
                    }
                }
                
                // Also try getting title from link text
                if title.isEmpty {
                    if let link = try? item.select("a").first(),
                       let linkText = try? link.text(),
                       !linkText.isEmpty {
                        title = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                guard !title.isEmpty else {
                    continue
                }
                
                // Filter out non-Pop items (podcasts, shows, etc.)
                guard isValidPopItem(title: title) else {
                    continue
                }
                
                // Try multiple image selectors - improved for current eBay structure
                var imageURL = ""
                let imageSelectors = [
                    ".s-item__image img",
                    ".s-item__image img[src]",
                    "img[class*='image']",
                    "img[data-src]",
                    "img",
                    "[class*='thumbnail'] img",
                    ".item-image img"
                ]
                for selector in imageSelectors {
                    if let img = try? item.select(selector).first() {
                        // Try multiple image attributes
                        imageURL = (try? img.attr("src")) ?? 
                                  (try? img.attr("data-src")) ?? 
                                  (try? img.attr("data-lazy-src")) ??
                                  (try? img.attr("data-original")) ?? ""
                        
                        // Clean up eBay image URLs (they sometimes use placeholder URLs)
                        if imageURL.contains("i.ebayimg.com") || imageURL.contains("ebayimg.com") || imageURL.contains("http") {
                            // Remove placeholder dimensions if present
                            imageURL = imageURL.replacingOccurrences(of: "/s-l140/", with: "/s-l500/")
                            break
                        }
                    }
                }
                
                // Fallback: try to find any img tag with a valid URL
                if imageURL.isEmpty || !imageURL.contains("http") {
                    if let img = try? item.select("img").first() {
                        let attrs = ["src", "data-src", "data-lazy-src", "data-original"]
                        for attr in attrs {
                            if let url = try? img.attr(attr), url.contains("http") {
                                imageURL = url
                                break
                            }
                        }
                    }
                }
                
                // Skip if no valid image URL found
                if imageURL.isEmpty || !imageURL.contains("http") {
                    continue
                }
                
                let cleanName = title
                    .replacingOccurrences(of: "New Listing", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "Funko POP! |Funko Pop! |\\(Chase\\)|\\(Exclusive\\)", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                
                if cleanName.isEmpty { continue }
                
                var result = PopLookupResult(
                    name: cleanName,
                    number: extractPopNumber(from: title) ?? "",
                    series: extractSeries(from: title),
                    imageURL: imageURL,
                    source: "eBay Search"
                )
                result.exclusivity = extractExclusivity(from: title)
                result.features = extractFeatures(from: title)
                
                // Detect signed status from title
                let signedStatus = detectSignedStatus(from: title)
                result.isSigned = signedStatus.isSigned
                result.signedBy = signedStatus.signedBy
                
                results.append(result)
            }
            
            print("✅ eBay search: Found \(results.count) results")
            return results.isEmpty ? nil : results
        } catch {
            print("❌ eBay search error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Search Mercari for Funko Pops
    private func searchMercari(query: String) async -> [PopLookupResult]? {
        let searchQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://www.mercari.com/search/?keyword=\(searchQuery)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.5", forHTTPHeaderField: "Accept-Language")
        
        do {
            // Small delay to appear more human-like and reduce rate limiting
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Mercari: No HTTP response")
                return nil
            }
            
            print("📡 Mercari HTTP Status: \(httpResponse.statusCode)")
            
            guard let html = String(data: data, encoding: .utf8) else {
                print("❌ Mercari: Could not decode HTML")
                return nil
            }
            
            print("📄 Mercari HTML length: \(html.count) characters")
            
            let doc = try SwiftSoup.parse(html)
            
            // Try multiple selector strategies - updated for current Mercari structure
            var items: Elements = try doc.select("[data-testid='item-cell']")
            if items.isEmpty {
                items = try doc.select("[data-testid='itemCell']")
            }
            if items.isEmpty {
                items = try doc.select(".item-cell")
            }
            if items.isEmpty {
                items = try doc.select(".merItemBox")
            }
            if items.isEmpty {
                items = try doc.select("section[data-testid='item-cell']")
            }
            if items.isEmpty {
                items = try doc.select("div[class*='ItemCell']")
            }
            if items.isEmpty {
                items = try doc.select("[class*='item-cell']")
            }
            if items.isEmpty {
                items = try doc.select("article, [role='article']")
            }
            if items.isEmpty {
                // Last resort: look for links with item IDs and their containers
                let links = try doc.select("a[href*='/items/']")
                if !links.isEmpty() {
                    // Try finding parent article or div elements
                    items = try doc.select("article:has(a[href*='/items/']), div:has(a[href*='/items/'])")
                }
            }
            
            print("🔍 Mercari found \(items.count) potential items")
            
            var results: [PopLookupResult] = []
            
            for item in items.prefix(20) {
                // Try multiple title selectors - improved for current Mercari structure
                var title = ""
                let titleSelectors = [
                    "h2",
                    "h3",
                    ".item-name",
                    "[data-testid='item-name']",
                    "[class*='title']",
                    "[class*='name']",
                    "a[class*='title']",
                    ".mer-item-name",
                    "span[class*='name']"
                ]
                for selector in titleSelectors {
                    if let element = try? item.select(selector).first(),
                       let text = try? element.text(),
                       !text.isEmpty {
                        title = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !title.isEmpty {
                            break
                        }
                    }
                }
                
                // Also try getting title from link text
                if title.isEmpty {
                    if let link = try? item.select("a").first(),
                       let linkText = try? link.text(),
                       !linkText.isEmpty {
                        title = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                guard !title.isEmpty else {
                    continue
                }
                
                // Filter out non-Pop items (podcasts, shows, etc.)
                guard isValidPopItem(title: title) else {
                    continue
                }
                
                // Try multiple image selectors - improved for current Mercari structure
                var imageURL = ""
                let imageSelectors = [
                    "img[class*='image']",
                    "img[class*='thumbnail']",
                    "img[data-testid='item-image']",
                    "img[src]",
                    "img[data-src]",
                    "img",
                    "[class*='image'] img",
                    ".item-image img",
                    "[class*='thumbnail'] img"
                ]
                for selector in imageSelectors {
                    if let img = try? item.select(selector).first() {
                        // Try multiple image attributes
                        imageURL = (try? img.attr("src")) ?? 
                                  (try? img.attr("data-src")) ?? 
                                  (try? img.attr("data-lazy-src")) ??
                                  (try? img.attr("data-original")) ??
                                  (try? img.attr("srcset")) ?? ""
                        
                        // Clean up image URL from srcset if needed
                        if imageURL.contains(" ") {
                            imageURL = imageURL.components(separatedBy: " ").first ?? imageURL
                        }
                        
                        if !imageURL.isEmpty && imageURL.contains("http") {
                            break
                        }
                    }
                }
                
                // Fallback: try to find any img tag with a valid URL
                if imageURL.isEmpty || !imageURL.contains("http") {
                    if let img = try? item.select("img").first() {
                        let attrs = ["src", "data-src", "data-lazy-src", "data-original", "srcset"]
                        for attr in attrs {
                            if let url = try? img.attr(attr), url.contains("http") {
                                imageURL = url.components(separatedBy: " ").first ?? url
                                break
                            }
                        }
                    }
                }
                
                // Skip if no valid image URL found
                if imageURL.isEmpty || !imageURL.contains("http") {
                    continue
                }
                
                let cleanName = title
                    .replacingOccurrences(of: "Funko POP! |Funko Pop! |\\(Chase\\)|\\(Exclusive\\)", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                
                if cleanName.isEmpty { continue }
                
                var result = PopLookupResult(
                    name: cleanName,
                    number: extractPopNumber(from: title) ?? "",
                    series: extractSeries(from: title),
                    imageURL: imageURL,
                    source: "Mercari Search"
                )
                result.exclusivity = extractExclusivity(from: title)
                result.features = extractFeatures(from: title)
                
                // Detect signed status from title
                let signedStatus = detectSignedStatus(from: title)
                result.isSigned = signedStatus.isSigned
                result.signedBy = signedStatus.signedBy
                
                results.append(result)
            }
            
            print("✅ Mercari search: Found \(results.count) results")
            return results.isEmpty ? nil : results
        } catch {
            print("❌ Mercari search error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Helper: Create PopItem from lookup result
    private func createPopItem(from result: PopLookupResult, upc: String, context: ModelContext) -> PopItem {
        let pop = PopItem(
            name: result.name,
            number: result.number,
            series: result.series,
            value: 0.0,
            imageURL: result.imageURL,
            upc: upc,
            source: result.source
        )
        
        // Auto-detect signed Pops
        detectSignedPop(pop: pop, name: result.name)
        
        context.insert(pop)
        try? context.save()
        return pop
    }
    
    // Auto-detect signed Pops from name
    private func detectSignedPop(pop: PopItem, name: String) {
        let lowerName = name.lowercased()
        
        // Check for signed keywords
        if lowerName.contains("signed") ||
           lowerName.contains("autographed") ||
           lowerName.contains("jsa") ||
           lowerName.contains("beckett") ||
           lowerName.contains("psa") {
            
            pop.isSigned = true
            
            // Extract actor name (common patterns)
            if let range = name.range(of: "signed by ", options: .caseInsensitive) {
                let start = range.upperBound
                let substring = String(name[start...])
                let components = substring.components(separatedBy: CharacterSet(charactersIn: " ,-"))
                let actor = components.prefix(3).joined(separator: " ").trimmingCharacters(in: .whitespaces)
                if !actor.isEmpty {
                    pop.signedBy = actor
                }
            } else if let range = name.range(of: "by ", options: .caseInsensitive) {
                // Alternative pattern: "Pop by Tom Holland"
                let start = range.upperBound
                let substring = String(name[start...])
                let components = substring.components(separatedBy: CharacterSet(charactersIn: " ,-"))
                let actor = components.prefix(3).joined(separator: " ").trimmingCharacters(in: .whitespaces)
                if !actor.isEmpty && actor.count > 2 {
                    pop.signedBy = actor
                }
            }
            
            // Look for COA
            if lowerName.contains("coa") ||
               lowerName.contains("certificate") ||
               lowerName.contains("authenticated") {
                pop.hasCOA = true
            }
            
            // Set multiplier based on COA
            pop.signedValueMultiplier = pop.hasCOA ? 5.0 : 3.0
        }
    }
}

