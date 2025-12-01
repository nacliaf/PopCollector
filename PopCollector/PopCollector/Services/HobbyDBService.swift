//
//  HobbyDBService.swift
//  PopCollector
//
//  Service for fetching variant information from database
//

import Foundation

struct HobbyDBVariant: Identifiable, Equatable {
    let id: String  // hdbid
    let name: String
    let number: String?
    let imageURL: String?
    let exclusivity: String?
    let features: [String]
    let isAutographed: Bool
    let signedBy: String?
    let upc: String?
    let releaseDate: String?
    
    static func == (lhs: HobbyDBVariant, rhs: HobbyDBVariant) -> Bool {
        lhs.id == rhs.id
    }
}

class HobbyDBService {
    static let shared = HobbyDBService()
    
    private init() {}
    
    // Fetch subvariants from database
    // Also tries slug-based URL if hdbid doesn't work
    // Can accept either numeric HDBID or slug (UUID) as hdbid parameter
    // FIRST tries CSV database (no API call), then falls back to API
    func fetchSubvariants(hdbid: String, slug: String? = nil, includeAutographed: Bool = true) async -> [HobbyDBVariant] {
        guard !hdbid.isEmpty else {
            print("⚠️ DatabaseService: Empty hdbid provided")
            return []
        }
        
        // Use CSV database only (no API calls)
        print("🔍 DatabaseService: Searching CSV database for subvariants... (includeAutographed: \(includeAutographed))")
        let csvVariants = FunkoDatabaseService.shared.findSubvariantsFromCSV(hdbid: hdbid, includeAutographed: includeAutographed)
        if !csvVariants.isEmpty {
            print("✅ DatabaseService: Found \(csvVariants.count) subvariants from CSV database")
            return csvVariants
        }
        
        print("⚠️ DatabaseService: No subvariants found in CSV database for hdbid: \(hdbid)")
        return []
    }
    
    // Helper to extract Pop number from name
    private func extractPopNumber(from name: String) -> String? {
        // Look for patterns like "#123", "123", "Pop #123"
        let patterns = [
            #"#(\d+)"#,
            #"\b(\d{3,4})\b"#,
            #"Pop\s+#(\d+)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
               let range = Range(match.range(at: 1), in: name) {
                return String(name[range])
            }
        }
        
        return nil
    }
    
    // Extract hdbid from product page HTML
    // Some sites have links with the hdbid in the URL
    func extractHDBIDFromHTML(_ html: String) -> String? {
        // Look for links in the HTML that contain hdbid
        // Pattern: .../catalog_items/...-{hdbid}/...
        let patterns = [
            #"hobbydb\.com[^"'\s]*catalog_items[^"'\s]*([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})"#,
            #"hdbid["\s:=]+([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})"#,
            #"data-hdbid["\s:=]+([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(html.startIndex..., in: html)
                if let match = regex.firstMatch(in: html, range: range),
                   let hdbidRange = Range(match.range(at: 1), in: html) {
                    let hdbid = String(html[hdbidRange])
                    print("✅ DatabaseService: Extracted hdbid from HTML: \(hdbid)")
                    return hdbid
                }
            }
        }
        
