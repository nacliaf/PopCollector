//
//  OnlineSearchSheet.swift
//  PopCollector
//
//  Online search for Funko Pops by name/text query
//

import SwiftUI
import SwiftData

// Enhanced search result with price
struct SearchResultWithPrice: Identifiable, @unchecked Sendable {
    let id: UUID
    let result: PopLookupResult
    var price: Double?
    var priceSource: String?
    
    nonisolated init(result: PopLookupResult, price: Double? = nil, priceSource: String? = nil) {
        self.id = result.id
        self.result = result
        self.price = price
        self.priceSource = priceSource
    }
}

// Unique Pop with all its listings aggregated (Pop-based, not listing-based)
struct UniquePop: Identifiable {
    let id: UUID
    let baseName: String  // Clean name without signed/autograph keywords
    let number: String
    var series: String
    var imageURL: String
    var productURL: String?  // URL to product page
    
    // ALL listings for this Pop (from Funko.com and official database sources)
    var allListings: [SearchResultWithPrice]
    
    init(baseName: String, number: String, series: String, imageURL: String, productURL: String? = nil) {
        self.id = UUID()
        self.baseName = baseName
        self.number = number
        self.series = series
        self.imageURL = imageURL
        self.productURL = productURL
        self.allListings = []
    }
    
    var displayName: String {
        // If we have listings, check if any contain variant info in the name
        // Variants like "E-Rank", "Upgrade", "Glow", etc. should be shown
        if let listingWithVariant = allListings.first(where: { listing in
            let name = listing.result.name.lowercased()
            return name.contains("e-rank") || name.contains("upgrade") || 
                   name.contains("glow") || name.contains("chase") ||
                   name.contains("metallic") || name.contains("limited edition") ||
                   name.contains("2025 anime")
        }) {
            // Return the original name from the listing (which includes variant info)
            return listingWithVariant.result.name
        }
        // Otherwise return the base name
        return baseName
    }
    
    // Get Pop number (from struct or first listing that has it)
    var displayNumber: String {
        if !number.isEmpty {
            return number
        }
        // Try to get from listings
        if let listingNumber = allListings.first(where: { !$0.result.number.isEmpty })?.result.number {
            return listingNumber
        }
        return ""
    }
    
    // Best image from all listings (use the specific image for this variant)
    var primaryImage: String {
        // Since each UniquePop represents a single variant/listing with its own image from CSV,
        // directly use the imageURL property which was set from the CSV entry during initialization
        // This ensures each variant displays its unique image from the database
        if !imageURL.isEmpty {
            return imageURL
        }
        
        // Fallback: Use the listing's imageURL if imageURL property is empty
        if let listingImage = allListings.first(where: { !$0.result.imageURL.isEmpty })?.result.imageURL {
            return listingImage
        }
        
        return ""
    }
    
    // Average price from all listings
    var averagePrice: Double? {
        let prices = allListings.compactMap { $0.price }.filter { $0 > 0 }
        guard !prices.isEmpty else { return nil }
        return prices.reduce(0, +) / Double(prices.count)
    }
    
    // Minimum price
    var minPrice: Double? {
        let prices = allListings.compactMap { $0.price }.filter { $0 > 0 }
        return prices.min()
    }
    
    // Maximum price
    var maxPrice: Double? {
        let prices = allListings.compactMap { $0.price }.filter { $0 > 0 }
        return prices.max()
    }
    
    // Check if has regular variants
    var hasRegular: Bool {
        allListings.contains { !$0.result.isSigned }
    }
    
    // Check if has signed variants
    var hasSigned: Bool {
        allListings.contains { $0.result.isSigned }
    }
    
    // Get exclusivity from listings - collect from all listings to catch all exclusivity types
    var exclusivity: String {
        var exclusivities: Set<String> = []
        for listing in allListings {
            if !listing.result.exclusivity.isEmpty {
                // Handle multiple exclusivities separated by •
                let parts = listing.result.exclusivity.components(separatedBy: " • ")
                exclusivities.formUnion(parts)
            }
        }
        return exclusivities.isEmpty ? "" : exclusivities.sorted().joined(separator: " • ")
    }
    
    // Get features from listings
    var features: [String] {
        var allFeatures: Set<String> = []
        for listing in allListings {
            allFeatures.formUnion(listing.result.features)
        }
        return Array(allFeatures).sorted()
    }
}

// Legacy support - keeping for backward compatibility with GroupedPopDetailView
struct GroupedPopWithVariants: Identifiable {
    let id: UUID
    let baseName: String
    var number: String
    var series: String
    var imageURL: String
    
    var regularVariant: SearchResultWithPrice?
    var signedVariant: SearchResultWithPrice?
    
    init(baseName: String, number: String, series: String, imageURL: String) {
        self.id = UUID()
        self.baseName = baseName
        self.number = number
        self.series = series
        self.imageURL = imageURL
        self.regularVariant = nil
        self.signedVariant = nil
    }
    
    // Convert from UniquePop
    init(from uniquePop: UniquePop) {
        self.id = uniquePop.id
        self.baseName = uniquePop.baseName
        self.number = uniquePop.number
        self.series = uniquePop.series
        self.imageURL = uniquePop.primaryImage
        
        // Find best regular and signed variants
        let regularListings = uniquePop.allListings.filter { !$0.result.isSigned }
        let signedListings = uniquePop.allListings.filter { $0.result.isSigned }
        
        self.regularVariant = regularListings.max { ($0.price ?? 0) < ($1.price ?? 0) }
        self.signedVariant = signedListings.max { ($0.price ?? 0) < ($1.price ?? 0) }
    }
    
    var displayName: String { baseName }
    var primaryImage: String { imageURL }
    var hasRegular: Bool { regularVariant != nil }
    var hasSigned: Bool { signedVariant != nil }
}

// Grouped Pop result showing unique Pops with all their variants
struct GroupedPopResult: Identifiable {
    let id: UUID
    let name: String
    let number: String
    let variants: [SearchResultWithPrice] // All listings/variants of this Pop
    
    var primaryResult: SearchResultWithPrice {
        // Use the first variant (or best match) as primary
        variants.first ?? variants[0]
    }
    
    var averagePrice: Double? {
        let prices = variants.compactMap { $0.price }.filter { $0 > 0 }
        guard !prices.isEmpty else { return nil }
        return prices.reduce(0, +) / Double(prices.count)
    }
}

struct OnlineSearchSheet: View {
    @Binding var searchQuery: String
    @Binding var searchResults: [PopLookupResult]
    @Binding var isSearching: Bool
    let folders: [PopFolder]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPop: UniquePop? // Selected Pop to show details
    @State private var resultsWithPrices: [SearchResultWithPrice] = []
    @State private var uniquePops: [UniquePop] = [] // Unique Pops with all listings aggregated
    @State private var showingFolderPicker = false
    @State private var showingSignedPrompt = false
    @State private var pendingPop: PopItem?
    
    private let priceFetcher = PriceFetcher()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    TextField("Search for Funko Pop...", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            performSearch()
                        }
                    
                    Button {
                        performSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(searchQuery.isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(searchQuery.isEmpty || isSearching)
                }
                .padding()
                
                // Search results - Grid of unique Pop cards
                if isSearching && uniquePops.isEmpty {
                    ProgressView("Searching online...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !uniquePops.isEmpty {
                    VStack(spacing: 0) {
                        // Total count header
                        HStack {
                            Text("Total: \(uniquePops.count) Pops")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        
                        // Grid of Pop cards
                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 16) {
                                ForEach(uniquePops) { pop in
                                    PopCard(pop: pop)
                                        .onTapGesture {
                                            selectedPop = pop
                                        }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                } else if !searchQuery.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term")
                    )
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Search for Funko Pops")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Enter a Pop name, character, or series to search Funko.com")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Search Online")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedPop) { pop in
                PopDetailSheet(
                    pop: pop,
                    folders: folders
                )
            }
            .sheet(isPresented: $showingFolderPicker) {
                if let pop = pendingPop {
                    AddToFolderSheet(pop: pop, folders: folders, context: context)
                }
            }
            .sheet(isPresented: $showingSignedPrompt) {
                if let pop = pendingPop {
                    SignedPopPromptSheet(pop: pop, context: context, popDisplayName: nil, popNumber: nil)
                        .onDisappear {
                            if let pop = pendingPop {
                                Task {
                                    // Fetch price
                                    if let priceResult = await priceFetcher.fetchAveragePrice(for: pop.name, upc: pop.upc) {
                                        await MainActor.run {
                                            pop.value = priceResult.averagePrice
                                            pop.lastUpdated = priceResult.lastUpdated
                                            pop.source = priceResult.source
                                            pop.trend = priceResult.trend
                                        }
                                    }
                                    
                                    // Show folder selection
                                    await MainActor.run {
                                        showingFolderPicker = true
                                    }
                                }
                            }
                        }
                }
            }
        }
    }
    
    private     func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        // Clear previous results
        isSearching = true
        searchResults = []
        resultsWithPrices = []
        uniquePops = [] // Clear unique pops
        
