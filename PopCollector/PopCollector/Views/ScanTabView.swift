//
//  ScanTabView.swift
//  PopCollector
//
//  Dedicated Scan tab that shows Pop info before adding to collection
//

import SwiftUI
import SwiftData

struct ScanTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PopFolder.order) private var folders: [PopFolder]
    
    @State private var showingScanner = false
    @State private var scannedCode = ""
    @State private var scannedVariants: [PopLookupResult] = []
    @State private var scannedUniquePops: [UniquePop] = []
    @State private var showingScannedResults = false
    @State private var selectedPop: UniquePop?
    @State private var showingScannedDetail = false
    @State private var isScanning = false
    
    private let priceFetcher = PriceFetcher()
    
    var body: some View {
        NavigationStack {
            ZStack {
                if scannedUniquePops.isEmpty && !isScanning {
                    // Empty state - show scan button
                    VStack(spacing: 24) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Scan a Pop!")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Point your camera at a Pop's barcode to see its details")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button {
                            showingScanner = true
                        } label: {
                            HStack {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.title3)
                                Text("Start Scanning")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                    }
                } else if isScanning {
                    // Loading state
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Looking up Pop...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Show scanned results - Pop cards side-by-side
                    ScrollView {
                        VStack(spacing: 16) {
                            Text("Scanned Results")
                                .font(.title2)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            // Show Pop cards in a horizontal scroll or grid
                            if scannedUniquePops.count == 1 {
                                // Single Pop - show large card
                                PopCard(pop: scannedUniquePops[0])
                                    .onTapGesture {
                                        selectedPop = scannedUniquePops[0]
                                        showingScannedDetail = true
                                    }
                                    .padding(.horizontal)
                            } else {
                                // Multiple Pops - show in horizontal scroll
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(scannedUniquePops) { pop in
                                            PopCard(pop: pop)
                                                .frame(width: 180)
                                                .onTapGesture {
                                                    selectedPop = pop
                                                    showingScannedDetail = true
                                                }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            // Scan another button
                            Button {
                                scannedCode = ""
                                scannedUniquePops = []
                                showingScanner = true
                            } label: {
                                HStack {
                                    Image(systemName: "barcode.viewfinder")
                                    Text("Scan Another Pop")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingScanner) {
                ScannerView(scannedCode: $scannedCode)
                    .onChange(of: scannedCode) { oldValue, newValue in
                        if !newValue.isEmpty {
                            Task {
                                await handleScan(newValue)
                            }
                        }
                    }
            }
            .sheet(isPresented: $showingScannedDetail) {
                if let pop = selectedPop {
                    PopDetailSheet(
                        pop: pop,
                        folders: folders
                    )
                    .onDisappear {
                        selectedPop = nil
                    }
                }
            }
        }
    }
    
    private func handleScan(_ code: String) async {
        // Close scanner first
        await MainActor.run {
            showingScanner = false
            isScanning = true
        }
        
        // Check for existing Pop with same UPC
        let descriptor = FetchDescriptor<PopItem>(
            predicate: #Predicate<PopItem> { $0.upc == code }
        )
        
        if let existingPop = try? modelContext.fetch(descriptor).first {
            // DUPLICATE FOUND — show info but don't auto-add
            await MainActor.run {
                Toast.show(
                    message: "This Pop is already in your collection!\nTap to view details",
                    systemImage: "info.circle.fill"
                )
                
                // Still show the Pop info so user can see details
                isScanning = false
            }
            
            // Create a result from existing pop to show
            var result = PopLookupResult(
                name: existingPop.name,
                number: existingPop.number,
                series: existingPop.series,
                imageURL: existingPop.imageURL,
                source: "Your Collection"
            )
            result.upc = existingPop.upc
            result.isSigned = existingPop.isSigned
            result.signedBy = existingPop.signedBy
            
            // Create unique pop from existing
            var uniquePop = UniquePop(
                baseName: existingPop.name,
                number: existingPop.number,
                series: existingPop.series,
                imageURL: existingPop.imageURL
            )
            
            // Add price if available
            let resultWithPrice = SearchResultWithPrice(
                result: result,
                price: existingPop.value > 0 ? existingPop.value : nil,
                priceSource: existingPop.value > 0 ? "Your Collection" : nil
            )
            
            uniquePop.allListings.append(resultWithPrice)
            
            await MainActor.run {
                scannedUniquePops = [uniquePop]
                isScanning = false
                selectedPop = uniquePop
                showingScannedDetail = true
            }
            return
        }
        
        // Brand new Pop — show info first
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        
        // Lookup all variants
        let variants = await UPCLookupService.shared.lookupVariants(upc: code)
        
        guard !variants.isEmpty else {
            await MainActor.run {
                Toast.show(message: "No results found for this UPC", systemImage: "exclamationmark.triangle")
                scannedCode = ""
                isScanning = false
            }
            return
        }
        
        // Fetch prices for all variants in parallel
        var priceResults: [(PopLookupResult, Double?, String?)] = []
        await withTaskGroup(of: (PopLookupResult, Double?, String?)?.self) { group in
            for variant in variants {
                group.addTask {
                    if let priceResult = await priceFetcher.fetchAveragePrice(for: variant.name, upc: code) {
                        return (variant, priceResult.averagePrice, priceResult.source)
                    } else {
                        return (variant, nil, nil)
                    }
                }
            }
            
            for await priceResult in group {
                if let result = priceResult {
                    priceResults.append(result)
                }
            }
        }
        
        // Create SearchResultWithPrice instances
        let resultsWithPrices = priceResults.map { result, price, source in
            SearchResultWithPrice(result: result, price: price, priceSource: source)
        }
        
        // Deduplicate by HDBID first - each unique HDBID should appear only once
        var seenHDBIDs: Set<String> = []
        var uniqueResults: [SearchResultWithPrice] = []
        
        for resultWithPrice in resultsWithPrices {
            // If HDBID exists and is not empty, use it for deduplication
            if let hdbid = resultWithPrice.result.hdbid, !hdbid.isEmpty {
                if seenHDBIDs.contains(hdbid) {
                    // Skip duplicate HDBID
                    continue
                }
                seenHDBIDs.insert(hdbid)
            }
            // If no HDBID, include it (fallback for items without HDBID)
            uniqueResults.append(resultWithPrice)
        }
        
        // Group ALL listings by unique Pop (same as search)
        var uniquePopDict: [String: UniquePop] = [:]
        
        for resultWithPrice in uniqueResults {
            let baseName = cleanPopName(resultWithPrice.result.name)
            let key = resultWithPrice.result.number.isEmpty
                ? baseName.lowercased()
                : "#\(resultWithPrice.result.number)|\(baseName.lowercased())"
            
            if var uniquePop = uniquePopDict[key] {
                // Add this listing to the Pop's listings
                uniquePop.allListings.append(resultWithPrice)
                
                // Update series/image if better source
                if uniquePop.series.isEmpty && !resultWithPrice.result.series.isEmpty {
                    uniquePop.series = resultWithPrice.result.series
                }
                if uniquePop.imageURL.isEmpty || 
                   (!resultWithPrice.result.imageURL.isEmpty && 
                    (resultWithPrice.result.source.contains("Database") || 
                     resultWithPrice.result.source.contains("Funko.com"))) {
                    uniquePop.imageURL = resultWithPrice.result.imageURL
                }
                
                uniquePopDict[key] = uniquePop
            } else {
                // Create new unique Pop
                var newPop = UniquePop(
                    baseName: baseName,
                    number: resultWithPrice.result.number,
                    series: resultWithPrice.result.series,
                    imageURL: resultWithPrice.result.imageURL
                )
                newPop.allListings.append(resultWithPrice)
                uniquePopDict[key] = newPop
            }
        }
        
        // Convert to sorted array
        let uniquePops = Array(uniquePopDict.values).sorted { lhs, rhs in
            if !lhs.number.isEmpty && !rhs.number.isEmpty {
                if let lhsNum = Int(lhs.number), let rhsNum = Int(rhs.number) {
                    return lhsNum < rhsNum
                }
            }
            return lhs.baseName < rhs.baseName
        }
        
        await MainActor.run {
            scannedUniquePops = uniquePops
            isScanning = false
            
            Toast.show(
                message: "Found \(uniquePops.count) Pop\(uniquePops.count == 1 ? "" : "s")!\nTap to view details",
                systemImage: "checkmark.circle.fill"
            )
            
            // If only one Pop, auto-show detail
            if uniquePops.count == 1 {
                selectedPop = uniquePops.first
                showingScannedDetail = true
            }
        }
    }
    
    // Helper: Clean Pop name (remove signed/autograph keywords for grouping)
    private func cleanPopName(_ name: String) -> String {
        var cleanName = name
        let signedPatterns = [
            " signed by.*",
            " signed",
            " autograph",
            " autographed",
            "\\*signed\\*",
            "\\*SIGNED\\*",
            " w/ jsa",
            " w/coa",
            " with coa",
            " authenticated"
        ]
        
        for pattern in signedPatterns {
            cleanName = cleanName.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        return cleanName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}

#Preview {
    ScanTabView()
        .modelContainer(for: [PopItem.self, PopFolder.self], inMemory: true)
}