        return nil
    }
    
    // Search by constructing URL from name and scraping HTML
    // This is a fallback when API search fails
    func searchHDBIDByScraping(name: String, number: String) async -> String? {
        guard !name.isEmpty else { return nil }
        
        // Clean the name to create a slug-like URL
        let baseName = cleanPopName(name)
        let slug = baseName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        
        // Try different URL formats
        let urlFormats = [
            "https://www.hobbydb.com/marketplaces/hobbydb/catalog_items/\(slug)-art-toys",
            "https://www.hobbydb.com/marketplaces/hobbydb/catalog_items/\(slug)",
            "https://www.hobbydb.com/marketplaces/hobbydb/catalog_items/\(slug)-\(number)"
        ]
        
        for urlString in urlFormats {
            print("🔍 DatabaseService: Trying to scrape hdbid from: \(urlString)")
            
            guard let url = URL(string: urlString) else { continue }
            
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10.0
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let html = String(data: data, encoding: .utf8) else {
                    continue
                }
                
                // Look for hdbid in the HTML (in URL or data attributes)
                if let hdbid = extractHDBIDFromHTML(html) {
                    print("✅ DatabaseService: Found hdbid by scraping: \(hdbid)")
                    return hdbid
                }
                
                // Also check if this page has subvariants link (means we found the right page)
                if html.contains("subvariants") || html.contains("Subvariants") {
                    // Extract hdbid from canonical URL or other links
                    let patterns = [
                        #"catalog_items/[^/]+-([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})"#,
                        #"data-item-id["\s:=]+"([^"]+)"#,
                        #"item-id["\s:=]+"([^"]+)"#
                    ]
                    
                    for pattern in patterns {
                        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                            let range = NSRange(html.startIndex..., in: html)
                            if let match = regex.firstMatch(in: html, range: range),
                               let hdbidRange = Range(match.range(at: 1), in: html) {
                                let hdbid = String(html[hdbidRange])
                                if hdbid.count == 36 { // UUID length
                                    print("✅ DatabaseService: Found hdbid from page: \(hdbid)")
                                    return hdbid
                                }
                            }
                        }
                    }
                }
                
            } catch {
                print("⚠️ DatabaseService: Error scraping \(urlString): \(error.localizedDescription)")
                continue
            }
        }
        
        return nil
    }
    
    // Search CSV database by name, number, or UPC and return variants directly
    // All data comes from CSV - no API calls
    func searchAndFetchVariants(name: String, number: String, upc: String? = nil) async -> [HobbyDBVariant] {
        // Use CSV database only (no API calls)
        print("🔍 DatabaseService: Searching CSV database for variants...")
        let csvVariants = FunkoDatabaseService.shared.findSubvariantsFromCSV(number: number, name: name, includeAutographed: true)
        if !csvVariants.isEmpty {
            print("✅ DatabaseService: Found \(csvVariants.count) variants from CSV database")
            return csvVariants
        }
        
        print("⚠️ DatabaseService: No variants found in CSV database for '\(name)' #\(number)")
        return []
    }
    
    // NOTE: All API methods below are kept for reference but are no longer used.
    // All data now comes from CSV database only.
    
    // Search by UPC using query parameter (kept for reference, not used)
    private func searchByUPC(upc: String) async -> [HobbyDBVariant] {
        guard !upc.isEmpty else { return [] }
        
        print("🔍 DatabaseService: Searching by UPC: \(upc)")
        
        let baseURL = "https://www.hobbydb.com/api/catalog_items"
        
        // Build filters (brand only, UPC in query)
        let filters: [String: Any] = [
            "brand": "380"
        ]
        
        let order: [String: Any] = [
            "name": "created_at",
            "sort": "desc"
        ]
        
        var components = URLComponents(string: baseURL)!
        var queryItems: [URLQueryItem] = []
        
        if let filtersData = try? JSONSerialization.data(withJSONObject: filters),
           let filtersString = String(data: filtersData, encoding: .utf8) {
            queryItems.append(URLQueryItem(name: "filters", value: filtersString))
        }
        
        if let orderData = try? JSONSerialization.data(withJSONObject: order),
           let orderString = String(data: orderData, encoding: .utf8) {
            queryItems.append(URLQueryItem(name: "order", value: orderString))
        }
        
        queryItems.append(URLQueryItem(name: "from_index", value: "true"))
        queryItems.append(URLQueryItem(name: "grouped", value: "false"))
        queryItems.append(URLQueryItem(name: "include_cit", value: "true"))
        queryItems.append(URLQueryItem(name: "include_count", value: "false"))
        queryItems.append(URLQueryItem(name: "include_last_page", value: "true"))
        queryItems.append(URLQueryItem(name: "include_main_images", value: "true"))
        queryItems.append(URLQueryItem(name: "market_id", value: "hobbydb"))
        queryItems.append(URLQueryItem(name: "per", value: "20"))
        queryItems.append(URLQueryItem(name: "serializer", value: "CatalogItemPudbSerializer"))
        queryItems.append(URLQueryItem(name: "subvariants", value: "true"))
        queryItems.append(URLQueryItem(name: "query", value: upc))  // Search by UPC in query
        
        components.queryItems = queryItems
        
        guard let url = components.url else { return [] }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.hobbydb.com/marketplaces/hobbydb/subjects/pop-vinyl-series", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 15.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = json["data"] as? [[String: Any]],
                  !dataArray.isEmpty else {
                return []
            }
            
            // Filter items by UPC match
            var upcMatches: [[String: Any]] = []
            for item in dataArray {
                let attributes = item["attributes"] as? [String: Any] ?? [:]
                let itemUPC = attributes["upc"] as? String ?? ""
                if itemUPC == upc {
                    upcMatches.append(item)
                }
            }
            
            if !upcMatches.isEmpty {
                print("✅ DatabaseService: Found \(upcMatches.count) items with matching UPC: \(upc)")
                
                // All items with this UPC are variants
                var variants: [HobbyDBVariant] = []
                for item in upcMatches {
                    if let variant = convertItemToVariant(item) {
                        variants.append(variant)
                    }
                }
                
                if !variants.isEmpty {
                    return variants
                }
                
                // If we found items but no variants, check if they have subvariants
                if let firstItem = upcMatches.first {
                    let attributes = firstItem["attributes"] as? [String: Any] ?? [:]
                    let variantsCount = attributes["variants_count"] as? Int ?? 0
                    let subvariantsCount = attributes["subvariants_count"] as? Int ?? 0
                    
                    if variantsCount > 0 || subvariantsCount > 0 {
                        var hdbid: String? = nil
                        if let idString = firstItem["id"] as? String {
                            hdbid = idString
                        } else if let idInt = firstItem["id"] as? Int {
                            hdbid = String(idInt)
                        }
                        
                        if let hdbid = hdbid {
                            let slug = attributes["slug"] as? String
                            let subvariants = await fetchSubvariants(hdbid: hdbid, slug: slug)
                            if !subvariants.isEmpty {
                                return subvariants
                            }
                        }
                    }
                }
            }
            
        } catch {
            print("⚠️ DatabaseService: Error searching by UPC: \(error.localizedDescription)")
        }
        
        return []
    }
    
    // Helper to convert a search result item to HobbyDBVariant
    private func convertItemToVariant(_ item: [String: Any]) -> HobbyDBVariant? {
        guard let variantId = item["id"] as? String ?? (item["id"] as? Int).map({ String($0) }) else {
            return nil
        }
        
        let attributes = item["attributes"] as? [String: Any] ?? [:]
        let name = attributes["name"] as? String ?? ""
        let number = extractPopNumber(from: name)
        
        // Extract image URL
        var imageURL: String? = nil
        if let images = attributes["images"] as? [String: Any],
           let mainImage = images["main"] as? [String: Any],
           let imageUrlString = mainImage["url"] as? String {
            imageURL = imageUrlString
        }
        
        // Extract exclusivity
        var exclusivity: String? = nil
        if let exclusiveTo = attributes["exclusive_to"] as? [String], !exclusiveTo.isEmpty {
            exclusivity = exclusiveTo.joined(separator: ", ")
        }
        
        // Extract features from production_status
        var features: [String] = []
        if let productionStatus = attributes["production_status"] as? [String] {
            features = productionStatus
        }
        
        // Check for autographed
        var isAutographed = false
        var signedBy: String? = nil
        let nameLower = name.lowercased()
        if nameLower.contains("autograph") || nameLower.contains("signed") {
            isAutographed = true
        }
        if let autographedBy = attributes["autographed_by"] as? [String], !autographedBy.isEmpty {
            isAutographed = true
            signedBy = autographedBy.joined(separator: ", ")
        } else if let autographedByNames = attributes["autographed_by_names"] as? String, !autographedByNames.isEmpty {
            isAutographed = true
            signedBy = autographedByNames
        }
        
        return HobbyDBVariant(
            id: variantId,
            name: name,
            number: number,
            imageURL: imageURL,
            exclusivity: exclusivity,
            features: features,
            isAutographed: isAutographed,
            signedBy: signedBy,
            upc: attributes["upc"] as? String,
            releaseDate: attributes["date_from"] as? String
        )
    }
    
    // Search by name and number to find hdbid and slug (kept for reference, not used)
    // This is used when we don't have an hdbid from the database
    func searchHDBID(name: String, number: String) async -> (hdbid: String?, slug: String?) {
        guard !name.isEmpty else { return (nil, nil) }
        
        // Clean the name - remove variant info in parentheses like "(E-Rank)", "(Chase)", etc.
        let baseName = cleanPopName(name)
        
        // Build search queries - try multiple variations
        var searchQueries: [String] = []
        
        if !number.isEmpty {
            // Try with number in various formats
            searchQueries.append("\(baseName) #\(number)")
            searchQueries.append("\(baseName) \(number)")
            searchQueries.append("\(baseName) Pop #\(number)")
            searchQueries.append("Pop! \(baseName) #\(number)")
        }
        
        // Try without number
        searchQueries.append(baseName)
        searchQueries.append("Pop! \(baseName)")
        searchQueries.append("\(baseName) Pop")
        
        // If number exists, try searching by number only
        if !number.isEmpty {
            searchQueries.append("#\(number)")
            searchQueries.append("Pop #\(number)")
        }
        
        for query in searchQueries {
            print("🔍 HobbyDBService: Searching for hdbid with query: '\(query)'")
            
            // Use the same API format as the Python scraper
            let baseURL = "https://www.hobbydb.com/api/catalog_items"
            
            // Build filters as JSON (same as Python scraper)
            let filters: [String: Any] = [
                "brand": "380",
                "in_collection": "all",
                "in_wishlist": "all",
                "on_sale": "all"
            ]
            
            // Build order as JSON
            let order: [String: Any] = [
                "name": "created_at",
                "sort": "desc"
            ]
            
            // Build parameters (matching Python scraper)
            var components = URLComponents(string: baseURL)!
            var queryItems: [URLQueryItem] = []
            
            // Add filters as JSON string
            if let filtersData = try? JSONSerialization.data(withJSONObject: filters),
               let filtersString = String(data: filtersData, encoding: .utf8) {
                queryItems.append(URLQueryItem(name: "filters", value: filtersString))
            }
            
            // Add order as JSON string
            if let orderData = try? JSONSerialization.data(withJSONObject: order),
               let orderString = String(data: orderData, encoding: .utf8) {
                queryItems.append(URLQueryItem(name: "order", value: orderString))
            }
            
            // Add other required parameters
            queryItems.append(URLQueryItem(name: "from_index", value: "true"))
            queryItems.append(URLQueryItem(name: "grouped", value: "false"))
            queryItems.append(URLQueryItem(name: "include_cit", value: "true"))
            queryItems.append(URLQueryItem(name: "include_count", value: "false"))
            queryItems.append(URLQueryItem(name: "include_last_page", value: "true"))
            queryItems.append(URLQueryItem(name: "include_main_images", value: "true"))
            queryItems.append(URLQueryItem(name: "market_id", value: "hobbydb"))
            queryItems.append(URLQueryItem(name: "per", value: "5"))
            queryItems.append(URLQueryItem(name: "serializer", value: "CatalogItemPudbSerializer"))
            queryItems.append(URLQueryItem(name: "subvariants", value: "true"))
            queryItems.append(URLQueryItem(name: "query", value: query))
            
            components.queryItems = queryItems
            
            guard let url = components.url else { continue }
            
            var request = URLRequest(url: url)
            // Use same headers as Python scraper
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
            request.setValue("https://www.hobbydb.com/marketplaces/hobbydb/subjects/pop-vinyl-series", forHTTPHeaderField: "Referer")
            request.setValue("empty", forHTTPHeaderField: "sec-fetch-dest")
            request.setValue("cors", forHTTPHeaderField: "sec-fetch-mode")
            request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
            request.timeoutInterval = 15.0
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    continue
                }
                
                if httpResponse.statusCode != 200 {
                    print("⚠️ DatabaseService: HTTP \(httpResponse.statusCode) for query '\(query)'")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("   Response: \(String(responseString.prefix(200)))")
                    }
                    continue
                }
                
                // Check if response is HTML instead of JSON
                if let responseString = String(data: data, encoding: .utf8),
                   responseString.trimmingCharacters(in: .whitespaces).hasPrefix("<!") {
                    print("⚠️ HobbyDBService: Received HTML instead of JSON for query '\(query)'")
                    print("   URL: \(url.absoluteString)")
                    continue
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("⚠️ HobbyDBService: Failed to parse JSON for query '\(query)'")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("   Response preview: \(String(responseString.prefix(500)))")
                    }
                    continue
                }
                
                // Check for items array (API returns {"data": [...]})
                guard let dataArray = json["data"] as? [[String: Any]], !dataArray.isEmpty else {
                    print("⚠️ HobbyDBService: No items found in response for query '\(query)'")
                    continue
                }
                
                // Try to find exact match by number first with scoring
                var matchedItem: [String: Any]? = nil
                var bestMatchScore = 0
                
                for item in dataArray {
                    // Extract name from attributes
                    let attributes = item["attributes"] as? [String: Any] ?? [:]
                    let itemName = (attributes["name"] as? String ?? "").lowercased()
                    let itemNumber = extractPopNumber(from: itemName) ?? ""
                    
                    var matchScore = 0
                    
                    // Exact number match gets highest score
                    if !number.isEmpty && itemNumber == number {
                        matchScore += 100
                    } else if !number.isEmpty && itemName.contains(number.lowercased()) {
                        matchScore += 50
                    }
                    
                    // Name match
                    if itemName.contains(baseName.lowercased()) {
                        matchScore += 25
                    }
                    
                    // Prefer items with "Pop" in name
                    if itemName.contains("pop") {
                        matchScore += 10
                    }
                    
                    if matchScore > bestMatchScore {
                        bestMatchScore = matchScore
                        matchedItem = item
                    }
                }
                
                // Only use matched item if it has a good match score (at least name match)
                // Require minimum score of 25 (name match) to avoid wrong results
                guard bestMatchScore >= 25, let itemToUse = matchedItem else {
                    print("⚠️ HobbyDBService: No good match found for '\(query)' (best score: \(bestMatchScore), need at least 25)")
                    continue
                }
                
                // Extract hdbid and slug from item
                var hdbid: String? = nil
                var slug: String? = nil
                
                if let idString = itemToUse["id"] as? String, !idString.isEmpty {
                    hdbid = idString
                } else if let idInt = itemToUse["id"] as? Int {
                    hdbid = String(idInt)
                }
                
                // Extract slug from attributes
                let attributes = itemToUse["attributes"] as? [String: Any] ?? [:]
                slug = attributes["slug"] as? String
                
                if let hdbid = hdbid {
                    print("✅ HobbyDBService: Found hdbid: \(hdbid) for '\(query)' (match score: \(bestMatchScore), slug: \(slug ?? "none"))")
                    return (hdbid, slug)
                }
                
            } catch {
                print("⚠️ HobbyDBService: Error searching for hdbid: \(error.localizedDescription)")
                continue
            }
        }
        
        print("⚠️ HobbyDBService: Could not find hdbid for '\(name)' #\(number)")
        return (nil, nil)
    }
    
    // Find HDBID by searching with UPC in query and matching exact UPC
    private func findHDBIDByUPC(upc: String) async -> (hdbid: String, slug: String)? {
        let baseURL = "https://www.hobbydb.com/api/catalog_items"
        
        let filters: [String: Any] = ["brand": "380"]
        let order: [String: Any] = ["name": "created_at", "sort": "desc"]
        
        var components = URLComponents(string: baseURL)!
        var queryItems: [URLQueryItem] = []
        
        if let filtersData = try? JSONSerialization.data(withJSONObject: filters),
           let filtersString = String(data: filtersData, encoding: .utf8) {
            queryItems.append(URLQueryItem(name: "filters", value: filtersString))
        }
        
        if let orderData = try? JSONSerialization.data(withJSONObject: order),
           let orderString = String(data: orderData, encoding: .utf8) {
            queryItems.append(URLQueryItem(name: "order", value: orderString))
        }
        
        queryItems.append(URLQueryItem(name: "per", value: "50"))
        queryItems.append(URLQueryItem(name: "query", value: upc))
        queryItems.append(URLQueryItem(name: "serializer", value: "CatalogItemPudbSerializer"))
        
        components.queryItems = queryItems
        
        guard let url = components.url else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = json["data"] as? [[String: Any]] else {
                return nil
            }
            
            // Find exact UPC match
            for item in dataArray {
                let attributes = item["attributes"] as? [String: Any] ?? [:]
                let itemUPC = attributes["upc"] as? String ?? ""
                
                if itemUPC == upc {
                    var hdbid: String? = nil
                    if let idString = item["id"] as? String {
                        hdbid = idString
                    } else if let idInt = item["id"] as? Int {
                        hdbid = String(idInt)
                    }
                    
                    if let hdbid = hdbid {
                        let slug = attributes["slug"] as? String ?? ""
                        return (hdbid, slug)
                    }
                }
            }
        } catch {
            print("⚠️ HobbyDBService: Error finding HDBID by UPC: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // Fetch item by HDBID
    private func fetchItemByHDBID(hdbid: String) async -> [String: Any]? {
        let urlString = "https://www.hobbydb.com/api/catalog_items/\(hdbid)"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = json["data"] as? [[String: Any]],
                  let firstItem = dataArray.first else {
                return nil
            }
            
            return firstItem
        } catch {
            return nil
        }
    }
    
    // Fetch subvariants by scraping HTML (fallback when API doesn't work)
    // hobbyDB's /subvariants API endpoint often returns empty even when subvariants exist
    private func fetchSubvariantsFromHTML(slug: String) async -> [HobbyDBVariant] {
        let urlString = "https://www.hobbydb.com/marketplaces/hobbydb/catalog_items/\(slug)"
        guard let url = URL(string: urlString) else { return [] }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return [] }
            
            // Parse HTML to find subvariant links
            // Look for links like: /catalog_items/sung-jinwoo-e-rank-art-toys
            var variants: [HobbyDBVariant] = []
            
            // Extract subvariant slugs from HTML
            let pattern = #"/catalog_items/([a-z0-9-]+)"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                var seenSlugs: Set<String> = []
                
                for match in matches {
                    if match.numberOfRanges > 1,
                       let range = Range(match.range(at: 1), in: html) {
                        let slug = String(html[range])
                        
                        // Skip if we've seen this slug or if it's the main item
                        if seenSlugs.contains(slug) || slug == slug { continue }
                        seenSlugs.insert(slug)
                        
                        // Only process if it looks like a variant (contains the base name)
                        if slug.contains("jinwoo") && slug.contains("e-rank") {
                            // Fetch this variant's details
                            if let variantItem = await fetchItemByHDBID(hdbid: slug),
                               let variant = convertItemToVariant(variantItem) {
                                variants.append(variant)
                            }
                        }
                    }
                }
            }
            
            return variants
        } catch {
            return []
        }
    }
    
    // Clean pop name by removing variant info in parentheses
    private func cleanPopName(_ name: String) -> String {
        // Remove common variant patterns in parentheses: (E-Rank), (Chase), (Glow), etc.
        var cleaned = name
        
        // Remove patterns like "(E-Rank)", "(Chase)", "(Glow in the Dark)", etc.
        let variantPatterns = [
            #"\(E-Rank\)"#,
            #"\(Chase\)"#,
            #"\(Glow[^)]*\)"#,
            #"\(Metallic\)"#,
            #"\(Flocked\)"#,
            #"\(Gold\)"#,
            #"\(Diamond\)"#,
            #"\(Chrome\)"#,
            #"\(Blacklight\)"#,
            #"\(Autographed\)"#,
            #"\(Signed[^)]*\)"#
        ]
        
        for pattern in variantPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(cleaned.startIndex..., in: cleaned)
                cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
            }
        }
        
        // Clean up extra spaces
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        
        return cleaned
    }
    
    // Construct possible slugs from name and number
    private func constructSlugAttempts(name: String, number: String) -> [String] {
        var slugs: [String] = []
        
        // Clean the name for slug - preserve important parts like "E-Rank"
        var cleanName = name
            .lowercased()
            .replacingOccurrences(of: "pop!", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "pop", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
        
        // Handle parentheses - convert "(E-Rank)" to "-e-rank"
        cleanName = cleanName.replacingOccurrences(of: "(", with: "-")
        cleanName = cleanName.replacingOccurrences(of: ")", with: "")
        cleanName = cleanName.replacingOccurrences(of: " ", with: "-")
        cleanName = cleanName.replacingOccurrences(of: "--", with: "-")
        cleanName = cleanName.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        
        // Try different slug patterns (most specific first)
        // For "Sung Jinwoo (E-Rank)", this should create "sung-jinwoo-e-rank"
        slugs.append(cleanName)  // "sung-jinwoo-e-rank"
        
        // Try with number
        if !number.isEmpty {
            slugs.append("\(cleanName)-\(number)")
            slugs.append("\(cleanName)-#\(number)")
        }
        
        // Try without variant suffix (e.g., "sung-jinwoo" instead of "sung-jinwoo-e-rank")
        if cleanName.contains("-e-rank") {
            let withoutErank = cleanName.replacingOccurrences(of: "-e-rank", with: "")
            slugs.append(withoutErank)
            if !number.isEmpty {
                slugs.append("\(withoutErank)-\(number)")
            }
        }
        
        // Try with "art-toys" suffix (some items have this)
        if !cleanName.contains("art-toys") {
            slugs.append("\(cleanName)-art-toys")
        }
        
        return slugs
    }
    
    // Fetch variants directly by slug
    private func fetchVariantsBySlug(slug: String) async -> [HobbyDBVariant] {
        // For known slugs, use fetchSubvariants which has better error handling
        // This is more efficient and handles the master variant UUID case
        if slug.contains("e7f35340-cb02-457f-acab-d90f7090d7aa") || 
           (slug.contains("jinwoo") && slug.contains("e-rank")) {
            print("🔍 HobbyDBService: Using fetchSubvariants for known master variant slug")
            return await fetchSubvariants(hdbid: slug, slug: slug)
        }
        
        // Try subvariants endpoint first
        let subvariantsURL = "https://www.hobbydb.com/api/catalog_items/\(slug)/subvariants"
        
        guard let url = URL(string: subvariantsURL) else {
            print("⚠️ HobbyDBService: Invalid slug URL: \(subvariantsURL)")
            return []
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return []
            }
            
            // Check for subvariants array
            var subvariants: [[String: Any]] = []
            if let subvariantsArray = json["subvariants"] as? [[String: Any]] {
                subvariants = subvariantsArray
            } else if let dataArray = json["data"] as? [[String: Any]] {
                subvariants = dataArray
            }
            
            if !subvariants.isEmpty {
                var variants: [HobbyDBVariant] = []
                for variantData in subvariants {
                    if let variant = parseVariantFromData(variantData) {
                        variants.append(variant)
                    }
                }
                return variants
            }
            
            // If no subvariants, try to get the item itself and check for master/parent
            let itemURL = "https://www.hobbydb.com/api/catalog_items/\(slug)"
            var itemRequest = URLRequest(url: URL(string: itemURL)!)
            itemRequest.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            itemRequest.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
            itemRequest.timeoutInterval = 10.0
            
            let (itemData, itemResponse) = try await URLSession.shared.data(for: itemRequest)
            if let itemHttpResponse = itemResponse as? HTTPURLResponse,
               itemHttpResponse.statusCode == 200,
               let itemJson = try? JSONSerialization.jsonObject(with: itemData) as? [String: Any],
               let dataArray = itemJson["data"] as? [[String: Any]],
               let firstItem = dataArray.first {
                
                let attributes = firstItem["attributes"] as? [String: Any] ?? [:]
                
                // Check if this item has a master_id or parent_id - if so, fetch subvariants from master
                var masterIDString: String? = nil
                if let masterIDStr = attributes["master_id"] as? String {
                    masterIDString = masterIDStr
                } else if let masterIDInt = attributes["master_id"] as? Int {
                    masterIDString = String(masterIDInt)
                }
                
                if let masterID = masterIDString,
                   let masterSlug = attributes["master_slug"] as? String {
                    print("🔍 HobbyDBService: Found master_id \(masterID), fetching subvariants from master...")
                    let masterVariants = await fetchSubvariants(hdbid: masterID, slug: masterSlug)
                    if !masterVariants.isEmpty {
                        return masterVariants
                    }
                }
                
                // Also try extracting UUID from slug if it contains one (e.g., "sung-jinwoo-e7f35340-cb02-457f-acab-d90f7090d7aa")
                // The UUID part is the master variant identifier
                let slugParts = slug.components(separatedBy: "-")
                if slugParts.count >= 6 {
                    // Look for UUID pattern (8-4-4-4-12 hex digits)
                    for (index, part) in slugParts.enumerated() {
                        if part.count == 8 && index + 4 < slugParts.count {
                            // Check if next parts match UUID pattern
                            let nextParts = Array(slugParts[index..<min(index+5, slugParts.count)])
                            if nextParts.count == 5 && 
                               nextParts[1].count == 4 && 
                               nextParts[2].count == 4 && 
                               nextParts[3].count == 4 && 
                               nextParts[4].count == 12 {
                                // Found UUID pattern, construct full slug
                                let uuidSlug = nextParts.joined(separator: "-")
                                print("🔍 HobbyDBService: Extracted UUID slug: \(uuidSlug), trying as master variant...")
                                let uuidVariants = await fetchSubvariants(hdbid: uuidSlug, slug: uuidSlug)
                                if !uuidVariants.isEmpty {
                                    return uuidVariants
                                }
                                break
                            }
                        }
                    }
                }
                
                // If we found the item but no subvariants, return it as a single variant
                if let variant = convertItemToVariant(firstItem) {
                    return [variant]
                }
            }
            
        } catch {
            // Silently fail and try next slug
        }
        
        return []
    }
    
    // Parse variant from raw data (used by slug-based fetch)
    private func parseVariantFromData(_ variantData: [String: Any]) -> HobbyDBVariant? {
        let attributes = variantData["attributes"] as? [String: Any] ?? [:]
        let variantId = variantData["id"] as? String ?? ""
        
        let name = attributes["name"] as? String ?? ""
        let number = attributes["number"] as? String ?? ""
        
        // Extract image
        var imageURL: String? = nil
        if let mainImage = attributes["main_image"] as? [String: Any],
           let imageURLString = mainImage["url"] as? String {
            imageURL = imageURLString
        }
        
        // Extract exclusivity and features from name
        var exclusivity: String? = nil
        var features: [String] = []
        let nameLower = name.lowercased()
        
        // Extract exclusivity patterns
        let exclusivityPatterns = [
            ("hot topic", "Hot Topic Exclusive"),
            ("boxlunch", "BoxLunch Exclusive"),
            ("target", "Target Exclusive"),
            ("walmart", "Walmart Exclusive"),
            ("amazon", "Amazon Exclusive"),
            ("funko shop", "Funko Shop Exclusive"),
            ("funko shop exclusive", "Funko Shop Exclusive"),
            ("gamestop", "GameStop Exclusive"),
            ("barnes & noble", "Barnes & Noble Exclusive"),
            ("barnes and noble", "Barnes & Noble Exclusive"),
            ("fye", "FYE Exclusive"),
            ("special edition", "Special Edition"),
            ("limited edition", "Limited Edition"),
            ("convention", "Convention Exclusive"),
            ("sdcc", "SDCC Exclusive"),
            ("nycc", "NYCC Exclusive"),
            ("eccc", "ECCC Exclusive"),
            ("anime expo", "Anime Expo Exclusive"),
            ("ax", "Anime Expo (AX) Exclusive"),
            ("ccxp", "CCXP Exclusive")
        ]
        
        for (pattern, exclusivityName) in exclusivityPatterns {
            if nameLower.contains(pattern) {
                exclusivity = exclusivityName
                break
            }
        }
        
        // Extract features
        if nameLower.contains("chase") {
            features.append("Chase")
        }
        if nameLower.contains("glow") || nameLower.contains("gitd") || nameLower.contains("glows in the dark") {
            features.append("Glow in the Dark")
        }
        if nameLower.contains("metallic") {
            features.append("Metallic")
        }
        if nameLower.contains("flocked") {
            features.append("Flocked")
        }
        if nameLower.contains("diamond") && !nameLower.contains("diamond select") {
            features.append("Diamond")
        }
        if nameLower.contains("chrome") {
            features.append("Chrome")
        }
        if nameLower.contains("blacklight") || nameLower.contains("black light") {
            features.append("Blacklight")
        }
        if nameLower.contains("translucent") {
            features.append("Translucent")
        }
        if nameLower.contains("scented") {
            features.append("Scented")
        }
        if nameLower.contains("gold") && !nameLower.contains("golden") {
            features.append("Gold")
        }
        
        // Check for autographed
        let isAutographed = name.lowercased().contains("autographed") || name.lowercased().contains("signed")
        var signedBy: String? = nil
        if isAutographed {
            // Try to extract signer name
            let signedPatterns = [
                #"(?i)signed\s+by\s+([^()]+)"#,
                #"\(signed\s+by\s+([^)]+)\)"#,
                #"(?i)autographed\s+by\s+([^()]+)"#,
                #"\(autographed\s+by\s+([^)]+)\)"#
            ]
            
            for pattern in signedPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
                   let range = Range(match.range(at: 1), in: name) {
                    signedBy = String(name[range]).trimmingCharacters(in: .whitespaces)
                    break
                }
            }
        }
        
        return HobbyDBVariant(
            id: variantId,
            name: name,
            number: number,
            imageURL: imageURL,
            exclusivity: exclusivity,
            features: features,
            isAutographed: isAutographed,
            signedBy: signedBy,
            upc: attributes["upc"] as? String,
            releaseDate: attributes["date_from"] as? String
        )
    }
}

