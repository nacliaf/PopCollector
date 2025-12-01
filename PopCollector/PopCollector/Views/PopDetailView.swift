//
//  PopDetailView.swift
//  PopCollector
//
//  Detail view for viewing Pop information before adding to collection
//

import SwiftUI
import SwiftData

struct PopDetailView: View {
    let result: PopLookupResult
    let price: Double?
    let priceSource: String?
    let folders: [PopFolder]
    var scannedUPC: String? = nil // Optional UPC from barcode scan
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddToCollection = false
    @State private var showingSignedPrompt = false
    @State private var pendingPop: PopItem?
    @State private var signedPrice: Double?
    @State private var signedPriceSource: String?
    @State private var signerName: String?
    @State private var isLoadingSignedPrice = false
    @State private var detailedInfo: FunkoDatabaseService.PopDetailInfo?
    @State private var isLoadingDetails = false
    @State private var aiRecognizedExclusivities: [String] = []  // Exclusivity found from image analysis
    @State private var isAnalyzingImage: Bool = false
    @State private var showAutographedVariants = false
    @State private var autographedVariants: [HobbyDBVariant] = []
    @State private var isLoadingAutographedVariants = false
    
    private let priceFetcher = PriceFetcher()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Debug info in development
                    #if DEBUG
                    if result.name.isEmpty {
                        Text("⚠️ Warning: Pop name is empty")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding()
                    }
                    #endif
                    
                    Spacer(minLength: 20)
                    
