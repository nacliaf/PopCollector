//
//  SignedPopPromptSheet.swift
//  PopCollector
//
//  Prompts user if Pop is signed and by whom, with common signers list
//

import SwiftUI
import SwiftData

struct SignedPopPromptSheet: View {
    @Bindable var pop: PopItem
    let context: ModelContext
    let popDisplayName: String?
    let popNumber: String?
    @Environment(\.dismiss) private var dismiss
    
    init(pop: PopItem, context: ModelContext, popDisplayName: String? = nil, popNumber: String? = nil) {
        self.pop = pop
        self.context = context
        self.popDisplayName = popDisplayName
        self.popNumber = popNumber
    }
    
    @State private var isSigned = false
    @State private var selectedSigners: Set<String> = []
    @State private var hasCOA = false
    @State private var showingCustomInput = false
    @State private var customSignerName = ""
    @State private var allSigners: [String] = []
    @State private var isLoadingSigners = false
    
    // Most common signers (fallback list)
    private let commonSigners = [
        "Tom Holland", "Robert Downey Jr", "Chris Evans", "Chris Hemsworth",
        "Mark Ruffalo", "Scarlett Johansson", "Benedict Cumberbatch",
        "Zendaya", "Timothée Chalamet", "Pedro Pascal", "Bella Ramsey",
        "Millie Bobby Brown", "Noah Schnapp", "Finn Wolfhard", "Gaten Matarazzo",
        "David Harbour", "Winona Ryder", "Matthew Modine", "Cara Buono",
        "Paul Reiser", "Brett Gelman", "Jamie Campbell Bower", "Joseph Quinn",
        "Grace Van Dien", "Eduardo Franco", "Tom Wlaschiha", "Millie Alcock",
        "Emma D'Arcy", "Matt Smith", "Olivia Cooke", "Paddy Considine",
        "Ewan Mitchell", "Rhys Ifans", "Steve Carell", "John Krasinski",
        "Jenna Fischer", "Rainn Wilson", "B.J. Novak", "Mindy Kaling",
        "Ed Helms", "Angela Kinsey", "Oscar Nunez", "Brian Baumgartner",
        "Kate Flannery", "Phyllis Smith", "Leslie David Baker", "Creed Bratton",
        "Craig Robinson", "Ellie Kemper", "Catherine Tate", "Jenna Coleman",
        "Peter Capaldi", "Matt Lucas", "Pearl Mackie", "Jodie Whittaker",
        "Mandip Gill", "Tosin Cole", "Bradley Walsh", "John Bishop",
        "Jemma Redgrave", "Ingrid Oliver"
    ]
    
    // Computed property to get signedBy string from selected signers
    private var signedByString: String {
        selectedSigners.sorted().joined(separator: ", ")
    }
    
