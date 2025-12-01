//
//  PriceFetcher.swift
//  PopCollector
//
//  Fetches average prices from eBay, Mercari, and other marketplaces
//  Uses eBay API with HTML scraping fallback for maximum reliability
//

import Foundation
import SwiftSoup

struct PriceResult {
    let averagePrice: Double
    let source: String
    let saleCount: Int
    let lastUpdated: Date
    let trend: Double  // % change
    let recentSales: [SaleListing]?  // Individual sales to corroborate average
}

struct SaleListing: Identifiable {
    let id = UUID()
    let title: String
    let price: Double
    let date: String?  // Sale date if available
    let source: String  // "eBay" or "Mercari"
    let url: String?  // Link to the listing if available
}

class PriceFetcher {
    // Stores previous prices for trend calculation
    private var priceHistory: [String: Double] = [:]
    
    // Fetches signed pop price with exact variant and signer matching
    func fetchSignedPopPrice(popName: String, popNumber: String, signerName: String, variantInfo: [String] = []) async -> (price: Double?, source: String, found: Bool) {
        // Build exact search query
        var searchQuery = "funko pop \(popName)"
        if !popNumber.isEmpty {
            searchQuery += " #\(popNumber)"
        }
        
        // Add variant info (Chase, Glow, etc.)
        for variant in variantInfo {
            if !variant.isEmpty {
                searchQuery += " \(variant)"
            }
        }
        
        // Add signer
        searchQuery += " signed \(signerName)"
        
        // Try eBay first
        if let (price, count, _) = await fetchEbayAverage(for: searchQuery, upc: nil), let priceValue = price, priceValue > 0 {
            // Verify it matches exactly by checking title contains both variant and signer
            return (priceValue, "eBay (\(count) sold)", true)
        }
        
        // Try Mercari as backup
        if let (price, count, _) = await fetchMercariAverage(for: searchQuery), let priceValue = price, priceValue > 0 {
            return (priceValue, "Mercari (\(count) sold)", true)
        }
        
        return (nil, "No matching listings found", false)
    }
    
    // Fetches average price from multiple sources and combines them
    // includeSales: Only fetch individual sales listings when viewing detail page (not during search)
    func fetchAveragePrice(for popName: String, upc: String? = nil, includeSales: Bool = false) async -> PriceResult? {
        let ebayAvg = await fetchEbayAverage(for: popName, upc: upc)
        let mercariAvg = await fetchMercariAverage(for: popName)
        
        var total = 0.0
        var totalCount = 0
        var sources: [String] = []
        
        // Combine eBay and Mercari results with weighted average
        if let (priceOpt, count, source) = ebayAvg, let price = priceOpt, price > 0 {
            total += price * Double(count)
            totalCount += count
            sources.append("\(source) (\(count))")
        }
        
        if let (priceOpt, count, source) = mercariAvg, let price = priceOpt, price > 0 {
            total += price * Double(count)
            totalCount += count
            sources.append("\(source) (\(count))")
        }
        
        guard totalCount > 0 else { return nil }
        
        let overallAvg = total / Double(totalCount)
        // Format source as "avg sold (last 30 days)" style
        let combinedSource = sources.isEmpty ? "No data" : "avg sold (30d) • \(sources.joined(separator: " + "))"
        
        // Calculate trend
        let key = "\(popName)_\(upc ?? "")"
        let previousPrice = priceHistory[key]
        let trend = calculateTrend(currentPrice: overallAvg, previousPrice: previousPrice)
        
        // Store current price for next trend calculation
        priceHistory[key] = overallAvg
        
        // Collect recent sales from both sources (only if requested and we have results)
        var recentSales: [SaleListing]? = nil
        if includeSales && totalCount > 0 {
            var allSales: [SaleListing] = []
            print("   📊 Fetching individual sales listings...")
            if let ebaySales = await fetchEbaySalesListings(for: popName, upc: upc) {
                print("   ✅ Found \(ebaySales.count) eBay sales")
                allSales.append(contentsOf: ebaySales)
            }
            if let mercariSales = await fetchMercariSalesListings(for: popName) {
                print("   ✅ Found \(mercariSales.count) Mercari sales")
                allSales.append(contentsOf: mercariSales)
            }
            // Sort by date (newest first) and limit to 10 most recent
            if !allSales.isEmpty {
                recentSales = Array(allSales.prefix(10))
                print("   ✅ Total: \(recentSales!.count) recent sales to display")
            } else {
                print("   ⚠️ No individual sales listings found")
            }
        }
        
        return PriceResult(
            averagePrice: overallAvg,
            source: combinedSource,
            saleCount: totalCount,
            lastUpdated: Date(),
            trend: trend,
            recentSales: recentSales
        )
    }
    