                    // BOX ART - Large, prominent display (like Funko.com)
                    VStack(spacing: 0) {
                        if !result.imageURL.isEmpty {
                            AsyncImage(url: URL(string: result.imageURL)) { phase in
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
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 320, height: 320)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.system(size: 70))
                                        .foregroundColor(.gray)
                                }
                        }
                    }
                    .padding(.top, 8)
                    
                    // Pop Name - Large, bold title
                    if !result.name.isEmpty {
                        Text(result.name)
                            .font(.system(size: 28, weight: .bold))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    } else {
                        Text("Unknown Pop")
                            .font(.system(size: 28, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }
                    
                    // Box Number (Pop Number) - Prominent display like Funko.com
                    if !result.number.isEmpty {
                        VStack(spacing: 4) {
                            Text("Box Number")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(1)
                            Text("#\(result.number)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 4) {
                            Text("Box Number")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(1)
                            Text("N/A")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                    }
                    
                    // Series - Subtle display
                    if !result.series.isEmpty && result.series != "Funko Pop!" {
                        Text(result.series)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                    }
                    
                    // Badges Row - Exclusivity and Features together
                    HStack(spacing: 12) {
                        // EXCLUSIVITY - Prominent badge
                        if !result.exclusivity.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text(result.exclusivity)
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
                        if !result.features.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(result.features, id: \.self) { feature in
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
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    
                    Divider()
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Autographed Variants Toggle
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
                                    await fetchAutographedVariants()
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
                    
                    // Detailed Information
                    if isLoadingDetails {
                        HStack {
                            ProgressView()
                            Text("Loading details...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else if let details = detailedInfo {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Funko POP! Details")
                                .font(.headline)
                                .padding(.horizontal)
                            
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
                        
                        Divider()
                            .padding(.horizontal)
                    }
                    
                    // Price Information - Regular and Signed
                    HStack(spacing: 12) {
                        // Regular Price
                        VStack(spacing: 8) {
                            Text("Regular Price")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if let price = price, price > 0 {
                                Text(String(format: "$%.2f", price))
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                                
                                if let source = priceSource {
                                    Text(source)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            } else {
                                Text("N/A")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                Text("Loading...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Signed Price
                        VStack(spacing: 8) {
                            Text("Signed Price")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if isLoadingSignedPrice {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if let signedPrice = signedPrice, signedPrice > 0 {
                                Text(String(format: "$%.2f", signedPrice))
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.purple)
                                
                                if let signer = signerName {
                                    Text("by \(signer)")
                                        .font(.caption2)
                                        .foregroundColor(.purple)
                                        .fontWeight(.semibold)
                                }
                                
                                if let source = signedPriceSource {
                                    Text(source)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            } else {
                                Text("N/A")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                Text("Not available")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Product Details Section - Catalog style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Product Details")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.bottom, 4)
                        
                        // Box Number / Pop Number
                        HStack(alignment: .top) {
                            Text("Box Number")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 120, alignment: .leading)
                            Text(result.number.isEmpty ? "Not available" : "#\(result.number)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(result.number.isEmpty ? .secondary : .primary)
                        }
                        
                        // Item Number (if we had UPC or similar)
                        if !result.upc.isEmpty {
                            HStack(alignment: .top) {
                                Text("UPC")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 120, alignment: .leading)
                                Text(result.upc)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .textSelection(.enabled)
                            }
                        }
                        
                        // Category / Series
                        if !result.series.isEmpty {
                            HStack(alignment: .top) {
                                Text("Series")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 120, alignment: .leading)
                                Text(result.series)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        
                        // Exclusivity - prioritize AI recognition, then result.exclusivity
                        let displayExclusivity: String = {
                            if !aiRecognizedExclusivities.isEmpty {
                                if aiRecognizedExclusivities.count > 1 {
                                    return aiRecognizedExclusivities.joined(separator: " • ")
                                } else {
                                    return aiRecognizedExclusivities[0]
                                }
                            }
                            return result.exclusivity
                        }()
                        
                        if !displayExclusivity.isEmpty {
                            HStack(alignment: .top) {
                                Text("Exclusivity")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 120, alignment: .leading)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(displayExclusivity)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                    if !aiRecognizedExclusivities.isEmpty && aiRecognizedExclusivities.first != result.exclusivity {
                                        HStack(spacing: 4) {
                                            Image(systemName: "sparkles")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                            Text("AI Detected")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Features
                        if !result.features.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Features")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(result.features.joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        // Release Date
                        if !result.releaseDate.isEmpty {
                            HStack(alignment: .top) {
                                Text("Release Date")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 120, alignment: .leading)
                                Text(result.releaseDate)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    
                    // Source Badge
                    HStack(spacing: 8) {
                        Image(systemName: result.source.contains("Database") || result.source.contains("Funko.com") ? "checkmark.seal.fill" : "tag.fill")
                            .foregroundColor(result.source.contains("Database") || result.source.contains("Funko.com") ? .green : .blue)
                        Text(result.source)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Add to Collection Button
                    Button {
                        addToCollection()
                    } label: {
                        Label("Add to Collection", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Pop Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                // Fetch signed price when view appears
                await fetchSignedPrice()
                // Analyze image for exclusivity stickers using AI
                await analyzeImageForExclusivity()
                // Fetch detailed information
                await fetchDetailedInfo()
            }
            .sheet(isPresented: $showingSignedPrompt) {
                if let pop = pendingPop {
                    SignedPopPromptSheet(pop: pop, context: context)
                        .onDisappear {
                            // After signed prompt, proceed to folder selection
                            if let pop = pendingPop {
                                // If signed price was found and pop is signed, use signed price
                                if pop.isSigned {
                                    if let signedPrice = signedPrice, signedPrice > 0 {
                                        Task {
                                            await MainActor.run {
                                                // Update value to signed price if available
                                                pop.value = signedPrice
                                                pop.source = signedPriceSource ?? pop.source
                                                pop.lastUpdated = Date()
                                                
                                                // Ensure signer is set if we found one
                                                if let signer = signerName, !signer.isEmpty && pop.signedBy.isEmpty {
                                                    pop.signedBy = signer
                                                }
                                                
                                                try? context.save()
                                            }
                                        }
                                    } else if let regularPrice = price, regularPrice > 0 {
                                        // If no signed price found but have regular price, use multiplier
                                        Task {
                                            await MainActor.run {
                                                pop.value = regularPrice * pop.signedValueMultiplier
                                                pop.lastUpdated = Date()
                                                try? context.save()
                                            }
                                        }
                                    }
                                }
                                
                                // Show folder selection after a brief delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showingAddToCollection = true
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingAddToCollection) {
                if let pop = pendingPop {
                    AddToFolderSheet(pop: pop, folders: folders, context: context)
                }
            }
        }
    }
    
    // Helper: Get icon for feature
    private func featureIcon(for feature: String) -> String {
        let featureLower = feature.lowercased()
        if featureLower.contains("glow") { return "sparkles" }
        if featureLower.contains("metallic") { return "star.fill" }
        if featureLower.contains("flocked") { return "hand.tap.fill" }
        if featureLower.contains("chrome") { return "diamond.fill" }
        if featureLower.contains("jumbo") || featureLower.contains("oversized") { return "square.and.arrow.up.fill" }
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
    
    private func fetchSignedPrice() async {
        // Search for signed versions of this pop
        isLoadingSignedPrice = true
        
        // Clean the pop name - remove "Pop!" prefix for better search
        var popName = result.name
        popName = popName.replacingOccurrences(of: "Pop! ", with: "", options: .caseInsensitive)
        popName = popName.replacingOccurrences(of: "Pop ", with: "", options: .caseInsensitive)
        popName = popName.trimmingCharacters(in: .whitespaces)
        
        // Try multiple signed search queries
        let signedQueries = [
            "\(popName) signed",
            "funko pop \(popName) signed",
            "\(popName) autograph",
            "funko pop \(popName) autograph"
        ]
        
        var allSignedResults: [PopLookupResult] = []
        
        // Search with all queries in parallel
        await withTaskGroup(of: [PopLookupResult].self) { group in
            for query in signedQueries {
                group.addTask {
                    await UPCLookupService.shared.searchPops(query: query)
                }
            }
            
            for await results in group {
                allSignedResults.append(contentsOf: results)
            }
        }
        
        // Find signed results that match this pop
        let matchingSigned = allSignedResults.filter { signed in
            let signedLower = signed.name.lowercased()
            let popLower = popName.lowercased()
            
            // Must contain signed/autograph keyword
            guard signedLower.contains("signed") || signedLower.contains("autograph") else {
                return false
            }
            
            // Extract base name from signed result (remove signed part)
            let baseName = signedLower
                .replacingOccurrences(of: " signed by.*", with: "", options: .regularExpression)
                .replacingOccurrences(of: " signed", with: "")
                .replacingOccurrences(of: " autograph", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            // Check if names match (allowing for some variation)
            return popLower.contains(baseName) || 
                   baseName.contains(popLower) ||
                   signedLower.contains(popLower) ||
                   popLower.contains(signedLower.components(separatedBy: "signed").first?.trimmingCharacters(in: .whitespaces) ?? "")
        }
        
        // If we found matching signed results, try to get prices from them
        if !matchingSigned.isEmpty {
            // Try to fetch prices from all matching signed results
            var signedPrices: [Double] = []
            var signedSources: [String] = []
            
            await withTaskGroup(of: (Double?, String?).self) { group in
                for signedResult in matchingSigned.prefix(5) { // Limit to 5 to avoid too many requests
                    group.addTask {
                        // Extract signer name for later use
                        if let signerRange = signedResult.name.range(of: "signed by ", options: .caseInsensitive) {
                            let start = signerRange.upperBound
                            let signerText = String(signedResult.name[start...])
                            let signerParts = signerText.components(separatedBy: CharacterSet(charactersIn: " ,-")).prefix(3)
                            let signer = signerParts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                            if !signer.isEmpty {
                                await MainActor.run {
                                    if signerName == nil || signerName!.isEmpty {
                                        signerName = signer
                                    }
                                }
                            }
                        }
                        
                        // Fetch price
                        if let priceResult = await priceFetcher.fetchAveragePrice(for: signedResult.name, upc: nil),
                           priceResult.averagePrice > 0 {
                            return (priceResult.averagePrice, priceResult.source)
                        }
                        return (nil, nil)
                    }
                }
                
                for await (price, source) in group {
                    if let price = price, let source = source, price > 0 {
                        signedPrices.append(price)
                        signedSources.append(source)
                    }
                }
            }
            
            // If we got actual signed prices, use the average
            if !signedPrices.isEmpty {
                let avgSignedPrice = signedPrices.reduce(0, +) / Double(signedPrices.count)
                await MainActor.run {
                    signedPrice = avgSignedPrice
                    signedPriceSource = "Marketplace average"
                    if let firstSigner = matchingSigned.first?.name, 
                       let signerRange = firstSigner.range(of: "signed by ", options: .caseInsensitive) {
                        let start = signerRange.upperBound
                        let signerText = String(firstSigner[start...])
                        let signerParts = signerText.components(separatedBy: CharacterSet(charactersIn: " ,-")).prefix(3)
                        signerName = signerParts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    }
                    isLoadingSignedPrice = false
                }
                return
            }
        }
        
        // No signed version found or no prices available - only show estimate if regular price exists
        await MainActor.run {
            if let regularPrice = price, regularPrice > 0 {
                // Only show estimate if we actually searched and found no signed listings
                signedPrice = regularPrice * 3.0
                signedPriceSource = "Estimate (no signed listings found)"
                signerName = nil
            } else {
                signedPrice = nil
                signedPriceSource = nil
                signerName = nil
            }
            isLoadingSignedPrice = false
        }
    }
    
    private func addToCollection() {
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
            value: price ?? 0.0,
            imageURL: result.imageURL,
            upc: scannedUPC ?? "", // Use scanned UPC if available
            source: result.source
        )
        
        context.insert(pop)
        try? context.save()
        
        // Fetch price if not already available
        if pop.value == 0 {
            Task {
                if let priceResult = await priceFetcher.fetchAveragePrice(for: pop.name, upc: pop.upc) {
                    await MainActor.run {
                        pop.value = priceResult.averagePrice
                        pop.lastUpdated = priceResult.lastUpdated
                        pop.source = priceResult.source
                        pop.trend = priceResult.trend
                        try? context.save()
                    }
                }
                
                // Pre-fill signer name if we found one (but don't set isSigned yet - let user decide)
                if let signer = signerName, !signer.isEmpty {
                    pop.signedBy = signer
                }
                
                // Show signed prompt to let user decide if it's signed
                await MainActor.run {
                    pendingPop = pop
                    showingSignedPrompt = true
                }
            }
        } else {
            // Price already available - pre-fill signer name if found (but don't set isSigned yet)
            if let signer = signerName, !signer.isEmpty {
                pop.signedBy = signer
            }
            
            // Show signed prompt to let user decide if it's signed
            pendingPop = pop
            showingSignedPrompt = true
        }
    }
    
    // MARK: - AI Image Analysis
    
    /// Analyzes the Pop box image for exclusivity stickers using AI
    private func analyzeImageForExclusivity() async {
        guard !result.imageURL.isEmpty, let imageURL = URL(string: result.imageURL) else {
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
                        popName: result.name,
                        popNumber: result.number,
                        correctedExclusivity: firstExclusivity
                    )
                }
            }
        }
    }
    
    private func fetchDetailedInfo() async {
        // Only fetch if we have a number (required to construct URL)
        guard !result.number.isEmpty else {
            print("⚠️ Cannot fetch details: No Pop number available")
            return
        }
        
        print("🔍 Fetching detailed info for: \(result.name) #\(result.number)")
        
        await MainActor.run {
            isLoadingDetails = true
        }
        
        // Fetch details from product URL
        if let productURL = result.productURL, !productURL.isEmpty {
            print("🔍 Fetching details from: \(productURL)")
            if let details = await FunkoDatabaseService.shared.fetchPopDetails(from: productURL, displayName: result.name) {
                print("✅ Successfully fetched details")
                await MainActor.run {
                    detailedInfo = details
                    isLoadingDetails = false
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
    
    private func fetchAutographedVariants() async {
        guard !result.number.isEmpty else { return }
        
        await MainActor.run {
            isLoadingAutographedVariants = true
        }
        
        print("🔍 PopDetailView: Searching for autographed variants of '\(result.name)' #\(result.number)")
        
        // Search by number and name directly (autographed variants might have different hdbids)
        // This ensures we find all variants with the same number, including autographed ones
        let variants = await FunkoDatabaseService.shared.findSubvariantsFromCSV(
            hdbid: nil,  // Don't search by hdbid - search by number/name instead
            number: result.number,
            name: result.name,
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
}

// Autographed Variant Card Component
struct AutographedVariantCard: View {
    let variant: HobbyDBVariant
    
    var body: some View {
        HStack(spacing: 12) {
            // Image
            if let imageURL = variant.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
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
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    }
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(variant.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if let signedBy = variant.signedBy, !signedBy.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "signature")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("Signed by \(signedBy)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "signature")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("Autographed")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                if let exclusivity = variant.exclusivity, !exclusivity.isEmpty {
                    Text(exclusivity)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

// Detail Row component for displaying key-value pairs
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