        Task {
            // print("🔍 Starting search for: '\(searchQuery)'")
            
            // Show results IMMEDIATELY as they come in
            // Start with the basic search (fastest)
            let cleanQuery = searchQuery.trimmingCharacters(in: .whitespaces)
            
            // Search local Excel database only (master variants only, no autographed, no subvariants)
            let quickResults = await FunkoDatabaseService.shared.searchLocalDatabase(query: cleanQuery, modelContext: context, includeAutographed: false)
            
            // Fast mapping - just use database fields directly
            // Show all results including autographed
            let quickLookupResults = quickResults.map { dbResult -> PopLookupResult in
                var result = PopLookupResult(
                    name: dbResult.name,
                    number: dbResult.number,
                    series: dbResult.series,
                    imageURL: dbResult.imageURL,
                    source: dbResult.source,
                    productURL: dbResult.productURL
                )
                result.hdbid = dbResult.hdbid
                result.releaseDate = dbResult.releaseDate ?? ""
                result.upc = dbResult.upc ?? ""
                
                // Simple exclusivity - just use exclusiveTo field directly
                if let exclusiveTo = dbResult.exclusiveTo, !exclusiveTo.isEmpty {
                    result.exclusivity = FunkoDatabaseService.shared.extractRetailerName(from: exclusiveTo)
                }
                
                // Check for special features in production status
                if let status = dbResult.productionStatus {
                    let statusLower = status.lowercased()
                    var features: [String] = []
                    if statusLower.contains("chase") { features.append("Chase") }
                    if statusLower.contains("glow") || statusLower.contains("glows in the dark") { 
                        features.append("Glow in the Dark") 
                    }
                    if statusLower.contains("metallic") { features.append("Metallic") }
                    if statusLower.contains("flocked") { features.append("Flocked") }
                    if statusLower.contains("diamond") && !statusLower.contains("diamond select") { features.append("Diamond") }
                    if statusLower.contains("chrome") { features.append("Chrome") }
                    if statusLower.contains("blacklight") || statusLower.contains("black light") { features.append("Blacklight") }
                    if statusLower.contains("translucent") { features.append("Translucent") }
                    if statusLower.contains("scented") { features.append("Scented") }
                    if statusLower.contains("gold") && !statusLower.contains("golden") { features.append("Gold") }
                    if !features.isEmpty { result.features = features }
                }
                
                return result
            }
            
            // Display results immediately
            await MainActor.run {
                let firstBatch = quickLookupResults.map { result in
                    SearchResultWithPrice(result: result, price: nil, priceSource: nil)
                }
                self.resultsWithPrices.append(contentsOf: firstBatch)
                self.searchResults.append(contentsOf: quickLookupResults)
                self.reaggregateUniquePops()
                self.isSearching = false
            }
            
            // Don't fetch subvariants - only show master/unique variants in search
        }
    }
    
    // Fetch variants for search results and add them as additional listings
    private func fetchHobbyDBVariantsForResults(_ results: [PopLookupResult]) async {
        // Only fetch for results that have name and number
        let resultsToFetch = results.filter { !$0.name.isEmpty && !$0.number.isEmpty }.prefix(10) // Limit to first 10
        
        guard !resultsToFetch.isEmpty else { return }
        
        print("🔍 Fetching variants for \(resultsToFetch.count) search results...")
        
        // Fetch variants in parallel (limit to 3 concurrent to avoid overwhelming)
        await withTaskGroup(of: (UUID, [HobbyDBVariant]).self) { group in
            for result in resultsToFetch {
                group.addTask {
                    // If we have hdbid from CSV, use it directly (faster and more reliable)
                    if let hdbid = result.hdbid, !hdbid.isEmpty {
                        print("🔍 Using hdbid from CSV: \(hdbid) for '\(result.name)'")
                        let variants = await HobbyDBService.shared.fetchSubvariants(hdbid: hdbid, slug: nil, includeAutographed: true)
                        if !variants.isEmpty {
                            return (result.id, variants)
                        }
                        // If fetchSubvariants returns empty, fall back to search
                        print("⚠️ No subvariants found for hdbid \(hdbid), falling back to search")
                    }
                    
                    // Fallback: Fetch variants using name, number, and UPC if available
                    let variants = await HobbyDBService.shared.searchAndFetchVariants(
                        name: result.name,
                        number: result.number,
                        upc: result.upc.isEmpty ? nil : result.upc
                    )
                    return (result.id, variants)
                }
            }
            
            // Add variants as new search results as they arrive
            for await (resultId, variants) in group {
                guard !variants.isEmpty else { continue }
                
                await MainActor.run {
                    // Find the original result
                    guard let originalIndex = self.searchResults.firstIndex(where: { $0.id == resultId }) else {
                        return
                    }
                    
                    let originalResult = self.searchResults[originalIndex]
                    
                    // Convert variants to PopLookupResult
                    // Show all variants in search results (including autographed)
                    var newResults: [PopLookupResult] = []
                    for variant in variants {
                        var variantResult = PopLookupResult(
                            name: variant.name,
                            number: variant.number ?? originalResult.number,
                            series: originalResult.series,
                            imageURL: variant.imageURL ?? originalResult.imageURL,
                            source: "Database",
                            productURL: originalResult.productURL
                        )
                        
                        // Set variant-specific properties
                        variantResult.exclusivity = variant.exclusivity ?? ""
                        variantResult.features = variant.features
                        variantResult.upc = variant.upc ?? originalResult.upc
                        variantResult.isSigned = variant.isAutographed
                        variantResult.signedBy = variant.signedBy ?? ""
                        variantResult.hdbid = variant.id
                        variantResult.releaseDate = variant.releaseDate ?? originalResult.releaseDate
                        
                        newResults.append(variantResult)
                    }
                    
                    // Add new results to searchResults and resultsWithPrices
                    self.searchResults.append(contentsOf: newResults)
                    
                    let newResultsWithPrices = newResults.map { result in
                        SearchResultWithPrice(result: result, price: nil, priceSource: nil)
                    }
                    self.resultsWithPrices.append(contentsOf: newResultsWithPrices)
                    
                    // Re-aggregate to update UI with new variants
                    self.reaggregateUniquePops()
                    
                    print("✅ Added \(newResults.count) variants for '\(originalResult.name)'")
                }
            }
        }
        
        print("✅ Finished fetching variants for search results")
    }
    
    // Helper to fetch prices without blocking UI
    private func fetchPricesForResults() async {
        var priceResults: [(UUID, Double?, String?)] = []
        
        // Limit concurrent price fetches to prevent freezing (max 5 at a time)
        let maxConcurrent = 5
        let resultsToFetch = Array(self.searchResults.prefix(50)) // Limit to first 50 results
        
        // Process in chunks to limit concurrent network requests
        var currentIndex = 0
        while currentIndex < resultsToFetch.count {
            let chunk = Array(resultsToFetch[currentIndex..<min(currentIndex + maxConcurrent, resultsToFetch.count)])
            
        await withTaskGroup(of: (UUID, Double?, String?)?.self) { group in
                for result in chunk {
                group.addTask {
                        // Explicitly set includeSales: false for search results
                        if let priceResult = await PriceFetcher().fetchAveragePrice(for: result.name, upc: result.upc, includeSales: false) {
                        return (result.id, priceResult.averagePrice, priceResult.source)
                    } else {
                        return (result.id, nil, nil)
                    }
                }
            }
            
            for await priceResult in group {
                if let result = priceResult {
                    priceResults.append(result)
                }
                }
            }
            
            currentIndex += maxConcurrent
            
            // Small delay between chunks to prevent overwhelming the network
            if currentIndex < resultsToFetch.count {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        
        // Update prices on main thread
        await MainActor.run {
            var updatedResults = self.resultsWithPrices
            for (id, price, source) in priceResults {
                if let index = updatedResults.firstIndex(where: { $0.id == id }) {
                    updatedResults[index].price = price
                    updatedResults[index].priceSource = source
                }
            }
            self.resultsWithPrices = updatedResults
            self.reaggregateUniquePops()
            // print("✅ Updated prices for \(priceResults.count) results")
        }
    }
    
    // Helper functions (from UPCLookupService)
    // Extract exclusivity from stickers first, then fall back to name
    private func extractExclusivity(from name: String, stickers: [String] = []) -> String {
        // First, check stickers for exclusivity (most reliable source)
        if !stickers.isEmpty {
            let stickerExclusivity = extractExclusivityFromStickers(stickers)
            if !stickerExclusivity.isEmpty {
                return stickerExclusivity
            }
        }
        
        // Fall back to name-based extraction
        return extractExclusivityFromName(name)
    }
    
    // Extract exclusivity from sticker array
    private func extractExclusivityFromStickers(_ stickers: [String]) -> String {
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
            "toys'r'us": "Toys R Us Exclusive",  // No spaces variant
            "walgreens": "Walgreens Exclusive",
            "cvs": "CVS Exclusive",
            "7-eleven": "7-Eleven Exclusive",
            "7 eleven": "7-Eleven Exclusive",
            "thinkgeek": "ThinkGeek Exclusive",
            "specialty series": "Specialty Series Exclusive",
            "px previews": "PX Previews Exclusive",
            "previews exclusive": "PX Previews Exclusive",
            "px": "PX Previews Exclusive",  // Common abbreviation
            "previews": "PX Previews Exclusive",  // Sometimes just "Previews"
            "lootcrate": "Lootcrate Exclusive",
            "loot crate": "Lootcrate Exclusive",
            "loot": "Lootcrate Exclusive",  // Sometimes just "Loot"
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
            "piab": "PIAB (Pop In A Box) Exclusive",
            "sam's club": "Sam's Club Exclusive",
            "sams club": "Sam's Club Exclusive",
            "baskin robbins": "Baskin Robbins Exclusive",
            "baskin-robbins": "Baskin Robbins Exclusive",
            "coca-cola store": "Coca-Cola Store Exclusive",
            "coca cola": "Coca-Cola Store Exclusive",
            "coca cola store": "Coca-Cola Store Exclusive",
            // Additional major retailers from CSV
            "five below": "Five Below Exclusive",
            "fivebelow": "Five Below Exclusive",
            "kohl's": "Kohl's Exclusive",
            "kohls": "Kohl's Exclusive",
            "only at kohl's": "Kohl's Exclusive",
            "meijer": "Meijer Exclusive",
            "spencer's": "Spencer's Exclusive",
            "spencers": "Spencer's Exclusive",
            "spirit halloween": "Spirit Halloween Exclusive",
            "urban outfitters": "Urban Outfitters Exclusive",
            "party city": "Party City Exclusive",
            "michaels": "Michaels Exclusive",
            "dick's sporting goods": "Dick's Sporting Goods Exclusive",
            "dicks sporting goods": "Dick's Sporting Goods Exclusive",
            "foot locker": "Foot Locker Exclusive",
            "footlocker": "Foot Locker Exclusive",
            "cinemark": "Cinemark Exclusive",
            "regal cinemas": "Regal Cinemas Exclusive",
            "regal theatres": "Regal Theatres Exclusive",
            "amc theatres": "AMC Theatres Exclusive",
            "amc": "AMC Theatres Exclusive",
            "disney parks": "Disney Parks Exclusive",
            "disney exclusive": "Disney Exclusive",
            "disney": "Disney Exclusive",
            "funko.com": "Funko Shop Exclusive",
            "funko (funko.com)": "Funko Shop Exclusive",
            "crunchyroll": "Crunchyroll Exclusive",
            "netflix shop": "Netflix Shop Exclusive",
            "netflix": "Netflix Shop Exclusive",
            "hbo shop": "HBO Shop Exclusive",
            "hbo": "HBO Shop Exclusive",
            "xbox gear shop": "Xbox Gear Shop Exclusive",
            "xbox": "Xbox Gear Shop Exclusive",
            "playstation": "PlayStation Official Licensed Product",
            "ps4": "PlayStation Official Licensed Product",
            "ps5": "PlayStation Official Licensed Product",
            "pokémon center": "Pokémon Center Exclusive",
            "pokemon center": "Pokémon Center Exclusive",
            "big bad toy store": "Big Bad Toy Store Exclusive",
            "bbts": "Big Bad Toy Store Exclusive",
            "galactic toys": "Galactic Toys Exclusive",
            "chrono toys": "Chrono Toys Exclusive",
            "toy wars": "Toy Wars Exclusive",
            "toywiz": "ToyWiz.com Exclusive",
            "toywiz.com": "ToyWiz.com Exclusive",
            "zavvi": "Zavvi Exclusive",
            "forbidden planet": "Forbidden Planet Exclusive (UK)",
            "fnac": "FNAC Exclusive",
            "underground toys": "Underground Toys Exclusive (UK)",
            "simply toys": "Simply Toys Exclusive",
            "dallas comic show": "Dallas Comic Show Exclusive"
        ]
        
        let knownConventions: [String: String] = [
            "nycc": "NYCC Exclusive",
            "new york comic con": "NYCC Exclusive",
            "sdcc": "SDCC Exclusive",
            "san diego comic con": "SDCC Exclusive",
            "san diego comic-con": "SDCC Exclusive",
            "comic-con": "SDCC Exclusive",
            "eccc": "ECCC Exclusive",
            "emerald city comic con": "ECCC Exclusive",
            "c2e2": "C2E2 Exclusive",
            "fan expo": "Fan Expo Exclusive",
            "fan expo canada": "Fan Expo Canada",
            "dallas comic con": "Dallas Comic Con Exclusive",
            "dallas comic-con": "Dallas Comic Con Exclusive",
            "dallas comic show": "Dallas Comic Show Exclusive",
            "dcc": "Dallas Comic Con Exclusive",
            "wondercon": "WonderCon Exclusive",
            "wonder con": "WonderCon Exclusive",
            "mefcc": "MEFCC Exclusive",
            "middle east film & comic con": "MEFCC Exclusive",
            "alamo city comic con": "Alamo City Comic Con (ACCC)",
            "accc": "Alamo City Comic Con (ACCC)",
            "anime expo": "Anime Expo (AX) Exclusive",
            "ax": "Anime Expo (AX) Exclusive",
            "comic con africa": "Comic Con Africa Exclusive",
            "comic con experience": "Comic Con Experience (CCXP) Exclusives",
            "ccxp": "Comic Con Experience (CCXP) Exclusives",
            "la comic con": "LA Comic Con (LACC)",
            "lacc": "LA Comic Con (LACC)",
            "rhode island comic con": "Rhode Island Comic Con Exclusive",
            "ricc": "Rhode Island Comic Con Exclusive",
            "tampa bay comic con": "Tampa Bay Comic Con Exclusive",
            "tbcc": "Tampa Bay Comic Con Exclusive",
            "fanx asia": "FanX Asia Exclusive",
            "mcm london comic con": "MCM London Comic Con Exclusive",
            "mcm london": "MCM London Comic Con Exclusive",
            "japan expo": "Japan Expo Exclusive",
            "thailand toy expo": "Thailand Toy Expo Exclusive",
            "super manila comic con": "Super Manila Comic Con Limited Edition",
            "power morphicon": "Power Morphicon Exclusive",
            "gencon": "GenCon Exclusive",
            "pax": "PAX Convention Exclusive",
            "pax convention": "PAX Convention Exclusive",
            "e3": "E3 Exclusive",
            "designercon": "DesignerCon Exclusive",
            "designer con": "DesignerCon Exclusive",
            "complex con": "Complex Con Exclusive",
            "comikaze": "Comikaze Exclusive",
            "rupauls drag con": "Rupauls Drag Con Exclusive",
            "rupaul's drag con": "Rupauls Drag Con Exclusive",
            "spooky empire": "Spooky Empire",
            "free comic book day": "Free Comic Book Day Exclusive",
            "fcbd": "Free Comic Book Day Exclusive",
            "halloween comicfest": "Halloween Comicfest",
            "d23": "D23 (The Ultimate Disney Fan Event) Expo",
            "d23 expo": "D23 (The Ultimate Disney Fan Event) Expo",
            "star wars celebration": "Star Wars Celebration Exclusive",
            "wrestle mania": "Wrestle Mania VI",
            "wrestlemania": "Wrestle Mania VI",
            "wwe": "WWE Exclusive",
            "ufc": "UFC Exclusive",
            "convention shared": "Convention Shared Exclusive",
            "shared exclusive": "Convention Shared Exclusive",
            "convention exclusive": "Convention Exclusive",
            "summer convention": "Summer Convention Exclusive",
            "spring convention": "Spring Convention Limited Edition",
            "fall convention": "Fall Convention Limited Edition",
            "winter convention": "Winter Convention Limited Edition"
        ]
        
        // Check each sticker for retailer/convention exclusivity
        for sticker in stickers {
            let stickerLower = sticker.lowercased()
            
            // Check conventions first (more specific)
            for (keyword, exclusivity) in knownConventions {
                if stickerLower.contains(keyword) {
                    return exclusivity
                }
            }
            
            // Then check retailers
            for (keyword, exclusivity) in knownRetailers {
                if stickerLower.contains(keyword) {
                    return exclusivity
                }
            }
        }
        
        return ""
    }
    
    // Known exclusivity by Pop number (for Pops where CSV data might be incomplete)
    private func getKnownExclusivityByNumber(_ number: String) -> String {
        let knownExclusivity: [String: String] = [
            // Amazon Exclusives
            "710": "Amazon Exclusive",  // Goku (Eating Noodles)
            
            // Toys R Us Exclusives
            "69": "Toys R Us Exclusive",  // Geoffrey as Batman
            "2 Pack": "Toys R Us Exclusive",  // Some 2-packs are Toys R Us
            
            // PX Previews Exclusives
            // Add specific PX Previews Pop numbers here as discovered
            
            // Lootcrate Exclusives
            // Add specific Lootcrate Pop numbers here as discovered
        ]
        return knownExclusivity[number] ?? ""
    }
    
    // Extract exclusivity from name (fallback when stickers not available)
    private func extractExclusivityFromName(_ name: String) -> String {
        let nameLower = name.lowercased()
        
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
            "toys'r'us": "Toys R Us Exclusive",  // No spaces variant
            "walgreens": "Walgreens Exclusive",
            "cvs": "CVS Exclusive",
            "7-eleven": "7-Eleven Exclusive",
            "7 eleven": "7-Eleven Exclusive",
            "thinkgeek": "ThinkGeek Exclusive",
            "specialty series": "Specialty Series Exclusive",
            "px previews": "PX Previews Exclusive",
            "previews exclusive": "PX Previews Exclusive",
            "px": "PX Previews Exclusive",  // Common abbreviation
            "previews": "PX Previews Exclusive",  // Sometimes just "Previews"
            "lootcrate": "Lootcrate Exclusive",
            "loot crate": "Lootcrate Exclusive",
            "loot": "Lootcrate Exclusive",  // Sometimes just "Loot"
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
            "baskin-robbins": "Baskin Robbins Exclusive",
            "coca-cola store": "Coca-Cola Store Exclusive",
            "coca cola": "Coca-Cola Store Exclusive",
            "coca cola store": "Coca-Cola Store Exclusive",
            // Additional major retailers from CSV
            "five below": "Five Below Exclusive",
            "fivebelow": "Five Below Exclusive",
            "kohl's": "Kohl's Exclusive",
            "kohls": "Kohl's Exclusive",
            "only at kohl's": "Kohl's Exclusive",
            "meijer": "Meijer Exclusive",
            "spencer's": "Spencer's Exclusive",
            "spencers": "Spencer's Exclusive",
            "spirit halloween": "Spirit Halloween Exclusive",
            "urban outfitters": "Urban Outfitters Exclusive",
            "party city": "Party City Exclusive",
            "michaels": "Michaels Exclusive",
            "dick's sporting goods": "Dick's Sporting Goods Exclusive",
            "dicks sporting goods": "Dick's Sporting Goods Exclusive",
            "foot locker": "Foot Locker Exclusive",
            "footlocker": "Foot Locker Exclusive",
            "cinemark": "Cinemark Exclusive",
            "regal cinemas": "Regal Cinemas Exclusive",
            "regal theatres": "Regal Theatres Exclusive",
            "amc theatres": "AMC Theatres Exclusive",
            "amc": "AMC Theatres Exclusive",
            "disney parks": "Disney Parks Exclusive",
            "disney exclusive": "Disney Exclusive",
            "disney": "Disney Exclusive",
            "funko.com": "Funko Shop Exclusive",
            "funko (funko.com)": "Funko Shop Exclusive",
            "crunchyroll": "Crunchyroll Exclusive",
            "netflix shop": "Netflix Shop Exclusive",
            "netflix": "Netflix Shop Exclusive",
            "hbo shop": "HBO Shop Exclusive",
            "hbo": "HBO Shop Exclusive",
            "xbox gear shop": "Xbox Gear Shop Exclusive",
            "xbox": "Xbox Gear Shop Exclusive",
            "playstation": "PlayStation Official Licensed Product",
            "ps4": "PlayStation Official Licensed Product",
            "ps5": "PlayStation Official Licensed Product",
            "pokémon center": "Pokémon Center Exclusive",
            "pokemon center": "Pokémon Center Exclusive",
            "big bad toy store": "Big Bad Toy Store Exclusive",
            "bbts": "Big Bad Toy Store Exclusive",
            "galactic toys": "Galactic Toys Exclusive",
            "chrono toys": "Chrono Toys Exclusive",
            "toy wars": "Toy Wars Exclusive",
            "toywiz": "ToyWiz.com Exclusive",
            "toywiz.com": "ToyWiz.com Exclusive",
            "zavvi": "Zavvi Exclusive",
            "forbidden planet": "Forbidden Planet Exclusive (UK)",
            "fnac": "FNAC Exclusive",
            "underground toys": "Underground Toys Exclusive (UK)",
            "simply toys": "Simply Toys Exclusive",
            "dallas comic show": "Dallas Comic Show Exclusive"
        ]
        
        let knownConventions: [String: String] = [
            "nycc": "NYCC Exclusive",
            "new york comic con": "NYCC Exclusive",
            "sdcc": "SDCC Exclusive",
            "san diego comic con": "SDCC Exclusive",
            "san diego comic-con": "SDCC Exclusive",
            "comic-con": "SDCC Exclusive",
            "eccc": "ECCC Exclusive",
            "emerald city comic con": "ECCC Exclusive",
            "c2e2": "C2E2 Exclusive",
            "fan expo": "Fan Expo Exclusive",
            "fan expo canada": "Fan Expo Canada",
            "dallas comic con": "Dallas Comic Con Exclusive",
            "dallas comic-con": "Dallas Comic Con Exclusive",
            "dallas comic show": "Dallas Comic Show Exclusive",
            "dcc": "Dallas Comic Con Exclusive",
            "wondercon": "WonderCon Exclusive",
            "wonder con": "WonderCon Exclusive",
            "mefcc": "MEFCC Exclusive",
            "middle east film & comic con": "MEFCC Exclusive",
            "alamo city comic con": "Alamo City Comic Con (ACCC)",
            "accc": "Alamo City Comic Con (ACCC)",
            "anime expo": "Anime Expo (AX) Exclusive",
            "ax": "Anime Expo (AX) Exclusive",
            "comic con africa": "Comic Con Africa Exclusive",
            "comic con experience": "Comic Con Experience (CCXP) Exclusives",
            "ccxp": "Comic Con Experience (CCXP) Exclusives",
            "la comic con": "LA Comic Con (LACC)",
            "lacc": "LA Comic Con (LACC)",
            "rhode island comic con": "Rhode Island Comic Con Exclusive",
            "ricc": "Rhode Island Comic Con Exclusive",
            "tampa bay comic con": "Tampa Bay Comic Con Exclusive",
            "tbcc": "Tampa Bay Comic Con Exclusive",
            "fanx asia": "FanX Asia Exclusive",
            "mcm london comic con": "MCM London Comic Con Exclusive",
            "mcm london": "MCM London Comic Con Exclusive",
            "japan expo": "Japan Expo Exclusive",
            "thailand toy expo": "Thailand Toy Expo Exclusive",
            "super manila comic con": "Super Manila Comic Con Limited Edition",
            "power morphicon": "Power Morphicon Exclusive",
            "gencon": "GenCon Exclusive",
            "pax": "PAX Convention Exclusive",
            "pax convention": "PAX Convention Exclusive",
            "e3": "E3 Exclusive",
            "designercon": "DesignerCon Exclusive",
            "designer con": "DesignerCon Exclusive",
            "complex con": "Complex Con Exclusive",
            "comikaze": "Comikaze Exclusive",
            "rupauls drag con": "Rupauls Drag Con Exclusive",
            "rupaul's drag con": "Rupauls Drag Con Exclusive",
            "spooky empire": "Spooky Empire",
            "free comic book day": "Free Comic Book Day Exclusive",
            "fcbd": "Free Comic Book Day Exclusive",
            "halloween comicfest": "Halloween Comicfest",
            "d23": "D23 (The Ultimate Disney Fan Event) Expo",
            "d23 expo": "D23 (The Ultimate Disney Fan Event) Expo",
            "star wars celebration": "Star Wars Celebration Exclusive",
            "wrestle mania": "Wrestle Mania VI",
            "wrestlemania": "Wrestle Mania VI",
            "wwe": "WWE Exclusive",
            "ufc": "UFC Exclusive",
            "convention shared": "Convention Shared Exclusive",
            "shared exclusive": "Convention Shared Exclusive",
            "convention exclusive": "Convention Exclusive",
            "summer convention": "Summer Convention Exclusive",
            "spring convention": "Spring Convention Limited Edition",
            "fall convention": "Fall Convention Limited Edition",
            "winter convention": "Winter Convention Limited Edition"
        ]
        
        // First, check for exclusivity in brackets [SDCC], [NYCC], etc.
        if let bracketRange = name.range(of: "[") {
            let afterBracket = String(name[bracketRange.upperBound...])
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
        
        // Then check ALL parentheses in the name for known retailers/conventions
        // Use regex to find all parentheses content
        let pattern = "\\(([^)]+)\\)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = name as NSString
            let matches = regex.matches(in: name, options: [], range: NSRange(location: 0, length: nsString.length))
            
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
        
        // Finally, check the entire name for retailer/convention keywords
        // Check conventions first (more specific)
        for (keyword, exclusivity) in knownConventions {
            if nameLower.contains(keyword) {
                return exclusivity
            }
        }
        
        // Then check retailers
        for (keyword, exclusivity) in knownRetailers {
            if nameLower.contains(keyword) {
                return exclusivity
            }
        }
        
        // If no known retailer/convention found, return empty (don't create fake exclusivity)
        return ""
    }
    
    private func extractFeatures(from name: String) -> [String] {
        var features: [String] = []
        let nameLower = name.lowercased()
        if nameLower.contains("chase") { features.append("Chase") }
        if nameLower.contains("glow") { features.append("Glow") }
        if nameLower.contains("metallic") { features.append("Metallic") }
        if nameLower.contains("flocked") { features.append("Flocked") }
        if nameLower.contains("chrome") { features.append("Chrome") }
        if nameLower.contains("black light") { features.append("Black Light") }
        return features
    }
    
    // Helper: Re-aggregate unique pops from current resultsWithPrices
    // Each variant gets its own card - only deduplicate exact duplicates (same HDBID AND same name AND same image)
    private func reaggregateUniquePops() {
        // Deduplicate only exact duplicates (same HDBID AND same name AND same image)
        // Different variants should have different HDBIDs or different images, so they'll all show up
        var seenResults: Set<String> = [] // Key: "hdbid|name|image" or "name|number|source|image"
        var uniqueResults: [SearchResultWithPrice] = []
        
        for resultWithPrice in resultsWithPrices {
            let result = resultWithPrice.result
            
            // Create a unique key for this result (include image to distinguish variants with same hdbid but different images)
            var resultKey: String
            if let hdbid = result.hdbid, !hdbid.isEmpty {
                // Use HDBID + name + image to identify unique variants
                // This ensures variants with different images are shown separately
                resultKey = "\(hdbid)|\(result.name)|\(result.imageURL)"
            } else {
                // Fallback: use name + number + source + image to identify duplicates
                resultKey = "\(result.name)|\(result.number)|\(result.source)|\(result.imageURL)"
            }
            
            // Only skip if we've seen this exact combination before
            if seenResults.contains(resultKey) {
                continue // Skip exact duplicate
            }
            seenResults.insert(resultKey)
            uniqueResults.append(resultWithPrice)
        }
        
        // Create a separate UniquePop for each result (including variants)
        // This way each variant gets its own card and can be clicked separately
        var uniquePopsList: [UniquePop] = []
        
        for resultWithPrice in uniqueResults {
            let originalName = resultWithPrice.result.name.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Use the full original name as baseName to preserve variant info
            // Each variant (E-Rank, Chase, etc.) will be its own card
            let baseName = originalName
            
            // Create a new UniquePop for each variant/listing
            // Each variant should have its own image URL from the database
                var newPop = UniquePop(
                    baseName: baseName,
                    number: resultWithPrice.result.number,
                    series: resultWithPrice.result.series,
                imageURL: resultWithPrice.result.imageURL, // Use the specific image URL for this variant
                    productURL: resultWithPrice.result.productURL
                )
                newPop.allListings.append(resultWithPrice)
            uniquePopsList.append(newPop)
            
            // Debug: Log variant info
            if let hdbid = resultWithPrice.result.hdbid {
                print("📦 Created UniquePop: \(baseName) (hdbid: \(hdbid), image: \(resultWithPrice.result.imageURL.prefix(50))...)")
            }
        }
        
        // Sort by Pop number first, then by name
        let sortedPops = uniquePopsList.sorted { lhs, rhs in
            // If both have numbers, sort by number
            if !lhs.number.isEmpty && !rhs.number.isEmpty {
                if let lhsNum = Int(lhs.number), let rhsNum = Int(rhs.number) {
                    if lhsNum != rhsNum {
                    return lhsNum < rhsNum
                    }
                    // Same number - sort by name to show variants together
                    return lhs.baseName < rhs.baseName
                }
                return lhs.number < rhs.number
            } else if !lhs.number.isEmpty {
                return true  // Numbers come first
            } else if !rhs.number.isEmpty {
                return false
            }
            // Otherwise sort alphabetically by name
            return lhs.baseName < rhs.baseName
        }
        
        // print("✅ Showing \(sortedPops.count) individual variants from \(resultsWithPrices.count) results")
        for (_, _) in sortedPops.enumerated() {
            // print("   \(index + 1). \(pop.displayName) #\(pop.number.isEmpty ? "?" : pop.number)")
        }
        
        self.uniquePops = sortedPops
    }
    
    // Helper: Extract variant information from name (E-Rank, Upgrade, Glow, Chase, etc.)
    private func extractVariantInfo(from name: String) -> String {
        let nameLower = name.lowercased()
        var variants: [String] = []
        
        // Check for variant types - prioritize Chase since it's in Production Status
        if nameLower.contains("chase") {
            variants.append("Chase")
        }
        if nameLower.contains("e-rank") || nameLower.contains("e rank") {
            variants.append("E-Rank")
        }
        if nameLower.contains("upgrade") {
            variants.append("Upgrade")
        }
        if nameLower.contains("glow") || nameLower.contains("glows in the dark") {
            variants.append("Glow")
        }
        if nameLower.contains("metallic") {
            variants.append("Metallic")
        }
        if nameLower.contains("flocked") {
            variants.append("Flocked")
        }
        if nameLower.contains("chrome") {
            variants.append("Chrome")
        }
        if nameLower.contains("limited edition") {
            variants.append("Limited Edition")
        }
        if nameLower.contains("2025 anime") || nameLower.contains("anime 2025") {
            variants.append("2025 Anime")
        }
        if nameLower.contains("common") && !nameLower.contains("uncommon") {
            variants.append("Common")
        }
        
        // If no variants found, return "Standard" to differentiate from variants
        return variants.isEmpty ? "Standard" : variants.joined(separator: " ")
    }
    
    // Helper: Clean Pop name (remove signed/autograph keywords for grouping, but preserve variant info)
    private func cleanPopName(_ name: String) -> String {
        var cleanName = name
        let signedPatterns = [
            " signed by.*",  // "Signed by John Doe"
            " signed",       // "Signed"
            " autograph",    // "Autograph"
            " autographed",  // "Autographed"
            "\\*signed\\*",  // "*Signed*"
            "\\*SIGNED\\*",  // "*SIGNED*"
            " w/ jsa",       // "w/ JSA"
            " w/coa",        // "w/COA"
            " with coa",     // "with COA"
            " authenticated"
        ]
        
        for pattern in signedPatterns {
            cleanName = cleanName.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // Don't remove variant information (E-Rank, Upgrade, Glow, etc.) - we want to keep those
        return cleanName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// Pop Card Component - Funko.com style product card
struct PopCard: View {
    let pop: UniquePop
    
    var body: some View {
        VStack(spacing: 0) {
            // Pop Box Image - Large and prominent (like Funko.com)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(height: 200)
                
                if !pop.primaryImage.isEmpty {
                    AsyncImage(url: URL(string: pop.primaryImage)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .scaleEffect(0.8)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .padding(12)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            // Pop Number - Show prominently at top (always show if available)
            if !pop.displayNumber.isEmpty {
                Text("#\(pop.displayNumber)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(.top, 10)
                    .padding(.horizontal, 8)
            }
            
            // Pop Name - Bold and prominent
            Text(pop.displayName)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.top, 6)
            
            // Variant/Exclusivity note - small text under name
            if !pop.features.isEmpty || !pop.exclusivity.isEmpty {
                Text(variantExclusivityNote)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.top, 2)
            }
            
            // Price at bottom (if available)
            if let avgPrice = pop.averagePrice {
                Text(String(format: "$%.0f", avgPrice))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            } else {
                Spacer()
                    .frame(height: 12)
                    .padding(.bottom, 12)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // Build the variant/exclusivity note text
    private var variantExclusivityNote: String {
        var parts: [String] = []
        
        // Add variant types (Chase, Glow, etc.)
        if !pop.features.isEmpty {
            parts.append(pop.features.joined(separator: " • "))
        }
        
        // Add exclusivity (Hot Topic, SDCC, etc.)
        if !pop.exclusivity.isEmpty {
            parts.append(pop.exclusivity)
        }
        
        return parts.joined(separator: " | ")
    }
    
    private func variantColor(for feature: String) -> Color {
        let featureLower = feature.lowercased()
        if featureLower.contains("chase") { return .red }
        if featureLower.contains("glow") { return .yellow }
        if featureLower.contains("metallic") { return .gray }
        if featureLower.contains("flocked") { return .brown }
        if featureLower.contains("diamond") { return .cyan }
        if featureLower.contains("chrome") { return .purple }
        if featureLower.contains("blacklight") || featureLower.contains("black light") { return .indigo }
        return .orange
    }
}

// Pop Detail Sheet - Shows all retailers/listings for a Pop
struct PopDetailSheet: View {
    let pop: UniquePop
    let folders: [PopFolder]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingFolderPicker = false
    @State private var showingSignedPrompt = false
    @State private var pendingPop: PopItem?
    @State private var detailedInfo: FunkoDatabaseService.PopDetailInfo?
    @State private var isLoadingDetails = false
    @State private var showingMoreEbayListings = false
    @State private var stickerVariants: [FunkoDatabaseService.StickerVariant] = []
    @State private var selectedVariantURL: String? = nil
    @State private var isLoadingVariants = false
    @State private var tempPopForSignedPrompt: PopItem?
    @State private var signedPrice: Double? = nil
    @State private var signedPriceSource: String = ""
    @State private var signedPriceFound: Bool = false
    @State private var aiRecognizedExclusivities: [String] = []  // Exclusivity found from image analysis
    @State private var isAnalyzingImage: Bool = false
    @State private var hobbyDBVariants: [HobbyDBVariant] = []  // Variants from database
    @State private var isLoadingHobbyDBVariants: Bool = false
    @State private var showingVariantSelection: Bool = false
    @State private var selectedVariant: HobbyDBVariant? = nil
    @State private var showAutographedVariants = false
    @State private var autographedVariants: [HobbyDBVariant] = []
    @State private var isLoadingAutographedVariants = false
    private let priceFetcher = PriceFetcher()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    popImageView
                    popDetailsHeader
                    
                    detailedInfoSection
                    
                    // Autographed Variants Toggle
                    autographedVariantsSection
                    
                    Divider()
                        .padding(.horizontal)
                    estimatedPriceSection
                    ebayListingsSection
                    addToCollectionButton
                }
            }
            .navigationTitle("Pop Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                // Initial fetch of variants (including autographed)
                await refetchVariants(includeAutographed: true)
                
                await fetchDetailedInfo()
                // Analyze image for exclusivity stickers using AI
                await analyzeImageForExclusivity()
            }
            .sheet(isPresented: $showingFolderPicker) {
                if let pop = pendingPop {
                    AddToFolderSheet(pop: pop, folders: folders, context: context)
                }
            }
            .sheet(isPresented: $showingSignedPrompt) {
                if let pop = pendingPop {
                    SignedPopPromptSheet(pop: pop, context: context, popDisplayName: nil, popNumber: nil)
                        .onDisappear {
                            if let pop = pendingPop {
                                Task {
                                    if let priceResult = await priceFetcher.fetchAveragePrice(for: pop.name, upc: pop.upc) {
                                        await MainActor.run {
                                            pop.value = priceResult.averagePrice
                                            pop.lastUpdated = priceResult.lastUpdated
                                            pop.source = priceResult.source
                                            pop.trend = priceResult.trend
                                        }
                                    }
                                    await MainActor.run {
                                        showingFolderPicker = true
                                    }
                                }
                            }
                        }
                }
            }
            .sheet(item: $tempPopForSignedPrompt) { tempPop in
                SignedPopPromptSheet(pop: tempPop, context: context, popDisplayName: pop.displayName, popNumber: pop.displayNumber)
                    .onAppear {
                        print("   📋 Showing signed prompt sheet for: \(tempPop.name)")
                    }
                    .onDisappear {
                        print("   📋 Signed prompt dismissed")
                        // Update or create the pop in collection with signed status
                        if let existingPop = findPopInCollection() {
                            existingPop.isSigned = tempPop.isSigned
                            existingPop.signedBy = tempPop.signedBy
                            existingPop.hasCOA = tempPop.hasCOA
                            existingPop.signedValueMultiplier = tempPop.signedValueMultiplier
                            try? context.save()
                            print("✅ Updated existing pop signed status: \(tempPop.signedBy)")
                        } else {
                            // Add new pop to collection with signed status
                            tempPop.isSigned = tempPop.isSigned
                            context.insert(tempPop)
                            try? context.save()
                            print("✅ Added new pop to collection with signed status: \(tempPop.signedBy)")
                        }
                        
                        // Fetch signed pricing if pop is signed
                        if tempPop.isSigned && !tempPop.signedBy.isEmpty {
                            Task {
                                await fetchSignedPrice(popName: pop.displayName, popNumber: pop.displayNumber, signerName: tempPop.signedBy)
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - View Components
    
    private var popImageView: some View {
        Group {
            // Use selected variant image if available, otherwise use pop's primary image
            let imageURL = selectedVariant?.imageURL ?? pop.primaryImage
            if !imageURL.isEmpty {
                AsyncImage(url: URL(string: imageURL)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(height: 300)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 300)
                                    .padding()
                            case .failure:
                                Image(systemName: "photo")
                                    .font(.system(size: 80))
                                    .foregroundColor(.gray)
                                    .frame(height: 300)
                            @unknown default:
                                EmptyView()
                    }
                }
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
                    .frame(height: 300)
                            }
                        }
                    }
                    
    private var popDetailsHeader: some View {
                    VStack(spacing: 12) {
            // Use selected variant name if available, otherwise use pop's display name
            Text(selectedVariant?.name ?? pop.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
            // Use selected variant number if available
            if let variantNumber = selectedVariant?.number, !variantNumber.isEmpty {
                Text("#\(variantNumber)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            } else if !pop.displayNumber.isEmpty {
                            Text("#\(pop.displayNumber)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        if !pop.series.isEmpty {
                            Text(pop.series)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
            // Show exclusivity and features as text under the name (similar to search results)
            Group {
                let displayExclusivityText: String = {
                    // First check selected variant exclusivity
                    if let variant = selectedVariant, let exclusivity = variant.exclusivity, !exclusivity.isEmpty {
                        return exclusivity
                    }
                    
                    // Then check AI-recognized exclusivity from image
                            if !aiRecognizedExclusivities.isEmpty {
                                    return aiRecognizedExclusivities.joined(separator: " • ")
                            }
                            
                            // Then check stickers from detailedInfo
                            if let details = detailedInfo, !details.stickers.isEmpty {
                                return extractExclusivityFromStickers(details.stickers)
                            }
                            
                            // Fallback to pop.exclusivity
                            return pop.exclusivity
                        }()
                        
                let displayFeaturesText: String = {
                    // Prioritize selected variant features
                    if let variant = selectedVariant, !variant.features.isEmpty {
                        return variant.features.joined(separator: " • ")
                    }
                    return pop.features.joined(separator: " • ")
                }()
                
                // Combine exclusivity and features
                let variantInfo: [String] = {
                    var info: [String] = []
                    if !displayExclusivityText.isEmpty {
                        info.append(displayExclusivityText)
                    }
                    if !displayFeaturesText.isEmpty {
                        info.append(displayFeaturesText)
                    }
                    return info
                }()
                
                if !variantInfo.isEmpty {
                    Text(variantInfo.joined(separator: " | "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
                
                // Collect all badges to show (for visual display below)
                        let allStickers: [String] = {
                            var stickers: [String] = []
                            // Add exclusivity
                    if !displayExclusivityText.isEmpty {
                        stickers.append(contentsOf: displayExclusivityText.components(separatedBy: " • "))
                            }
                            // Add features
                    if !displayFeaturesText.isEmpty {
                        stickers.append(contentsOf: displayFeaturesText.components(separatedBy: " • "))
                    }
                            // Add stickers from detailedInfo that aren't already shown
                            if let details = detailedInfo {
                                for sticker in details.stickers {
                                    let stickerLower = sticker.lowercased()
                                    let alreadyShown = stickers.contains { $0.lowercased() == stickerLower || stickerLower.contains($0.lowercased()) || $0.lowercased().contains(stickerLower) }
                                    if !alreadyShown {
                                        stickers.append(sticker)
                                    }
                                }
                            }
                            return stickers
                        }()
                        
                        if !allStickers.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(allStickers, id: \.self) { sticker in
                                        Text(sticker.uppercased())
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(stickerColor(for: sticker).opacity(0.2))
                                            .foregroundColor(stickerColor(for: sticker))
                                            .cornerRadius(6)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
            }
                        .padding(.horizontal)
    }
    
    
    // Find if this pop already exists in the collection
    private func findPopInCollection() -> PopItem? {
        let popNumber = pop.displayNumber
        let popName = pop.baseName
        
        let descriptor = FetchDescriptor<PopItem>(
            predicate: #Predicate<PopItem> { item in
                item.number == popNumber && item.name == popName
            }
        )
        return try? context.fetch(descriptor).first
    }
    
    private func variantColorForSheet(for feature: String) -> Color {
        return stickerColor(for: feature)
    }
    
    private func stickerColor(for sticker: String) -> Color {
        let stickerLower = sticker.lowercased()
        // Variant types
        if stickerLower.contains("chase") { return .red }
        if stickerLower.contains("glow") { return .yellow }
        if stickerLower.contains("metallic") { return .gray }
        if stickerLower.contains("flocked") { return .brown }
        if stickerLower.contains("diamond") { return .cyan }
        if stickerLower.contains("chrome") { return .purple }
        if stickerLower.contains("blacklight") || stickerLower.contains("black light") { return .indigo }
        if stickerLower.contains("translucent") { return .teal }
        if stickerLower.contains("scented") { return .pink }
        // Exclusivity - blue for retailers/conventions
        if stickerLower.contains("exclusive") || stickerLower.contains("hot topic") || 
           stickerLower.contains("target") || stickerLower.contains("walmart") ||
           stickerLower.contains("sdcc") || stickerLower.contains("nycc") ||
           stickerLower.contains("convention") || stickerLower.contains("funko shop") {
            return .blue
        }
        return .orange
    }
    
    // Create a temporary PopItem for the signed prompt
    private func createTempPopForSignedPrompt() -> PopItem? {
        let bestListing = pop.allListings.first { 
            $0.result.source.contains("Database") || 
            $0.result.source.contains("Funko.com")
        } ?? pop.allListings.first
        
        guard let listing = bestListing else {
            return nil
        }
        
        // Check if pop already exists in collection
        if let existingPop = findPopInCollection() {
            return existingPop
        }
        
        // Create new PopItem
        let tempPop = PopItem(
            name: pop.baseName,
            number: pop.number,
            series: pop.series,
            value: pop.averagePrice ?? 0,
            imageURL: pop.primaryImage,
            upc: listing.result.upc,
            source: listing.result.source
        )
        
        return tempPop
    }
    
    // Note: handleAutographedToggle removed - toggle now just filters view, doesn't add to collection
    
    @ViewBuilder
    private var detailedInfoSection: some View {
        if isLoadingDetails {
            HStack {
                ProgressView()
                Text("Loading details...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
        } else if let details = detailedInfo, details.hasData {
                        // Show detailed info only if we have meaningful data
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Funko POP! Details")
                                .font(.headline)
                        .padding(.horizontal)
                    
                            // Sticker Variant Selector (if multiple variants available)
                            if !stickerVariants.isEmpty && stickerVariants.count > 1 {
                                    VStack(alignment: .leading, spacing: 8) {
                                    Text("Select Sticker Variant")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal)
                                        
                                    Picker("Sticker Variant", selection: $selectedVariantURL) {
                                        ForEach(stickerVariants) { variant in
                                            Text(variant.displayName)
                                                .tag(variant.url as String?)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .padding(.horizontal)
                                    .onChange(of: selectedVariantURL) { oldValue, newValue in
                                        if let newURL = newValue {
                                            Task {
                                                await loadVariantDetails(url: newURL)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            
                            // Details Grid
                            VStack(spacing: 12) {
                                if !details.stickers.isEmpty {
                                    DetailRow(label: "Stickers", value: details.stickers.joined(separator: " • "))
                                }
                                
                                if details.variations > 0 {
                                    DetailRow(label: "Variations", value: "\(details.variations) Variant\(details.variations > 1 ? "s" : "")")
                                }
                                
                                if !details.character.isEmpty {
                                    DetailRow(label: "Character", value: details.character)
                                }
                                
                                if !details.releaseDate.isEmpty {
                                    DetailRow(label: "Release Date", value: details.releaseDate)
                                }
                                
                                if !details.category.isEmpty {
                                    DetailRow(label: "Category", value: details.category)
                                }
                                
                                if !details.tvShowCollection.isEmpty {
                                    DetailRow(label: "TV Show Collection", value: details.tvShowCollection)
                                }
                                
                                if !details.show.isEmpty {
                                    DetailRow(label: "Show", value: details.show)
                                }
                                
                                if !details.size.isEmpty {
                                    DetailRow(label: "Size", value: details.size)
                                }
                                
                                if !details.vinylType.isEmpty {
                                    DetailRow(label: "Vinyl Figure or Bobble-Head", value: details.vinylType)
                                }
                                
                                if !details.mediaFranchise.isEmpty {
                                    DetailRow(label: "Media Franchise", value: details.mediaFranchise)
                                }
                                
                                if let value = details.estimatedValue {
                                    DetailRow(label: "Estimated Value (USD)", value: String(format: "$%.2f", value))
                                }
                                
                                if let trend = details.priceTrend {
                                    DetailRow(label: "Price Trend", value: trend)
                                }
                                
                                if let volume = details.monthlyVolume {
                                    DetailRow(label: "Monthly Volume", value: volume)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
        } else if !isLoadingDetails && !pop.displayNumber.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("Detailed information not available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private var autographedVariantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $showAutographedVariants) {
                HStack(spacing: 8) {
                    Image(systemName: "signature")
                        .foregroundColor(.blue)
                    Text("Show Autographed Variants")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal)
            .onChange(of: showAutographedVariants) { oldValue, newValue in
                if newValue {
                    Task {
                        await fetchAutographedVariantsForSheet()
                    }
                } else {
                    autographedVariants = []
                }
            }
            
            // Autographed Variants List
            if showAutographedVariants {
                if isLoadingAutographedVariants {
                    HStack {
                        ProgressView()
                        Text("Loading autographed variants...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                } else if !autographedVariants.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Autographed Variants")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        ForEach(autographedVariants) { variant in
                            AutographedVariantCard(variant: variant)
                        }
                    }
                    .padding(.top, 8)
                } else if !isLoadingAutographedVariants {
                    Text("No autographed variants found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
            }
        }
        .padding(.vertical, 8)
    }
                    
    @ViewBuilder
    private var estimatedPriceSection: some View {
                        VStack(spacing: 12) {
                            Text("Estimated Value")
                                .font(.headline)
                            
            // Show signed price if available, otherwise show regular price
            if let existingPop = findPopInCollection(), existingPop.isSigned && !existingPop.signedBy.isEmpty {
                if signedPriceFound, let price = signedPrice {
                    VStack(spacing: 8) {
                        HStack {
                            Text("🇺🇸")
                                .font(.title2)
                            Text(String(format: "$%.2f", price))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }
                        
                        Text("Signed by \(existingPop.signedBy)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(signedPriceSource)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else if !signedPriceFound && signedPriceSource.contains("No matching") {
                    VStack(spacing: 8) {
                        Text("No matching signed listings found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("for \(pop.displayName) signed by \(existingPop.signedBy)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Loading or fallback to regular price
                    if let avgPrice = pop.averagePrice {
                        HStack {
                            Text("🇺🇸")
                                .font(.title2)
                            Text(String(format: "$%.2f", avgPrice))
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                }
            } else if let avgPrice = pop.averagePrice {
                            HStack(spacing: 24) {
                                VStack {
                                    Text("🇺🇸")
                                        .font(.title2)
                                    Text(String(format: "$%.2f", avgPrice))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                                
                                if let minPrice = pop.minPrice, let maxPrice = pop.maxPrice, minPrice != maxPrice {
                                    VStack {
                                        Text("Range")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(String(format: "$%.2f - $%.2f", minPrice, maxPrice))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                        }
                    }
                }
            }
            
            // Show recent sales if available
            if let sales = detailedInfo?.recentSales, !sales.isEmpty {
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Sales")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ForEach(sales.prefix(5)) { sale in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sale.title)
                                    .font(.caption)
                                    .lineLimit(2)
                                
                                if let date = sale.date {
                                    Text(date)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "$%.2f", sale.price))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text(sale.source)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        if sale.id != sales.prefix(5).last?.id {
                            Divider()
                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
    // Fetch signed pop price from eBay/Mercari
    private func fetchSignedPrice(popName: String, popNumber: String, signerName: String) async {
        // Get variant info from pop
        let variantInfo = pop.features + (pop.exclusivity.isEmpty ? [] : [pop.exclusivity])
        
        let result = await priceFetcher.fetchSignedPopPrice(
            popName: popName,
            popNumber: popNumber,
            signerName: signerName,
            variantInfo: variantInfo
        )
        
        await MainActor.run {
            signedPrice = result.price
            signedPriceSource = result.source
            signedPriceFound = result.found
        }
    }
    
    @ViewBuilder
    private var ebayListingsSection: some View {
        if let details = detailedInfo, !details.ebayListings.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Available Listings")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)
                
                let listingsToShow = showingMoreEbayListings ? details.ebayListings : Array(details.ebayListings.prefix(1))
                
                ForEach(listingsToShow) { listing in
                    EbayListingRow(listing: listing)
                }
                
                if details.ebayListings.count > 1 {
                    Button(action: {
                        showingMoreEbayListings.toggle()
                    }) {
                        HStack {
                            Text(showingMoreEbayListings ? "Show Less" : "Show More (\(details.ebayListings.count - 1) more)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Image(systemName: showingMoreEbayListings ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        } else if !pop.allListings.isEmpty {
                        let variants = groupListingsByVariant(pop.allListings)
                        let hasMultipleVariants = variants.count > 1
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text(hasMultipleVariants ? "Available Variants" : "Available Listings")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if hasMultipleVariants {
                                ForEach(Array(variants.keys.sorted()), id: \.self) { variantType in
                                    if let listings = variants[variantType], !listings.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(variantType)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                
                                                if variantType.uppercased().contains("CHASE") {
                                                    Text("CHASE")
                                                        .font(.caption2)
                                                        .fontWeight(.bold)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.red.opacity(0.2))
                                                        .foregroundColor(.red)
                                                        .cornerRadius(4)
                                                } else if !variantType.contains("Common") {
                                                    Text("VARIANT")
                                                        .font(.caption2)
                                                        .fontWeight(.bold)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.blue.opacity(0.2))
                                                        .foregroundColor(.blue)
                                                        .cornerRadius(4)
                                                }
                                                Spacer()
                                            }
                                            .padding(.horizontal)
                                            .padding(.top, 8)
                                            
                                            ForEach(listings, id: \.id) { listing in
                                                RetailerListingRow(listing: listing)
                                            }
                                        }
                                        .padding(.bottom, 12)
                                    }
                                }
                            } else {
                                ForEach(pop.allListings, id: \.id) { listing in
                                    RetailerListingRow(listing: listing)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
    }
    
    private var addToCollectionButton: some View {
        Button {
            addToCollection()
        } label: {
                                HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add to Collection")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
                                }
                                .padding(.horizontal)
        .padding(.bottom, 20)
                            }
                            
    // Fetch detailed information from product URL
    // MARK: - AI Image Analysis
    
    /// Analyzes the Pop box image for exclusivity stickers using AI
    private func analyzeImageForExclusivity() async {
        guard !pop.primaryImage.isEmpty, let imageURL = URL(string: pop.primaryImage) else {
            return
        }
        
        // Load image from URL
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            guard let uiImage = UIImage(data: data) else {
                return
            }
            
            await analyzeImage(image: uiImage)
        } catch {
            print("⚠️ Failed to load image for AI analysis: \(error)")
        }
    }
    
    /// Analyzes a UIImage for exclusivity stickers
    private func analyzeImage(image: UIImage) async {
        guard !isAnalyzingImage else { return }
        
        await MainActor.run {
            isAnalyzingImage = true
        }
        
        // Use AI to recognize text from the image
        let recognizedExclusivities = await AIExclusivityRecognizer.shared.recognizeExclusivityFromImage(image)
        
        await MainActor.run {
            aiRecognizedExclusivities = recognizedExclusivities
            isAnalyzingImage = false
            
            if !recognizedExclusivities.isEmpty {
                print("🤖 AI recognized exclusivities from image: \(recognizedExclusivities.joined(separator: ", "))")
                
                // Learn from AI recognition if it found something not in the database
                if let firstExclusivity = recognizedExclusivities.first {
                    AIExclusivityRecognizer.shared.learnFromCorrection(
                        popName: pop.displayName,
                        popNumber: pop.displayNumber,
                        correctedExclusivity: firstExclusivity
                    )
                }
            }
        }
    }
    
    private func fetchDetailedInfo() async {
        print("🚀 PopDetailSheet: fetchDetailedInfo() called")
        print("   - Pop name: \(pop.displayName)")
        print("   - Pop number: '\(pop.displayNumber)'")
        print("   - Number isEmpty: \(pop.displayNumber.isEmpty)")
        print("   - All listings count: \(pop.allListings.count)")
        
        // Only fetch if we have a number (required to construct URL)
        guard !pop.displayNumber.isEmpty else {
            print("⚠️ Cannot fetch details: No Pop number available")
            return
        }
        
        print("🔍 Fetching detailed info for: \(pop.displayName) #\(pop.displayNumber)")
        
        await MainActor.run {
            isLoadingDetails = true
            print("   - Set isLoadingDetails = true")
        }
        
        // Get details from product URL (without blocking on eBay calls)
        if let productURL = pop.productURL, !productURL.isEmpty {
            print("   - Fetching details from: \(productURL)")
            // Fetch basic details first (fast)
            if let details = await FunkoDatabaseService.shared.fetchPopDetails(from: productURL, displayName: pop.displayName, skipEbay: true) {
                print("✅ Successfully fetched basic details")
                await MainActor.run {
                    detailedInfo = details
                    isLoadingDetails = false
                }
                
                // Fetch eBay data in background (slow, but non-blocking)
                Task {
                    if let fullDetails = await FunkoDatabaseService.shared.fetchPopDetails(from: productURL, displayName: pop.displayName, skipEbay: false) {
                        await MainActor.run {
                            detailedInfo = fullDetails
                        }
                    }
                }
            } else {
                print("❌ Failed to fetch details")
                await MainActor.run {
                    isLoadingDetails = false
                }
            }
        } else {
            print("⚠️ No product URL available")
            await MainActor.run {
                isLoadingDetails = false
            }
        }
    }
    
    // Helper to fetch HTML from a URL
    private func fetchHTML(from urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            return html
        } catch {
            print("⚠️ Error fetching HTML: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Fetch variants from database
    private func fetchHobbyDBVariants(hdbid: String, slug: String? = nil) async {
        await MainActor.run {
            isLoadingHobbyDBVariants = true
        }
        
        // Try to get slug from product URL if not provided
        var finalSlug = slug
        if finalSlug == nil, let productURL = pop.productURL, productURL.contains("catalog_items") {
            // Try to extract slug from URL
            if let url = URL(string: productURL),
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                let pathComponents = components.path.components(separatedBy: "/")
                if let catalogIndex = pathComponents.firstIndex(of: "catalog_items"),
                   catalogIndex + 1 < pathComponents.count {
                    finalSlug = pathComponents[catalogIndex + 1]
                }
            }
        }
        
        let variants = await HobbyDBService.shared.fetchSubvariants(hdbid: hdbid, slug: finalSlug)
        
        await MainActor.run {
            hobbyDBVariants = variants
            isLoadingHobbyDBVariants = false
            
            // If we have variants and none selected, select the first one
            if selectedVariant == nil && !variants.isEmpty {
                selectedVariant = variants.first
            }
        }
    }
    
    // Update pop details based on selected variant
    private func updatePopFromVariant(_ variant: HobbyDBVariant) async {
        // The variant selection will update what's shown in the UI
        // The selected variant is stored in @State and used in the view
        print("🔄 Selected variant: \(variant.name)")
        
        
        // Refresh details if we have a product URL
        if let productURL = pop.productURL, !productURL.isEmpty {
            await fetchDetailedInfo()
        }
    }
    
    // Refetch variants with optional autographed inclusion
    private func refetchVariants(includeAutographed: Bool) async {
        await MainActor.run {
            isLoadingHobbyDBVariants = true
        }
        
        // Check if we have an hdbid from CSV database
        var hdbid = pop.allListings.first(where: { $0.result.hdbid != nil && !$0.result.hdbid!.isEmpty })?.result.hdbid
        
        // If we have hdbid from CSV, use it directly (faster and more reliable)
        if let hdbid = hdbid, !hdbid.isEmpty {
            print("🔍 PopDetailSheet: Refetching variants with hdbid: \(hdbid) (includeAutographed: \(includeAutographed))")
            let variants = await HobbyDBService.shared.fetchSubvariants(hdbid: hdbid, slug: nil, includeAutographed: includeAutographed)
            await MainActor.run {
                hobbyDBVariants = variants
                isLoadingHobbyDBVariants = false
                
                // If we have variants and none selected, select the first one
                if selectedVariant == nil && !variants.isEmpty {
                    selectedVariant = variants.first
                }
            }
        } else {
            // If no hdbid, try to extract from product page
            if let productURL = pop.productURL, !productURL.isEmpty {
                print("🔍 PopDetailSheet: No hdbid in listings, trying to extract from product page...")
                if let html = await fetchHTML(from: productURL) {
                    hdbid = HobbyDBService.shared.extractHDBIDFromHTML(html)
                    if let hdbid = hdbid, !hdbid.isEmpty {
                        print("🔍 PopDetailSheet: Found hdbid from product page: \(hdbid)")
                        let variants = await HobbyDBService.shared.fetchSubvariants(hdbid: hdbid, slug: nil, includeAutographed: includeAutographed)
                        await MainActor.run {
                            hobbyDBVariants = variants
                            isLoadingHobbyDBVariants = false
                            
                            if selectedVariant == nil && !variants.isEmpty {
                                selectedVariant = variants.first
                            }
                        }
                        return
                    }
                }
            }
            
            // Fallback: Search database directly for variants
            // Use UPC if available (most reliable), otherwise use name and number
            print("🔍 PopDetailSheet: Searching database for variants of '\(pop.displayName)' #\(pop.displayNumber)...")
            
            // Get UPC from listings if available
            let upc = pop.allListings.first?.result.upc ?? ""
            
            let variants = await HobbyDBService.shared.searchAndFetchVariants(
                name: pop.displayName,
                number: pop.displayNumber,
                upc: upc.isEmpty ? nil : upc
            )
            
            await MainActor.run {
                hobbyDBVariants = variants
                isLoadingHobbyDBVariants = false
                
                if selectedVariant == nil && !variants.isEmpty {
                    selectedVariant = variants.first
                }
            }
        }
    }
    
    // Fetch autographed variants for the sheet
    private func fetchAutographedVariantsForSheet() async {
        await MainActor.run {
            isLoadingAutographedVariants = true
        }
        
        print("🔍 PopDetailSheet: Searching for autographed variants of '\(pop.displayName)' #\(pop.displayNumber)")
        
        // Search by number and name directly (autographed variants might have different hdbids)
        // This ensures we find all variants with the same number, including autographed ones
        let variants = await FunkoDatabaseService.shared.findSubvariantsFromCSV(
            hdbid: nil,  // Don't search by hdbid - search by number/name instead
            number: pop.displayNumber,
            name: pop.displayName,
            includeAutographed: true  // Include autographed variants
        )
        
        // Filter to only autographed variants
        let autographed = variants.filter { $0.isAutographed }
        
        await MainActor.run {
            autographedVariants = autographed
            isLoadingAutographedVariants = false
        }
        
        print("✅ Found \(autographed.count) autographed variants out of \(variants.count) total variants")
        
        // Debug: Print details of found variants
        for variant in autographed {
            print("   - Autographed: \(variant.name) #\(variant.number ?? "?") (hdbid: \(variant.id))")
            if let signedBy = variant.signedBy {
                print("     Signed by: \(signedBy)")
            }
        }
    }
    
    // Fetch all sticker variants for this Pop
    private func fetchStickerVariants(currentURL: String, popNumber: String) async {
        await MainActor.run {
            isLoadingVariants = true
        }
        
        let variants = await FunkoDatabaseService.shared.fetchAllStickerVariants(for: popNumber, currentURL: currentURL)
        
        await MainActor.run {
            stickerVariants = variants
            // Set initial selection to current URL if not already set
            if selectedVariantURL == nil && !variants.isEmpty {
                selectedVariantURL = currentURL
            }
            isLoadingVariants = false
        }
    }
    
    // Load details for a specific variant URL
    private func loadVariantDetails(url: String) async {
        await MainActor.run {
            isLoadingDetails = true
        }
        
        if let details = await FunkoDatabaseService.shared.fetchPopDetails(from: url, displayName: pop.displayName) {
            await MainActor.run {
                detailedInfo = details
                isLoadingDetails = false
            }
        } else {
            await MainActor.run {
                isLoadingDetails = false
            }
        }
    }
    
    // Helper: Group listings by variant type with detailed info from CSV
    private func groupListingsByVariant(_ listings: [SearchResultWithPrice]) -> [String: [SearchResultWithPrice]] {
        var groups: [String: [SearchResultWithPrice]] = [:]
        
        for listing in listings {
            // Extract variant info from the listing
            let name = listing.result.name
            let nameLower = name.lowercased()
            
            // Extract stickers/features from name (comprehensive list)
            var stickers: [String] = []
            
            // Chase variants (check first)
            if nameLower.contains("chase") {
                stickers.append("Chase")
            }
            
            // Glow variants
            if nameLower.contains("glow") || nameLower.contains("glows in the dark") || nameLower.contains("glow in the dark") || nameLower.contains("gitd") || nameLower.contains("glowing") {
                stickers.append("Glows in the Dark")
            }
            
            // Metallic variants
            if nameLower.contains("metallic") || nameLower.contains("metal") {
                stickers.append("Metallic")
            }
            
            // Flocked variants
            if nameLower.contains("flocked") || nameLower.contains("fuzzy") {
                stickers.append("Flocked")
            }
            
            // Chrome variants
            if nameLower.contains("chrome") || nameLower.contains("chromed") {
                stickers.append("Chrome")
            }
            
            // Black Light variants
            if nameLower.contains("black light") || nameLower.contains("blacklight") || nameLower.contains("blacklight collection") {
                stickers.append("Black Light")
            }
            
            // Glitter variants
            if nameLower.contains("glitter") || nameLower.contains("glittery") {
                stickers.append("Glitter")
            }
            
            // Diamond Collection
            if nameLower.contains("diamond") {
                stickers.append("Diamond Collection")
            }
            
            // Holographic
            if nameLower.contains("holo") || nameLower.contains("holographic") {
                stickers.append("Holographic")
            }
            
            // Size variants
            if nameLower.contains("oversized") || nameLower.contains("jumbo") || nameLower.contains("super sized") || nameLower.contains("6 inch") || nameLower.contains("10 inch") || nameLower.contains("18 inch") {
                stickers.append("Oversized")
            }
            
            if nameLower.contains("mini") || nameLower.contains("pocket pop") || nameLower.contains("pocket") {
                stickers.append("Mini")
            }
            
            // Special collections
            if nameLower.contains("rides") || nameLower.contains("pop! rides") {
                stickers.append("Pop! Rides")
            }
            
            if nameLower.contains("deluxe") || nameLower.contains("pop! deluxe") {
                stickers.append("Pop! Deluxe")
            }
            
            if nameLower.contains("two pack") || nameLower.contains("2 pack") || nameLower.contains("pop! two pack") {
                stickers.append("Two Pack")
            }
            
            if nameLower.contains("three pack") || nameLower.contains("3 pack") || nameLower.contains("pop! three pack") {
                stickers.append("Three Pack")
            }
            
            if nameLower.contains("moments") || nameLower.contains("pop! moments") {
                stickers.append("Pop! Moments")
            }
            
            if nameLower.contains("keychain") || nameLower.contains("pop! keychain") {
                stickers.append("Pop! Keychain")
            }
            
            // Special editions
            if nameLower.contains("vaulted") {
                stickers.append("Vaulted")
            }
            
            if nameLower.contains("retired") {
                stickers.append("Retired")
            }
            
            if nameLower.contains("anniversary") {
                stickers.append("Anniversary Edition")
            }
            
            if nameLower.contains("movie moment") {
                stickers.append("Movie Moment")
            }
            
            // Extract exclusivity from name (check for retailer exclusives)
            var exclusivity: String = ""
            let exclusivityPatterns = [
                // Conventions (check first as they're more specific)
                ("NYCC", "NYCC Exclusive"),
                ("New York Comic Con", "NYCC Exclusive"),
                ("SDCC", "SDCC Exclusive"),
                ("San Diego Comic Con", "SDCC Exclusive"),
                ("San Diego Comic-Con", "SDCC Exclusive"),
                ("Comic-Con", "SDCC Exclusive"),
                ("ECCC", "ECCC Exclusive"),
                ("Emerald City Comic Con", "ECCC Exclusive"),
                ("C2E2", "C2E2 Exclusive"),
                ("Fan Expo", "Fan Expo Exclusive"),
                ("Convention Shared", "Convention Shared Exclusive"),
                ("Shared Exclusive", "Convention Shared Exclusive"),
                ("Convention Exclusive", "Convention Exclusive"),
                // Major Retailers
                ("Hot Topic", "Hot Topic Exclusive"),
                ("Target", "Target Exclusive"),
                ("Walmart", "Walmart Exclusive"),
                ("Amazon", "Amazon Exclusive"),
                ("GameStop", "GameStop Exclusive"),
                ("Funko Shop", "Funko Shop Exclusive"),
                ("BoxLunch", "BoxLunch Exclusive"),
                ("Entertainment Earth", "Entertainment Earth Exclusive"),
                ("Fugitive Toys", "Fugitive Toys Exclusive"),
                ("BAM!", "BAM! Exclusive"),
                ("BAM", "BAM! Exclusive"),
                ("Books A Million", "BAM! Exclusive"),
                ("Chalice Collectibles", "Chalice Collectibles Exclusive"),
                ("Chalice", "Chalice Collectibles Exclusive"),
                ("Toys R Us", "Toys R Us Exclusive"),
                ("ToysRUs", "Toys R Us Exclusive"),
                ("Toys 'R' Us", "Toys R Us Exclusive"),
                ("Walgreens", "Walgreens Exclusive"),
                ("CVS", "CVS Exclusive"),
                ("7-Eleven", "7-Eleven Exclusive"),
                ("7 Eleven", "7-Eleven Exclusive"),
                ("ThinkGeek", "ThinkGeek Exclusive"),
                ("Specialty Series", "Specialty Series Exclusive"),
                ("PX Previews", "PX Previews Exclusive"),
                ("Previews Exclusive", "PX Previews Exclusive"),
                ("Lootcrate", "Lootcrate Exclusive"),
                ("Loot Crate", "Lootcrate Exclusive"),
                ("Midtown Comics", "Midtown Comics Exclusive"),
                ("Toy Tokyo", "Toy Tokyo Exclusive"),
                ("Barnes and Noble", "Barnes & Noble Exclusive"),
                ("Barnes & Noble", "Barnes & Noble Exclusive"),
                ("DC Legion Collectors", "DC Legion Collectors Exclusive"),
                ("FYE", "FYE Exclusive"),
                ("Gemini Collectibles", "Gemini Collectibles Exclusive"),
                ("Gemini", "Gemini Collectibles Exclusive"),
                // General
                ("Limited Edition", "Limited Edition")
            ]
            
            for (pattern, exclusive) in exclusivityPatterns {
                if nameLower.contains(pattern.lowercased()) {
                    exclusivity = exclusive
                    break
                }
            }
            
            // Also check the exclusivity field from the result
            if exclusivity.isEmpty && !listing.result.exclusivity.isEmpty {
                exclusivity = listing.result.exclusivity
            }
            
            // Build unique variant key
            var variantKey = "Common"
            var variantParts: [String] = []
            
            // Add stickers first
            if !stickers.isEmpty {
                variantParts.append(contentsOf: stickers)
            }
            
            // Add exclusivity
            if !exclusivity.isEmpty {
                variantParts.append(exclusivity)
            }
            
            // Build the variant key
            if !variantParts.isEmpty {
                variantKey = variantParts.joined(separator: " • ")
            }
            
            // Create group if it doesn't exist
            if groups[variantKey] == nil {
                groups[variantKey] = []
            }
            groups[variantKey]?.append(listing)
        }
        
        return groups
    }
    
    // Extract exclusivity from sticker array - can return multiple exclusivity types
    private func extractExclusivityFromStickers(_ stickers: [String]) -> String {
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
            "toys'r'us": "Toys R Us Exclusive",  // No spaces variant
            "walgreens": "Walgreens Exclusive",
            "cvs": "CVS Exclusive",
            "7-eleven": "7-Eleven Exclusive",
            "7 eleven": "7-Eleven Exclusive",
            "thinkgeek": "ThinkGeek Exclusive",
            "specialty series": "Specialty Series Exclusive",
            "px previews": "PX Previews Exclusive",
            "previews exclusive": "PX Previews Exclusive",
            "px": "PX Previews Exclusive",  // Common abbreviation
            "previews": "PX Previews Exclusive",  // Sometimes just "Previews"
            "lootcrate": "Lootcrate Exclusive",
            "loot crate": "Lootcrate Exclusive",
            "loot": "Lootcrate Exclusive",  // Sometimes just "Loot"
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
            "comic-con": "SDCC Exclusive",
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
            "convention shared": "Convention Shared Exclusive",
            "shared exclusive": "Convention Shared Exclusive",
            "convention exclusive": "Convention Exclusive"
        ]
        
        var foundExclusivities: [String] = []
        
        // Check each sticker for retailer/convention exclusivity
        for sticker in stickers {
            let stickerLower = sticker.lowercased()
            
            // Check conventions first (more specific)
            for (keyword, exclusivity) in knownConventions {
                if stickerLower.contains(keyword) && !foundExclusivities.contains(exclusivity) {
                    foundExclusivities.append(exclusivity)
                }
            }
            
            // Then check retailers (can coexist with conventions)
            for (keyword, exclusivity) in knownRetailers {
                if stickerLower.contains(keyword) && !foundExclusivities.contains(exclusivity) {
                    foundExclusivities.append(exclusivity)
                }
            }
        }
        
        // Return combined exclusivity (e.g., "Convention Shared Exclusive • Hot Topic Exclusive")
        if foundExclusivities.count > 1 {
            return foundExclusivities.joined(separator: " • ")
        } else if foundExclusivities.count == 1 {
            return foundExclusivities[0]
        }
        
        return ""
    }
    
    // Check if we should show signed prompt when opening detail sheet
    private func checkAndShowSignedPrompt() async {
        // Check if pop name already mentions signed
        let displayName = pop.displayName
        let listingNames = pop.allListings.map { $0.result.name }
        let allNamesToCheck = [displayName] + listingNames
        let isSignedInName = allNamesToCheck.contains { isPopNameSigned($0) }
        
        print("🔍 Checking signed status on open - displayName: '\(displayName)', isSignedInName: \(isSignedInName)")
        
        // If not signed in name, show prompt
        if !isSignedInName {
            print("   ✅ Pop is not signed in name, preparing to show prompt...")
            // Create a temporary PopItem for the prompt
            let bestListing = pop.allListings.first { 
                $0.result.source.contains("Database") || 
                $0.result.source.contains("Funko.com")
            } ?? pop.allListings.first
            
            guard let listing = bestListing else {
                print("   ❌ No listing found, cannot show signed prompt")
                return
            }
            
            print("   ✅ Found listing: \(listing.result.name)")
            
            let tempPop = PopItem(
                name: pop.baseName,
                number: pop.number,
                series: pop.series,
                value: pop.averagePrice ?? 0,
                imageURL: pop.primaryImage,
                upc: listing.result.upc,
                source: listing.result.source
            )
            
            print("   ✅ Created tempPop, setting tempPopForSignedPrompt")
            await MainActor.run {
                // Set tempPopForSignedPrompt directly - using .sheet(item:) will show it automatically
                tempPopForSignedPrompt = tempPop
                print("   ✅ tempPopForSignedPrompt is now set")
            }
        } else {
            print("   ⚠️ Pop name already mentions signed, skipping prompt")
        }
    }
    
    // Helper: Check if pop name already mentions signed/autograph
    private func isPopNameSigned(_ name: String) -> Bool {
        let nameLower = name.lowercased()
        let signedKeywords = [
            "signed",
            "autograph",
            "autographed",
            "w/ jsa",
            "w/coa",
            "with coa",
            "authenticated"
        ]
        
        for keyword in signedKeywords {
            if nameLower.contains(keyword) {
                return true
            }
        }
        
        return false
    }
    
    private func addToCollection() {
        // Get best listing for data
        let bestListing = pop.allListings.first { 
            $0.result.source.contains("Database") || 
            $0.result.source.contains("Funko.com")
        } ?? pop.allListings.first
        
        guard let listing = bestListing else { return }
        
        // Check if pop already exists in collection (from toggle)
        if let existingPop = findPopInCollection() {
            // Pop already exists, just show folder picker
            pendingPop = existingPop
            showingFolderPicker = true
            Toast.show(
                message: "Pop already in collection",
                systemImage: "info.circle.fill"
            )
            return
        }
        
        let newPop = PopItem(
            name: pop.baseName,
            number: pop.number,
            series: pop.series,
            value: pop.averagePrice ?? 0,
            imageURL: pop.primaryImage,
            upc: listing.result.upc,
            source: listing.result.source
        )
        
        // Check if selected variant from hobbyDB is autographed
        if let selectedVariant = selectedVariant, selectedVariant.isAutographed {
            // Use autographed info from selected variant
            newPop.isSigned = true
            if let signedBy = selectedVariant.signedBy, !signedBy.isEmpty {
                newPop.signedBy = signedBy
            }
        } else if let tempPop = tempPopForSignedPrompt, tempPop.isSigned {
            // User marked it as signed via toggle and filled out the prompt (legacy support)
            newPop.isSigned = tempPop.isSigned
            newPop.signedBy = tempPop.signedBy
            newPop.hasCOA = tempPop.hasCOA
            newPop.signedValueMultiplier = tempPop.signedValueMultiplier
        } else {
            // Check if name explicitly mentions signed (auto-detect)
            let displayName = pop.displayName
            let listingNames = pop.allListings.map { $0.result.name }
            let allNamesToCheck = [displayName] + listingNames
            let isSignedInName = allNamesToCheck.contains { isPopNameSigned($0) }
            
            if isSignedInName {
                // Auto-detect signed from name
                newPop.isSigned = true
                
                // Try to extract signer name from "signed by [name]" pattern
                let signedName = allNamesToCheck.first { isPopNameSigned($0) && $0.lowercased().contains("signed by") } ?? displayName
                let nameLower = signedName.lowercased()
                if nameLower.contains("signed by") {
                    let components = signedName.components(separatedBy: "signed by")
                    if components.count > 1 {
                        let signerPart = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        let cleanedSigner = signerPart
                            .replacingOccurrences(of: " w/ jsa", with: "", options: .caseInsensitive)
                            .replacingOccurrences(of: " w/coa", with: "", options: .caseInsensitive)
                            .replacingOccurrences(of: " with coa", with: "", options: .caseInsensitive)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if !cleanedSigner.isEmpty {
                            newPop.signedBy = cleanedSigner
                        }
                    }
                }
            }
            // Otherwise, newPop.isSigned remains false (user didn't toggle it on)
        }
        
        context.insert(newPop)
        
        do {
            try context.save()
            pendingPop = newPop
            showingFolderPicker = true
            Toast.show(
                message: "Added \(pop.displayName) to collection",
                systemImage: "checkmark.circle.fill"
            )
        } catch {
            Toast.show(
                message: "Failed to add Pop: \(error.localizedDescription)",
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }
}

// Retailer Listing Row - Shows individual listing from a retailer
struct EbayListingRow: View {
    let listing: FunkoDatabaseService.EbayListing
    
    var body: some View {
        Button(action: {
            if let url = URL(string: listing.itemURL) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                // Thumbnail
                if !listing.imageURL.isEmpty {
                    AsyncImage(url: URL(string: listing.imageURL)) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .overlay {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                }
                
                // Details
                VStack(alignment: .leading, spacing: 4) {
                    Text("eBay")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(listing.title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if let condition = listing.condition {
                        Text(condition)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Price
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "$%.2f", listing.price))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

struct RetailerListingRow: View {
    let listing: SearchResultWithPrice
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if !listing.result.imageURL.isEmpty {
                AsyncImage(url: URL(string: listing.result.imageURL)) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.result.source)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                // Variant badges
                HStack(spacing: 4) {
                    if listing.result.features.contains(where: { $0.uppercased().contains("CHASE") }) {
                        Text("CHASE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(3)
                    }
                    if !listing.result.exclusivity.isEmpty {
                        Text(listing.result.exclusivity.uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                    }
                    if listing.result.isSigned {
                        Text("SIGNED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(3)
                    }
                }
                
                Text(listing.result.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Show Pop number if available
                if !listing.result.number.isEmpty {
                    Text("#\(listing.result.number)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .fontDesign(.monospaced)
                }
            }
            
            Spacer()
            
            // Price
            VStack(alignment: .trailing, spacing: 4) {
                if let price = listing.price, price > 0 {
                    Text(String(format: "$%.2f", price))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                } else {
                    Text("N/A")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let source = listing.priceSource {
                    Text(source)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// Grid card showing a grouped Pop
struct PopGridCard: View {
    let group: GroupedPopResult
    
    var body: some View {
        VStack(spacing: 0) {
            // Box art - prominent display
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 220)
                
                if !group.primaryResult.result.imageURL.isEmpty {
                    AsyncImage(url: URL(string: group.primaryResult.result.imageURL)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .scaleEffect(1.2)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 220)
                                .padding(10)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                }
                
                // Variant count badge (top right) - "See X Subvariants" style
                if group.variants.count > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.caption2)
                                Text("\(group.variants.count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.75))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(8)
                        }
                        Spacer()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Content area - hobbyDB style with ALL info
            VStack(alignment: .leading, spacing: 10) {
                // Pop Number - PROMINENT like hobbyDB (shown first)
                if !group.number.isEmpty {
                    Text("#\(group.number)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.bottom, 2)
                } else {
                    Text("#—")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 2)
                }
                
                // Pop name - prominent, bold
                Text(group.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Variant and Exclusivity note - subtitle under name
                if !group.primaryResult.result.features.isEmpty || !group.primaryResult.result.exclusivity.isEmpty {
                    let variantText = group.primaryResult.result.features.joined(separator: ", ")
                    let exclusivityText = group.primaryResult.result.exclusivity
                    
                    if !variantText.isEmpty && !exclusivityText.isEmpty {
                        Text("\(variantText) • \(exclusivityText)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .padding(.top, 2)
                    .padding(.bottom, 4)
                    } else if !variantText.isEmpty {
                        Text(variantText)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .padding(.top, 2)
                            .padding(.bottom, 4)
                    } else if !exclusivityText.isEmpty {
                        Text(exclusivityText)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .padding(.top, 2)
                            .padding(.bottom, 4)
                    } else {
                        Spacer()
                            .frame(height: 4)
                    }
                } else {
                    Spacer()
                        .frame(height: 4)
                }
                
                // Badges row - Exclusivity and Features (horizontal, wrapping)
                if !group.primaryResult.result.exclusivity.isEmpty || !group.primaryResult.result.features.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        // Exclusivity badge (e.g., "Funko Shop Exclusive")
                        if !group.primaryResult.result.exclusivity.isEmpty {
                            Text(group.primaryResult.result.exclusivity.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(5)
                        }
                        
                        // Features badges (wrap to multiple lines if needed)
                        if !group.primaryResult.result.features.isEmpty {
                            FlowLayout(spacing: 4) {
                                ForEach(group.primaryResult.result.features.prefix(3), id: \.self) { feature in
                                    if feature.uppercased().contains("CHASE") {
                                        Text("CHASE")
                                            .font(.system(size: 7, weight: .bold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.red.opacity(0.25))
                                            .foregroundColor(.red)
                                            .cornerRadius(4)
                                    } else {
                                        Text(feature.uppercased())
                                            .font(.system(size: 7, weight: .bold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundColor(.blue)
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical, 6)
                
                // Price display - "EV: $X" style (hobbyDB format)
                VStack(alignment: .leading, spacing: 2) {
                    if let avgPrice = group.averagePrice, avgPrice > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("EV:")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(formatPrice(avgPrice))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        Text("avg sold (30d)")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    } else if let price = group.primaryResult.price, price > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("EV:")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(formatPrice(price))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        Text("market price")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("EV:")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("—")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        Text("no data")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }
    
    // Helper to format price nicely (like hobbyDB)
    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            let kPrice = price / 1000.0
            if kPrice >= 10 {
                return String(format: "$%.0fk", kPrice)
            } else {
                return String(format: "$%.1fk", kPrice)
            }
        } else {
            return String(format: "$%.0f", price)
        }
    }
}

// FlowLayout helper for wrapping badges horizontally
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.width ?? .infinity,
            subviews: subviews,
            spacing: spacing
        )
        return result.bounds
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                    y: bounds.minY + result.frames[index].minY),
                        proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var bounds = CGSize.zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            bounds = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// Sheet showing scanned results in grid style (same as search)
struct ScannedResultsSheet: View {
    let groupedPops: [GroupedPopResult]
    let scannedCode: String
    let onSelectGroup: (GroupedPopResult) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if groupedPops.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "barcode.viewfinder",
                        description: Text("Could not find any variants for this UPC")
                    )
                } else {
                    VStack(spacing: 0) {
                        // Total count header
                        HStack {
                            Text("Found \(groupedPops.count) variant\(groupedPops.count == 1 ? "" : "s")")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        
                        // Grid layout - 2 columns like hobbyDB (same as search)
                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 16) {
                                ForEach(groupedPops) { group in
                                    PopGridCard(group: group)
                                        .onTapGesture {
                                            print("📷 Tapped on scanned Pop: \(group.name) (#\(group.number))")
                                            onSelectGroup(group)
                                        }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
            .navigationTitle("Scanned Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Sheet showing all variants/listings of a Pop (like hobbyDB)
struct PopVariantsSheet: View {
    let group: GroupedPopResult
    let onSelect: (SearchResultWithPrice) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var signedVariants: [SearchResultWithPrice] = []
    @State private var isLoadingSigned = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header with Pop info
                    VStack(alignment: .leading, spacing: 12) {
                        // Box art
                        if !group.primaryResult.result.imageURL.isEmpty {
                            AsyncImage(url: URL(string: group.primaryResult.result.imageURL)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 150, height: 150)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 150)
                                case .failure:
                                    Image(systemName: "photo")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                        .frame(height: 150)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .padding(.top, 16)
                        }
                        
                        Text(group.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        
                        if !group.number.isEmpty {
                            Text("POP #\(group.number)")
                                .font(.headline)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Average price for this Pop
                        if let avgPrice = group.averagePrice, avgPrice > 0 {
                            VStack(spacing: 4) {
                                Text(formatPrice(avgPrice))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.green)
                                Text("Average sold (last 30 days)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    
                    // Regular variants section
                    if group.variants.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            Text("No variants found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    } else {
                        // Filter out any signed variants that may have slipped through
                        let regularVariantsOnly = group.variants.filter { variant in
                            let nameLower = variant.result.name.lowercased()
                            return !nameLower.contains("signed") && !nameLower.contains("autograph")
                        }
                        
                        if regularVariantsOnly.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.orange)
                                Text("No regular variants found")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Regular Variants")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 16)
                                
                                ForEach(regularVariantsOnly) { variant in
                                    VariantRow(variant: variant)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            onSelect(variant)
                                        }
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                    }
                    
                    // Signed versions section
                    if isLoadingSigned {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Searching for signed versions...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else if !signedVariants.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Signed Versions")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                            
                            ForEach(signedVariants) { variant in
                                SignedVariantRow(variant: variant)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        onSelect(variant)
                                    }
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Variant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                // Search for signed versions of this Pop
                await searchSignedVersions()
            }
        }
    }
    
    private func searchSignedVersions() async {
        isLoadingSigned = true
        
        // Clean pop name
        var popName = group.name
        popName = popName.replacingOccurrences(of: "Pop! ", with: "", options: .caseInsensitive)
        popName = popName.replacingOccurrences(of: "Pop ", with: "", options: .caseInsensitive)
        popName = popName.trimmingCharacters(in: .whitespaces)
        
        // Search for signed versions
        let signedQueries = [
            "\(popName) signed",
            "funko pop \(popName) signed",
            "\(popName) autograph",
            "funko pop \(popName) autograph"
        ]
        
        var allSignedResults: [PopLookupResult] = []
        
        await withTaskGroup(of: [PopLookupResult].self) { taskGroup in
            for query in signedQueries {
                taskGroup.addTask {
                    await UPCLookupService.shared.searchPops(query: query)
                }
            }
            
            for await results in taskGroup {
                allSignedResults.append(contentsOf: results)
            }
        }
        
        // Filter to matching signed results
        let matchingSigned = allSignedResults.filter { signed in
            let signedLower = signed.name.lowercased()
            let popLower = popName.lowercased()
            
            // Must contain signed/autograph keyword
            guard signedLower.contains("signed") || signedLower.contains("autograph") else {
                return false
            }
            
            // Extract base name
            let baseName = signedLower
                .replacingOccurrences(of: " signed by.*", with: "", options: .regularExpression)
                .replacingOccurrences(of: " signed", with: "")
                .replacingOccurrences(of: " autograph", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            return popLower.contains(baseName) || baseName.contains(popLower)
        }
        
        // Get prices for signed variants
        var signedWithPrices: [SearchResultWithPrice] = []
        await withTaskGroup(of: SearchResultWithPrice?.self) { taskGroup in
            for signedResult in matchingSigned.prefix(5) {
                taskGroup.addTask {
                    if let priceResult = await PriceFetcher().fetchAveragePrice(for: signedResult.name, upc: nil) {
                        return SearchResultWithPrice(
                            result: signedResult,
                            price: priceResult.averagePrice,
                            priceSource: "avg sold (30d)"
                        )
                    }
                    return SearchResultWithPrice(result: signedResult)
                }
            }
            
            for await signedWithPrice in taskGroup {
                if let signed = signedWithPrice {
                    signedWithPrices.append(signed)
                }
            }
        }
        
        await MainActor.run {
            signedVariants = signedWithPrices
            isLoadingSigned = false
        }
    }
    
    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            let kPrice = price / 1000.0
            if kPrice >= 10 {
                return String(format: "$%.0fk", kPrice)
            } else {
                return String(format: "$%.1fk", kPrice)
            }
        } else {
            return String(format: "$%.0f", price)
        }
    }
}

// Row showing a signed variant
struct SignedVariantRow: View {
    let variant: SearchResultWithPrice
    
    var body: some View {
        HStack(spacing: 16) {
            OptimizedAsyncImage(url: variant.result.imageURL, width: 80, height: 80, cornerRadius: 12)
                .shadow(radius: 4)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.purple)
                    Text("SIGNED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
                
                Text(variant.result.name)
                    .font(.headline)
                    .lineLimit(2)
                
                // Extract signer name if available
                if variant.result.name.lowercased().contains("signed by") {
                    let signerPart = variant.result.name
                        .components(separatedBy: "signed by")
                        .dropFirst()
                        .joined(separator: " ")
                        .trimmingCharacters(in: .whitespaces)
                    
                    if !signerPart.isEmpty {
                        Text("by \(signerPart)")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                            .fontWeight(.medium)
                    }
                }
                
                // Price for signed version - "EV: $X" format
                if let price = variant.price, price > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("EV:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(formatPrice(price))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.purple)
                        }
                        if let source = variant.priceSource {
                            Text(source)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("EV:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("—")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1.5)
        )
        .padding(.vertical, 4)
    }
    
    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            let kPrice = price / 1000.0
            if kPrice >= 10 {
                return String(format: "$%.0fk", kPrice)
            } else {
                return String(format: "$%.1fk", kPrice)
            }
        } else {
            return String(format: "$%.0f", price)
        }
    }
}

// Row showing a single variant/listing
struct VariantRow: View {
    let variant: SearchResultWithPrice
    
    var body: some View {
        HStack(spacing: 16) {
            OptimizedAsyncImage(url: variant.result.imageURL, width: 80, height: 80, cornerRadius: 12)
                .shadow(radius: 4)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(variant.result.name)
                    .font(.headline)
                    .lineLimit(2)
                
                // Source badge
                HStack(spacing: 4) {
                    Image(systemName: variant.result.source.contains("Database") ? "checkmark.seal.fill" : "tag.fill")
                        .font(.caption2)
                        .foregroundColor(variant.result.source.contains("Database") ? .green : .blue)
                    Text(variant.result.source)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Exclusivity/Features
                if !variant.result.exclusivity.isEmpty || !variant.result.features.isEmpty {
                    HStack(spacing: 6) {
                        if !variant.result.exclusivity.isEmpty {
                            Text(variant.result.exclusivity)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                        ForEach(variant.result.features.prefix(2), id: \.self) { feature in
                            Text(feature)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                }
                
                // Price Display - "EV: $X" format (hobbyDB style)
                if let price = variant.price, price > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("EV:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(formatPrice(price))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.green)
                        }
                        if let source = variant.priceSource {
                            Text(source)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("EV:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("—")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            let kPrice = price / 1000.0
            if kPrice >= 10 {
                return String(format: "$%.0fk", kPrice)
            } else {
                return String(format: "$%.1fk", kPrice)
            }
        } else {
            return String(format: "$%.0f", price)
        }
    }
}

// List row showing individual Pop with all details: #, Name, Series, Variant/Details, Exclusive/Notes
struct PopListRow: View {
    let resultWithPrice: SearchResultWithPrice
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Pop number (left column)
            if !resultWithPrice.result.number.isEmpty {
                Text("#\(resultWithPrice.result.number)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.blue)
                    .frame(width: 50, alignment: .leading)
            } else {
                Text("-")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
            }
            
            // Main content (middle column)
            VStack(alignment: .leading, spacing: 4) {
                // Figure Name with signed indicator
                HStack(spacing: 6) {
                    Text(resultWithPrice.result.name)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Signed badge
                    if resultWithPrice.result.isSigned {
                        Text("SIGNED")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(3)
                    }
                }
                
                // Signed by info
                if resultWithPrice.result.isSigned && !resultWithPrice.result.signedBy.isEmpty {
                    Text("Signed by: \(resultWithPrice.result.signedBy)")
                        .font(.system(size: 11))
                        .foregroundColor(.purple)
                }
                
                // Line (Series)
                if !resultWithPrice.result.series.isEmpty {
                    Text(resultWithPrice.result.series)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                // Variant/Details (Features)
                if !resultWithPrice.result.features.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(resultWithPrice.result.features.prefix(3), id: \.self) { feature in
                            Text(feature)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                        if resultWithPrice.result.features.count > 3 {
                            Text("+\(resultWithPrice.result.features.count - 3)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                } else if !resultWithPrice.result.isSigned {
                    // Only show "Standard" if not signed (signed is already indicated)
                    Text("Standard")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                // Exclusive/Notes
                if !resultWithPrice.result.exclusivity.isEmpty {
                    Text(resultWithPrice.result.exclusivity)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // Price (right column)
            if let price = resultWithPrice.price, price > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatPrice(price))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.green)
                    if let source = resultWithPrice.priceSource {
                        Text(source)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            let kPrice = price / 1000.0
            if kPrice >= 10 {
                return String(format: "$%.0fk", kPrice)
            } else {
                return String(format: "$%.1fk", kPrice)
            }
        } else {
            return String(format: "$%.0f", price)
        }
    }
}

// List row showing grouped Pop (regular and/or signed variants)
struct GroupedPopListRow: View {
    let group: GroupedPopWithVariants
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Pop number (left column)
            if !group.number.isEmpty {
                Text("#\(group.number)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.blue)
                    .frame(width: 50, alignment: .leading)
            } else {
                Text("-")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
            }
            
            // Main content (middle column)
            VStack(alignment: .leading, spacing: 4) {
                // Figure Name
                Text(group.baseName)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Variant indicators
                HStack(spacing: 6) {
                    if group.hasRegular {
                        Text("REGULAR")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                    }
                    
                    if group.hasSigned {
                        Text("SIGNED")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(3)
                    }
                }
                
                // Line (Series)
                if !group.series.isEmpty {
                    Text(group.series)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                // Exclusivity badge if available
                if let regular = group.regularVariant, !regular.result.exclusivity.isEmpty {
                    Text(regular.result.exclusivity)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(3)
                }
                
                // Release date if available
                if let regular = group.regularVariant, !regular.result.releaseDate.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 8))
                        Text(regular.result.releaseDate)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Prices (right column) - show both if available
            VStack(alignment: .trailing, spacing: 4) {
                // Regular price
                if group.hasRegular, let regular = group.regularVariant, let price = regular.price, price > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Regular")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(formatPrice(price))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.blue)
                    }
                }
                
                // Signed price
                if group.hasSigned, let signed = group.signedVariant, let price = signed.price, price > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Signed")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(formatPrice(price))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.purple)
                    }
                }
                
                // If no prices, show placeholder
                if (!group.hasRegular || group.regularVariant?.price == nil) && 
                   (!group.hasSigned || group.signedVariant?.price == nil) {
                    Text("-")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            let kPrice = price / 1000.0
            if kPrice >= 10 {
                return String(format: "$%.0fk", kPrice)
            } else {
                return String(format: "$%.1fk", kPrice)
            }
        } else {
            return String(format: "$%.0f", price)
        }
    }
}

// Detail view showing both regular and signed variants with prices
struct GroupedPopDetailView: View {
    let group: GroupedPopWithVariants
    let folders: [PopFolder]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddToCollection = false
    @State private var showingSignedPrompt = false
    @State private var pendingPop: PopItem?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 20)
                    
                    // BOX ART - Large, prominent display
                    VStack(spacing: 0) {
                        if !group.primaryImage.isEmpty {
                            AsyncImage(url: URL(string: group.primaryImage)) { phase in
                                switch phase {
                                case .empty:
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 320, height: 320)
                                        .overlay {
                                            ProgressView()
                                                .scaleEffect(1.5)
                                        }
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 320, height: 320)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
                                case .failure:
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 320, height: 320)
                                        .overlay {
                                            VStack(spacing: 12) {
                                                Image(systemName: "photo")
                                                    .font(.system(size: 70))
                                                    .foregroundColor(.gray)
                                                Text("Image unavailable")
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    // Pop Name
                    Text(group.baseName)
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    
                    // Box Number (Pop Number)
                    if !group.number.isEmpty {
                        VStack(spacing: 4) {
                            Text("Box Number")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(1)
                            Text("#\(group.number)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 12)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // PRICES - Both Regular and Signed side by side
                    VStack(spacing: 16) {
                        Text("Prices")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                        
                        HStack(spacing: 12) {
                            // Regular Price
                            if group.hasRegular, let regular = group.regularVariant {
                                VStack(spacing: 8) {
                                    Text("Regular Price")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    if let price = regular.price, price > 0 {
                                        Text(String(format: "$%.2f", price))
                                            .font(.system(size: 28, weight: .bold, design: .rounded))
                                            .foregroundColor(.blue)
                                        
                                        if let source = regular.priceSource {
                                            Text(source)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    } else {
                                        Text("N/A")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            // Signed Price
                            if group.hasSigned, let signed = group.signedVariant {
                                VStack(spacing: 8) {
                                    Text("Signed Price")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    if let price = signed.price, price > 0 {
                                        Text(String(format: "$%.2f", price))
                                            .font(.system(size: 28, weight: .bold, design: .rounded))
                                            .foregroundColor(.purple)
                                        
                                        if !signed.result.signedBy.isEmpty {
                                            Text("by \(signed.result.signedBy)")
                                                .font(.caption2)
                                                .foregroundColor(.purple)
                                                .fontWeight(.semibold)
                                        }
                                        
                                        if let source = signed.priceSource {
                                            Text(source)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    } else {
                                        Text("N/A")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.top, 8)
                    
                    // DETAILED INFO SECTION - Comprehensive metadata
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Additional Information")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.bottom, 4)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Series
                            if !group.series.isEmpty {
                                HStack(spacing: 12) {
                                    Image(systemName: "square.stack.3d.up.fill")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Series")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                        Text(group.series)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    Spacer()
                                }
                            }
                            
                            // Release Date
                            if let regular = group.regularVariant, !regular.result.releaseDate.isEmpty {
                                HStack(spacing: 12) {
                                    Image(systemName: "calendar")
                                        .font(.title3)
                                        .foregroundColor(.orange)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Release Date")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                        Text(regular.result.releaseDate)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    Spacer()
                                }
                            }
                            
                            // UPC
                            if let regular = group.regularVariant, !regular.result.upc.isEmpty {
                                HStack(spacing: 12) {
                                    Image(systemName: "barcode")
                                        .font(.title3)
                                        .foregroundColor(.green)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("UPC / Barcode")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                        Text(regular.result.upc)
                                            .font(.system(size: 13, design: .monospaced))
                                            .fontWeight(.medium)
                                            .textSelection(.enabled)
                                    }
                                    Spacer()
                                }
                            }
                            
                            // Data Source
                            if let regular = group.regularVariant, !regular.result.source.isEmpty {
                                HStack(spacing: 12) {
                                    Image(systemName: regular.result.source.contains("Database") || regular.result.source.contains("Funko.com") ? "checkmark.seal.fill" : "info.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.purple)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Data Source")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                        Text(regular.result.source)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    Spacer()
                                }
                            }
                            
                            // Price Source (if different from data source)
                            if let regular = group.regularVariant, let priceSource = regular.priceSource, priceSource != regular.result.source {
                                HStack(spacing: 12) {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.green)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Price Source")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                        Text(priceSource)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal, 24)
                    
                    // Features and Exclusivity badges (from regular variant, or signed if no regular)
                    if let regular = group.regularVariant, (!regular.result.features.isEmpty || !regular.result.exclusivity.isEmpty) {
                        VStack(alignment: .leading, spacing: 12) {
                            // EXCLUSIVITY - Prominent badge
                            if !regular.result.exclusivity.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text(regular.result.exclusivity)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.orange.opacity(0.15))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.orange.opacity(0.4), lineWidth: 1.5)
                                )
                            }
                            
                            // FEATURES - Horizontal scrollable badges
                            if !regular.result.features.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(regular.result.features, id: \.self) { feature in
                                            HStack(spacing: 5) {
                                                Image(systemName: featureIcon(for: feature))
                                                    .font(.caption2)
                                                Text(feature)
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(featureColor(for: feature).opacity(0.15))
                                            )
                                            .foregroundColor(featureColor(for: feature))
                                            .overlay(
                                                Capsule()
                                                    .stroke(featureColor(for: feature).opacity(0.4), lineWidth: 1.5)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                    } else if let signed = group.signedVariant, (!signed.result.features.isEmpty || !signed.result.exclusivity.isEmpty) {
                        VStack(alignment: .leading, spacing: 12) {
                            // EXCLUSIVITY - Prominent badge
                            if !signed.result.exclusivity.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text(signed.result.exclusivity)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.orange.opacity(0.15))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.orange.opacity(0.4), lineWidth: 1.5)
                                )
                            }
                            
                            // FEATURES - Horizontal scrollable badges
                            if !signed.result.features.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(signed.result.features, id: \.self) { feature in
                                            HStack(spacing: 5) {
                                                Image(systemName: featureIcon(for: feature))
                                                    .font(.caption2)
                                                Text(feature)
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(featureColor(for: feature).opacity(0.15))
                                            )
                                            .foregroundColor(featureColor(for: feature))
                                            .overlay(
                                                Capsule()
                                                    .stroke(featureColor(for: feature).opacity(0.4), lineWidth: 1.5)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Add to Collection Buttons - one for each variant
                    VStack(spacing: 12) {
                        // Add Regular variant button
                        if group.hasRegular, let regular = group.regularVariant {
                            Button {
                                addPopFromResult(regular.result, isSigned: false, signedBy: "")
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                    Text("Add Regular to Collection")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                        
                        // Add Signed variant button
                        if group.hasSigned, let signed = group.signedVariant {
                            Button {
                                addPopFromResult(signed.result, isSigned: true, signedBy: signed.result.signedBy)
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                    Text("Add Signed to Collection")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
            }
            .navigationTitle(group.baseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addPopFromResult(_ result: PopLookupResult, isSigned: Bool, signedBy: String) {
        // Check if Pop already exists
        let descriptor = FetchDescriptor<PopItem>()
        let allPops = (try? context.fetch(descriptor)) ?? []
        let existing = allPops.first { $0.name == result.name && $0.number == result.number }
        
        if let existing = existing {
            // Duplicate - increment quantity
            existing.quantity += 1
            existing.lastUpdated = Date()
            try? context.save()
            
            Toast.show(
                message: "Added another!\nNow ×\(existing.quantity)",
                systemImage: "plus.circle.fill"
            )
            
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
            return
        }
        
        // Create new Pop
        let pop = PopItem(
            name: result.name,
            number: result.number,
            series: result.series,
            value: 0.0,
            imageURL: result.imageURL,
            upc: "",
            source: result.source
        )
        pop.isSigned = isSigned
        pop.signedBy = signedBy
        
        context.insert(pop)
        try? context.save()
        
        // Show signed prompt if applicable
        if isSigned {
            pendingPop = pop
            showingSignedPrompt = true
        } else {
            dismiss()
        }
    }
    
    // Helper: Get icon for feature
    private func featureIcon(for feature: String) -> String {
        let featureLower = feature.lowercased()
        if featureLower.contains("glow") { return "lightbulb.fill" }
        if featureLower.contains("metallic") { return "sparkles" }
        if featureLower.contains("flocked") { return "pawprint.fill" }
        if featureLower.contains("chrome") { return "circle.hexagongrid.fill" }
        if featureLower.contains("jumbo") || featureLower.contains("oversized") { return "square.stack.3d.up.fill" }
        if featureLower.contains("rides") { return "car.fill" }
        return "sparkles"
    }
    
    // Helper: Get color for feature
    private func featureColor(for feature: String) -> Color {
        let featureLower = feature.lowercased()
        if featureLower.contains("glow") { return .yellow }
        if featureLower.contains("metallic") { return .gray }
        if featureLower.contains("flocked") { return .brown }
        if featureLower.contains("chrome") { return .blue }
        if featureLower.contains("jumbo") || featureLower.contains("oversized") { return .purple }
        if featureLower.contains("rides") { return .red }
        return .blue
    }
}

// Variant Selection Sheet - Shows all variants from hobbyDB
struct HobbyDBVariantSelectionSheet: View {
    let variants: [HobbyDBVariant]
    @Binding var selectedVariant: HobbyDBVariant?
    let onSelect: (HobbyDBVariant) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(variants) { variant in
                    Button {
                        selectedVariant = variant
                        onSelect(variant)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            // Image
                            if let imageURL = variant.imageURL, let url = URL(string: imageURL) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 60, height: 60)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 60, height: 60)
                                    case .failure:
                                        Image(systemName: "photo")
                                            .frame(width: 60, height: 60)
                                            .foregroundColor(.gray)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                Image(systemName: "photo")
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                // Name
                                Text(variant.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                // Number
                                if let number = variant.number, !number.isEmpty {
                                    Text("#\(number)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Exclusivity
                                if let exclusivity = variant.exclusivity, !exclusivity.isEmpty {
                                    Text(exclusivity)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                
                                // Features
                                if !variant.features.isEmpty {
                                    HStack(spacing: 4) {
                                        ForEach(variant.features, id: \.self) { feature in
                                            Text(feature)
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                                
                                // Autographed indicator
                                if variant.isAutographed {
                                    HStack(spacing: 4) {
                                        Image(systemName: "signature")
                                            .font(.caption2)
                                        if let signedBy = variant.signedBy, !signedBy.isEmpty {
                                            Text("Signed by \(signedBy)")
                                                .font(.caption2)
                                        } else {
                                            Text("Autographed")
                                                .font(.caption2)
                                        }
                                    }
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(4)
                                }
                            }
                            
                            Spacer()
                            
                            // Selection indicator
                            if selectedVariant?.id == variant.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Select Variant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