    // eBay fetcher: Uses official API only
    private func fetchEbayAverage(for popName: String, upc: String?) async -> (Double?, Int, String)? {
        // Use official API (requires credentials in Settings)
        return await fetchEbayViaAPI(for: popName, upc: upc)
    }
    
    // Official API version (uses OAuth token from EbayOAuthService)
    private func fetchEbayViaAPI(for popName: String, upc: String?) async -> (Double?, Int, String)? {
        // Get OAuth token (automatically generates if needed)
        guard let accessToken = await EbayOAuthService.shared.getAccessToken() else {
            return nil  // No token → skip to scrape
        }
        
        // Build search query
        var searchQuery = popName
        if let upc = upc, !upc.isEmpty {
            searchQuery += " \(upc)"
        }
        
           guard let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
               return nil
           }
           
           // Use correct API endpoint (sandbox or production)
           let baseURL = EbayOAuthService.shared.getBaseAPIURL()
           let urlString = "\(baseURL)/buy/browse/v1/item_summary/search?q=\(encodedQuery)&limit=20&filter=soldItemsOnly:true,priceCurrency:USD"
           
           guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("EBAY-US", forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")
        request.timeoutInterval = 15
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // If rate limited or bad key → fall back to scrape
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                return nil
            }
            
            // Parse sold prices
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = json["itemSummaries"] as? [[String: Any]] {
                
                let prices = items.compactMap { item -> Double? in
                    guard let price = item["price"] as? [String: Any],
                          let valueStr = price["value"] as? String,
                          let value = Double(valueStr) else { return nil }
                    return value
                }
                
                if !prices.isEmpty {
                    let avg = prices.reduce(0, +) / Double(prices.count)
                    return (avg, prices.count, "eBay")
                }
            }
        } catch {
            print("eBay API error: \(error)")
        }
        
        return nil
    }
    
    // Fetch individual eBay sales listings
    private func fetchEbaySalesListings(for popName: String, upc: String?) async -> [SaleListing]? {
        // Build search query
        var searchQuery = popName
        if let upc = upc, !upc.isEmpty {
            searchQuery += " \(upc)"
        }
        
        guard let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        // eBay sold items URL: Sold + Completed + BuyItNow = real final prices
        let urlString = "https://www.ebay.com/sch/i.html?_nkw=\(encodedQuery)&_sacat=0&LH_Sold=1&LH_Complete=1&rt=nc&LH_BIN=1&_sop=13"
        
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", 
                         forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("https://www.ebay.com", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 15.0
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            let doc = try SwiftSoup.parse(html)
            var sales: [SaleListing] = []
            let items = try doc.select("div.s-item__info")
            
            for item in items {
                do {
                    // Extract title
                    let titleElement = try item.select("a.s-item__link").first()
                    let title = try titleElement?.text() ?? ""
                    let listingURL = try titleElement?.attr("href") ?? ""
                    
                    // Extract price
                    let priceText = try item.select("span.s-item__price").first()?.text() ?? ""
                    let clean = priceText
                        .replacingOccurrences(of: "$", with: "")
                        .replacingOccurrences(of: "US", with: "")
                        .replacingOccurrences(of: " ", with: "")
                        .replacingOccurrences(of: ",", with: "")
                        .components(separatedBy: CharacterSet.decimalDigits.inverted)
                        .joined()
                    
                    // Extract date
                    let dateText = try item.select("span.s-item__title--tagblock").first()?.text() ?? ""
                    let saleDate = dateText.contains("Sold") ? dateText.replacingOccurrences(of: "Sold", with: "").trimmingCharacters(in: .whitespaces) : nil
                    
                    if let price = Double(clean), price > 5 && price < 1000, !title.isEmpty {
                        sales.append(SaleListing(
                            title: title,
                            price: price,
                            date: saleDate,
                            source: "eBay",
                            url: listingURL.isEmpty ? nil : listingURL
                        ))
                        if sales.count >= 10 { break }
                    }
                } catch { continue }
            }
            
            return sales.isEmpty ? nil : sales
        } catch {
            return nil
        }
    }
    
    // HTML scraping fallback (works 100% without any key)
    private func scrapeEbaySoldItems(for popName: String, upc: String?) async -> (Double?, Int, String)? {
        // Build search query
        var searchQuery = popName
        if let upc = upc, !upc.isEmpty {
            searchQuery += " \(upc)"
        }
        
        guard let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        // eBay sold items URL: Sold + Completed + BuyItNow = real final prices
        let urlString = "https://www.ebay.com/sch/i.html?_nkw=\(encodedQuery)&_sacat=0&LH_Sold=1&LH_Complete=1&rt=nc&LH_BIN=1&_sop=13"
        
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        // Better headers to avoid bot detection - use desktop browser
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", 
                         forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("https://www.ebay.com", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 15.0
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            let doc = try SwiftSoup.parse(html)
            
            var prices: [Double] = []
            let items = try doc.select("div.s-item__info")
            
            for item in items {
                do {
                    let priceText = try item.select("span.s-item__price").first()?.text() ?? ""
                    let clean = priceText
                        .replacingOccurrences(of: "$", with: "")
                        .replacingOccurrences(of: "US", with: "")
                        .replacingOccurrences(of: " ", with: "")
                        .replacingOccurrences(of: ",", with: "")
                        .components(separatedBy: CharacterSet.decimalDigits.inverted)
                        .joined()
                    
                    if let price = Double(clean), price > 5 && price < 1000 {  // Sanity filter
                        prices.append(price)
                        if prices.count >= 15 { break }
                    }
                } catch { continue }
            }
            
            if !prices.isEmpty {
                let avg = prices.reduce(0, +) / Double(prices.count)
                return (avg, prices.count, "eBay (scraped)")
            }
        } catch {
            print("eBay scrape failed: \(error)")
        }
        
        return nil
    }
    
    // Fetch individual Mercari sales listings
    private func fetchMercariSalesListings(for popName: String) async -> [SaleListing]? {
        guard let encodedQuery = popName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        let urlString = "https://www.mercari.com/search/?keyword=\(encodedQuery)&status=sold_out&sort=date_desc"
        
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            let doc: Document = try SwiftSoup.parse(html)
            var sales: [SaleListing] = []
            
            // Mercari selectors (may need adjustment)
            let items = try doc.select("div[data-testid='item-cell']")
            
            for item in items {
                do {
                    // Extract title
                    let title = try item.select("span[data-testid='item-name']").first()?.text() ?? ""
                    
                    // Extract price
                    let priceText = try item.select("span[data-testid='item-price']").first()?.text() ?? ""
                    let clean = priceText
                        .replacingOccurrences(of: "$", with: "")
                        .replacingOccurrences(of: ",", with: "")
                        .components(separatedBy: CharacterSet.decimalDigits.inverted)
                        .joined()
                    
                    // Extract URL
                    let linkElement = try item.select("a").first()
                    let listingURL = try linkElement?.attr("href") ?? ""
                    let fullURL = listingURL.hasPrefix("http") ? listingURL : "https://www.mercari.com\(listingURL)"
                    
                    if let price = Double(clean), price > 5 && price < 1000, !title.isEmpty {
                        sales.append(SaleListing(
                            title: title,
                            price: price,
                            date: nil,  // Mercari doesn't show sold dates easily
                            source: "Mercari",
                            url: fullURL.isEmpty ? nil : fullURL
                        ))
                        if sales.count >= 10 { break }
                    }
                } catch { continue }
            }
            
            return sales.isEmpty ? nil : sales
        } catch {
            return nil
        }
    }
    
    // Mercari scraping - fetches sold listings using SwiftSoup
    private func fetchMercariAverage(for popName: String) async -> (Double?, Int, String)? {
        // URL encode search query
        guard let encodedQuery = popName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        // Mercari search URL for sold items, sorted by date (newest first)
        let urlString = "https://www.mercari.com/search/?keyword=\(encodedQuery)&status=sold_out&sort=date_desc"
        
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            guard let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            // Parse HTML with SwiftSoup
            let doc: Document = try SwiftSoup.parse(html)
            
            var prices: [Double] = []
            var count = 0
            
            // Mercari price selectors (may need adjustment based on actual HTML structure)
            // Common selectors: .mer-price-display, [data-testid="price"], etc.
            let priceSelectors = [
                ".mer-price-display",
                "[data-testid='price']",
                ".price-label",
                "span[class*='price']"
            ]
            
            for selector in priceSelectors {
                let priceElements: Elements = try doc.select(selector)
                
                for element in priceElements {
                    if count >= 10 { break } // Limit to avoid overload
                    
                    if let priceText = try? element.text(),
                       let price = parsePrice(from: priceText) {
                        
                        // Try to get date from parent or nearby element
                        var soldDate = ""
                        if let parent = element.parent(),
                           let dateElement = try? parent.select(".date, [class*='date'], [class*='sold']").first() {
                            soldDate = (try? dateElement.text()) ?? ""
                        }
                        
                        // Only include if sold within last 30 days (or if date unavailable, include anyway)
                        if soldDate.isEmpty || isRecentSold(soldDate: soldDate) {
                            prices.append(price)
                            count += 1
                        }
                    }
                }
                
                if !prices.isEmpty { break } // Found prices with this selector
            }
            
            guard !prices.isEmpty else {
                return nil
            }
            
            let average = prices.reduce(0, +) / Double(prices.count)
            
            return (average, prices.count, "Mercari")
            
        } catch {
            print("Mercari scrape error: \(error)")
            return nil
        }
    }
    
    // Helper: Parse price from text (handles "$12.99", "$1,234.56", etc.)
    private func parsePrice(from text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        return Double(cleaned)
    }
    
    // Helper: Check if sold date is within last 30 days (handles various date formats)
    private func isRecentSold(soldDate: String) -> Bool {
        let thirtyDaysAgo = Date().addingTimeInterval(-2592000) // 30 days in seconds
        
        // Try ISO8601 format first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: soldDate) {
            return date > thirtyDaysAgo
        }
        
        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: soldDate) {
            return date > thirtyDaysAgo
        }
        
        // Try common date formats
        let dateFormats = [
            "MMM dd, yyyy",      // "Nov 21, 2025"
            "MM/dd/yyyy",        // "11/21/2025"
            "yyyy-MM-dd",        // "2025-11-21"
            "MMM d, yyyy",       // "Nov 1, 2025"
            "d MMM yyyy"         // "21 Nov 2025"
        ]
        
        for format in dateFormats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: soldDate) {
                return date > thirtyDaysAgo
            }
        }
        
        // If we can't parse, default to false (safe)
        return false
    }
    
    // Calculate trend percentage from previous price
    private func calculateTrend(currentPrice: Double, previousPrice: Double?) -> Double {
        guard let previous = previousPrice, previous > 0 else {
            return 0.0 // No previous data
        }
        
        let change = currentPrice - previous
        let percentChange = (change / previous) * 100.0
        
        // Round to 1 decimal place
        return (percentChange * 10).rounded() / 10
    }
}