    // Parse signedBy string into set of signers
    private func parseSigners(_ signedBy: String) -> Set<String> {
        if signedBy.isEmpty { return [] }
        return Set(signedBy.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("This Pop is signed", isOn: $isSigned)
                        .tint(.purple)
                } header: {
                    Text("Signed Status")
                } footer: {
                    if isSigned {
                        Text("Signed Pops are valued 3-5× higher")
                            .foregroundColor(.purple)
                    }
                }
                
                if isSigned {
                    Section {
                        // Loading state
                        if isLoadingSigners {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Searching for signers...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // All found signers (from search + common)
                        if !allSigners.isEmpty {
                            Text("Found Signers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                            
                            ScrollView {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                    ForEach(allSigners, id: \.self) { signer in
                                        Button {
                                            if selectedSigners.contains(signer) {
                                                selectedSigners.remove(signer)
                                            } else {
                                                selectedSigners.insert(signer)
                                            }
                                            showingCustomInput = false
                                        } label: {
                                            HStack {
                                                Image(systemName: selectedSigners.contains(signer) ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(selectedSigners.contains(signer) ? .purple : .secondary)
                                                Text(signer)
                                                    .font(.subheadline)
                                                    .foregroundColor(.primary)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 12)
                                            .background(
                                                selectedSigners.contains(signer) ?
                                                    Color.purple.opacity(0.2) :
                                                    Color(.systemGray6)
                                            )
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 300)
                        }
                        
                        // Custom input button
                        Button {
                            showingCustomInput.toggle()
                            if showingCustomInput {
                                // When custom input is shown, fetch signers from eBay
                                Task {
                                    await fetchCustomSignersFromEbay()
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Add Custom Signer")
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.top, allSigners.isEmpty ? 0 : 8)
                        
                        if showingCustomInput {
                            VStack(spacing: 8) {
                                HStack {
                                    TextField("Enter signer name", text: $customSignerName)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Button {
                                        if !customSignerName.trimmingCharacters(in: .whitespaces).isEmpty {
                                            let trimmed = customSignerName.trimmingCharacters(in: .whitespaces)
                                            selectedSigners.insert(trimmed)
                                            if !allSigners.contains(trimmed) {
                                                allSigners.append(trimmed)
                                            }
                                            customSignerName = ""
                                            showingCustomInput = false
                                        }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.title3)
                                    }
                                    .disabled(customSignerName.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                                
                                // Show eBay signers when custom input is active
                                if isLoadingSigners {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Searching eBay for signers...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else if !allSigners.isEmpty {
                                    Text("Suggested signers from eBay:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Selected signers display
                        if !selectedSigners.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Selected Signers:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(selectedSigners).sorted(), id: \.self) { signer in
                                            HStack(spacing: 4) {
                                                Text(signer)
                                                    .font(.subheadline)
                                                Button {
                                                    selectedSigners.remove(signer)
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.purple)
                                                        .font(.caption)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.purple.opacity(0.2))
                                            .cornerRadius(16)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                    } header: {
                        Text("Who Signed It? (Select Multiple)")
                    } footer: {
                        Text("You can select multiple signers if the Pop is signed by more than one person")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Section {
                        Toggle("Has Certificate of Authenticity (COA)", isOn: $hasCOA)
                            .tint(.purple)
                    } header: {
                        Text("Authentication")
                    } footer: {
                        if hasCOA {
                            Text("COA increases value multiplier to 5×")
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
            .navigationTitle("Signed Pop?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        pop.isSigned = isSigned
                        pop.signedBy = signedByString
                        pop.hasCOA = hasCOA
                        pop.signedValueMultiplier = hasCOA ? 5.0 : 3.0
                        
                        // Increase multiplier for multiple signers
                        if selectedSigners.count > 1 {
                            pop.signedValueMultiplier = (hasCOA ? 5.0 : 3.0) * Double(selectedSigners.count) * 1.2
                        }
                        
                        try? context.save()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                    .bold()
                    .disabled(isSigned && selectedSigners.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Pre-fill if already set
            isSigned = pop.isSigned
            selectedSigners = parseSigners(pop.signedBy)
            hasCOA = pop.hasCOA
            
            // Start searching for signers
            Task {
                await fetchAllSigners()
            }
        }
    }
    
    private func fetchAllSigners() async {
        isLoadingSigners = true
        
        var foundSigners: Set<String> = []
        
        let displayName = popDisplayName ?? pop.name
        let number = popNumber ?? ""
        
        // Fetch from eBay
        let ebaySigners = await FunkoDatabaseService.shared.fetchSignersFromEbay(for: displayName, popNumber: number)
        foundSigners.formUnion(Set(ebaySigners))
        
        // Also search database as fallback
        let signedSearchQuery = "\(pop.name) signed"
        let signedResults = await UPCLookupService.shared.searchPops(query: signedSearchQuery)
        
        // Extract signers from database results
        for result in signedResults {
            // Extract signer from "signed by X" pattern
            if let signerRange = result.name.range(of: "signed by ", options: .caseInsensitive) {
                let start = signerRange.upperBound
                let signerText = String(result.name[start...])
                let signerParts = signerText.components(separatedBy: CharacterSet(charactersIn: " ,&"))
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && $0.count > 2 }
                
                // Take first 2-3 words as signer name
                if let firstPart = signerParts.first, firstPart.count > 2 {
                    let fullName = signerParts.prefix(2).joined(separator: " ")
                    if fullName.count > 2 {
                        foundSigners.insert(fullName.capitalized)
                    }
                } else if !signerParts.isEmpty {
                    // If first part is too short, try using all parts
                    let fullName = signerParts.prefix(3).joined(separator: " ")
                    if fullName.count > 2 {
                        foundSigners.insert(fullName.capitalized)
                    }
                }
                
                // Also check for multiple signers separated by "&" or "and"
                if signerText.contains("&") || signerText.contains(" and ") {
                    let parts = signerText.components(separatedBy: CharacterSet(charactersIn: "&"))
                    for part in parts {
                        let names = part.components(separatedBy: " ").prefix(2).joined(separator: " ").trimmingCharacters(in: .whitespaces)
                        if names.count > 2 {
                            foundSigners.insert(names.capitalized)
                        }
                    }
                }
            }
            
            // Extract from "by X" pattern
            if let byRange = result.name.range(of: " by ", options: .caseInsensitive) {
                let start = byRange.upperBound
                let signerText = String(result.name[start...])
                let signerParts = signerText.components(separatedBy: CharacterSet(charactersIn: " ,&"))
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && $0.count > 2 }
                
                if !signerParts.isEmpty {
                    let fullName = signerParts.prefix(2).joined(separator: " ")
                    if fullName.count > 2 {
                        foundSigners.insert(fullName.capitalized)
                    }
                }
            }
        }
        
        await MainActor.run {
            // Combine found signers with common signers
            var allSignersList = Array(foundSigners).sorted()
            
            // Add common signers that aren't already in the list
            for commonSigner in commonSigners {
                if !allSignersList.contains(where: { $0.lowercased() == commonSigner.lowercased() }) {
                    allSignersList.append(commonSigner)
                }
            }
            
            self.allSigners = allSignersList
            self.isLoadingSigners = false
            
            // Pre-select signer if pop already has one
            if !selectedSigners.isEmpty {
                // Already set from onAppear
            } else if let prefillSigner = pop.signedBy.split(separator: ",").first?.trimmingCharacters(in: .whitespaces),
                      !prefillSigner.isEmpty {
                // Try to find and select matching signer
                if let matching = allSignersList.first(where: { $0.lowercased() == prefillSigner.lowercased() }) {
                    selectedSigners.insert(matching)
                }
            }
        }
    }
    
    // Fetch signers from HobbyDB database (removed - using CSV database only)
    private func fetchSignersFromHobbyDB(popName: String, popNumber: String) async -> [String] {
        // No longer fetching from HobbyDB - using CSV database only
        return []
    }
    
    // Fetch signers from eBay when custom signer is selected
    private func fetchCustomSignersFromEbay() async {
        let displayName = popDisplayName ?? pop.name
        let number = popNumber ?? ""
        
        await MainActor.run {
            isLoadingSigners = true
        }
        
        // Fetch signers from eBay
        let ebaySigners = await FunkoDatabaseService.shared.fetchSignersFromEbay(for: displayName, popNumber: number)
        
        await MainActor.run {
            // Add eBay signers to the list if not already present
            for signer in ebaySigners {
                if !allSigners.contains(where: { $0.lowercased() == signer.lowercased() }) {
                    allSigners.append(signer)
                }
            }
            allSigners.sort()
            isLoadingSigners = false
        }
    }
}

