//
//  CollectionView.swift
//  PopCollector
//
//  Main collection view with bins, search, filters, sorting, and export
//  Supports quantity, signed pops, vaulted, price alerts, and full iCloud sync
//

import SwiftUI
import SwiftData

/// Sorting options for collection
enum SortOption: String, CaseIterable {
    case valueDescending = "Highest Value"
    case valueAscending = "Lowest Value"
    case nameAZ = "Name A–Z"
    case nameZA = "Name Z–A"
    case newest = "Newest First"
    case oldest = "Oldest First"
    case quantity = "Most Copies"
    case signed = "Signed First"
}

struct CollectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PopFolder.order) private var folders: [PopFolder]
    
    // Query for unfiled pops (no folder)
    @Query(
        filter: #Predicate<PopItem> { $0.folder == nil },
        sort: \PopItem.dateAdded,
        order: .reverse
    ) private var unfiledPops: [PopItem]
    
    // Removed scanner state - now handled by ScanTabView
    @State private var newlyScannedPop: PopItem?
    @State private var editingFolder: PopFolder?
    @State private var editingFolderName = ""
    @State private var showingNewFolder = false
    @State private var newFolderName = ""
    @State private var isRefreshing = false
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var showingSignedPrompt = false
    @State private var pendingPopForSignedPrompt: PopItem?
    @State private var priceRefreshProgress: (current: Int, total: Int)?
    @State private var isRefreshingPrices = false
    @State private var refreshTask: Task<Void, Never>?
    
    // Filter states
    @State private var filterSeries = ""
    @State private var minValue: Double = 0
    @State private var maxValue: Double = 10000
    @State private var showSignedOnly = false
    @State private var showVaultedOnly = false
    @State private var sortOption: SortOption = .valueDescending
    @State private var showingExport = false
    @State private var showingBinMenu: PopFolder?
    @State private var showingOnlineSearch = false
    @State private var onlineSearchQuery = ""
    @State private var onlineSearchResults: [PopLookupResult] = []
    @State private var isSearching = false
    
    private let priceFetcher = PriceFetcher()
    
    // Get all pops (unfiled + in folders)
    var allPops: [PopItem] {
        unfiledPops + folders.flatMap { $0.pops }
    }
    
    // Advanced filtered and sorted pops
    var filteredUnfiledPops: [PopItem] {
        var results = unfiledPops
        
        // Search filter
        if !searchText.isEmpty {
            results = results.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.series.localizedCaseInsensitiveContains(searchText) ||
                $0.upc.contains(searchText) ||
                $0.signedBy.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Series filter
        if !filterSeries.isEmpty {
            results = results.filter { $0.series.localizedCaseInsensitiveContains(filterSeries) }
        }
        
        // Signed filter
        if showSignedOnly {
            results = results.filter { $0.isSigned }
        }
        
        // Vaulted filter
        if showVaultedOnly {
            results = results.filter { $0.isVaulted }
        }
        
        // Value range filter
        results = results.filter {
            $0.displayValue >= minValue && $0.displayValue <= maxValue
        }
        
        // Sort results
        return sortedPops(from: results)
    }
    
    /// Sort pops based on selected sort option
    private func sortedPops(from pops: [PopItem]) -> [PopItem] {
        return pops.sorted { pop1, pop2 in
            switch sortOption {
            case .valueDescending:
                return pop1.displayValue > pop2.displayValue
            case .valueAscending:
                return pop1.displayValue < pop2.displayValue
            case .nameAZ:
                return pop1.name.localizedCaseInsensitiveCompare(pop2.name) == .orderedAscending
            case .nameZA:
                return pop1.name.localizedCaseInsensitiveCompare(pop2.name) == .orderedDescending
            case .newest:
                return pop1.dateAdded > pop2.dateAdded
            case .oldest:
                return pop1.dateAdded < pop2.dateAdded
            case .quantity:
                return pop1.quantity > pop2.quantity
            case .signed:
                if pop1.isSigned && !pop2.isSigned { return true }
                if !pop1.isSigned && pop2.isSigned { return false }
                return pop1.displayValue > pop2.displayValue // Secondary sort by value
            }
        }
    }
    
    var filteredFolders: [PopFolder] {
        // If no filters active, return all folders
        if searchText.isEmpty && filterSeries.isEmpty && !showSignedOnly && !showVaultedOnly && minValue == 0 && maxValue >= 10000 {
            return folders
        }
        
        // Apply filters - show folders that have matching pops
        return folders.filter { folder in
            folder.pops.contains { pop in
                var matches = true
                
                // Search filter
                if !searchText.isEmpty {
                    matches = matches && (
                        pop.name.localizedCaseInsensitiveContains(searchText) ||
                        pop.series.localizedCaseInsensitiveContains(searchText) ||
                        pop.upc.contains(searchText) ||
                        pop.signedBy.localizedCaseInsensitiveContains(searchText)
                    )
                }
                
                // Series filter
                if !filterSeries.isEmpty {
                    matches = matches && pop.series.localizedCaseInsensitiveContains(filterSeries)
                }
                
                // Signed filter
                if showSignedOnly {
                    matches = matches && pop.isSigned
                }
                
                // Vaulted filter
                if showVaultedOnly {
                    matches = matches && pop.isVaulted
                }
                
                // Value range filter
                matches = matches && (pop.displayValue >= minValue && pop.displayValue <= maxValue)
                
                return matches
            }
        }
    }
    
    // Get filtered and sorted pops for a folder
    func filteredPopsForFolder(_ folder: PopFolder) -> [PopItem] {
        var results = folder.pops
        
        // Search filter
        if !searchText.isEmpty {
            results = results.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.series.localizedCaseInsensitiveContains(searchText) ||
                $0.upc.contains(searchText) ||
                $0.signedBy.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Series filter
        if !filterSeries.isEmpty {
            results = results.filter { $0.series.localizedCaseInsensitiveContains(filterSeries) }
        }
        
        // Signed filter
        if showSignedOnly {
            results = results.filter { $0.isSigned }
        }
        
        // Vaulted filter
        if showVaultedOnly {
            results = results.filter { $0.isVaulted }
        }
        
        // Value range filter
        results = results.filter {
            $0.displayValue >= minValue && $0.displayValue <= maxValue
        }
        
        // Sort results
        return sortedPops(from: results)
    }
    
    /// Get all filtered and sorted pops for export
    var allFilteredSortedPops: [PopItem] {
        let all = unfiledPops + folders.flatMap { $0.pops }
        var filtered = all
        
        // Apply all filters
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.series.localizedCaseInsensitiveContains(searchText) ||
                $0.upc.contains(searchText) ||
                $0.signedBy.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if !filterSeries.isEmpty {
            filtered = filtered.filter { $0.series.localizedCaseInsensitiveContains(filterSeries) }
        }
        
        if showSignedOnly {
            filtered = filtered.filter { $0.isSigned }
        }
        
        if showVaultedOnly {
            filtered = filtered.filter { $0.isVaulted }
        }
        
        filtered = filtered.filter {
            $0.displayValue >= minValue && $0.displayValue <= maxValue
        }
        
        return sortedPops(from: filtered)
    }
    
    private var isEmpty: Bool {
        folders.isEmpty && unfiledPops.isEmpty
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Your collection is empty!")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Tap below to scan your first Pop")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Main list content - extracted to simplify body
    @ViewBuilder
    private var listContent: some View {
        List {
            // Unfiled Pops
            if !filteredUnfiledPops.isEmpty {
                Section("No Bin") {
                    ForEach(filteredUnfiledPops) { pop in
                        PopRowView(pop: pop, allFolders: folders, isRefreshing: isRefreshing)
                    }
                    .onMove { indices, newOffset in
                        moveUnfiledPops(indices: indices, to: newOffset)
                    }
                    .onDelete { indices in
                        deletePops(at: indices, from: nil)
                    }
                }
            }
            
            // Custom Folders with thumbnails + drag reorder
            ForEach(filteredFolders) { folder in
                Section {
                    let filteredPops = filteredPopsForFolder(folder)
                    if filteredPops.isEmpty {
                        Text("No Pops match filters")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(filteredPops) { pop in
                            PopRowView(pop: pop, allFolders: folders, isRefreshing: isRefreshing)
                        }
                        .onMove { indices, newOffset in
                            movePops(in: folder, indices: indices, to: newOffset)
                        }
                        .onDelete { indices in
                            deletePops(at: indices, from: folder)
                        }
                    }
                } header: {
                    folderHeaderView(for: folder)
                }
            }
            .onMove { indices, newOffset in
                moveFolders(indices: indices, to: newOffset)
            }
            .onDelete { indices in
                deleteFolders(at: indices)
            }
        }
        .refreshable {
            // Haptic on pull
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            
            // Shimmer animation while refreshing
            withAnimation {
                isRefreshing = true
            }
            
            await refreshAllPrices()
            
            withAnimation {
                isRefreshing = false
            }
            
            // Success haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    // Folder header view - extracted to simplify
    @ViewBuilder
    private func folderHeaderView(for folder: PopFolder) -> some View {
        HStack {
            AsyncImage(url: URL(string: folder.thumbnailURL)) { phase in
                switch phase {
                case .empty:
                    Color.gray
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Color.gray
                @unknown default:
                    Color.gray
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(folder.name)
                .font(.headline)
            
            Spacer()
            
            Button {
                shareFolder(folder)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.blue)
            }
            
            Button {
                editingFolderName = folder.name
                editingFolder = folder
            } label: {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            showingBinMenu = folder
        }
    }
    
    // Main content view - extracted to simplify body
    @ViewBuilder
    private var mainContentView: some View {
        VStack {
            if isEmpty {
                emptyStateView
            } else {
                listContent
            }
        }
    }
    
    // Leading toolbar items - extracted to simplify
    @ToolbarContentBuilder
    private var leadingToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack {
                EditButton()
                
                Menu {
                    Picker("Sort By", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
        }
    }
    
    // Trailing toolbar items - extracted to simplify
    @ToolbarContentBuilder
    private var trailingToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            trailingToolbarContent
        }
    }
    
    // Trailing toolbar content - extracted to simplify
    @ViewBuilder
    private var trailingToolbarContent: some View {
        HStack {
            // Online Search Button
            Button {
                showingOnlineSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            
            if hasActiveFilters {
                Button {
                    clearAllFilters()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            
            Button {
                showingFilters.toggle()
            } label: {
                Image(systemName: showingFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
            
            if hasPops {
                exportButton
                priceRefreshButton
            }
            
            Button {
                showingNewFolder = true
            } label: {
                Image(systemName: "folder.badge.plus")
            }
        }
    }
    
    // Helper computed properties
    private var hasActiveFilters: Bool {
        showingFilters || !filterSeries.isEmpty || showSignedOnly || showVaultedOnly || minValue > 0 || maxValue < 10000
    }
    
    private var hasPops: Bool {
        !unfiledPops.isEmpty || folders.contains(where: { !$0.pops.isEmpty })
    }
    
    private func clearAllFilters() {
        filterSeries = ""
        minValue = 0
        maxValue = 10000
        showSignedOnly = false
        showVaultedOnly = false
    }
    
    // Export button - extracted to simplify
    @ViewBuilder
    private var exportButton: some View {
        Button {
            showingExport = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .popover(isPresented: $showingExport) {
            ExportSheet(pops: allFilteredSortedPops)
        }
    }
    
    // Price refresh button - extracted to simplify
    @ViewBuilder
    private var priceRefreshButton: some View {
        if isRefreshingPrices, let progress = priceRefreshProgress {
            Button {
                refreshTask?.cancel()
                isRefreshingPrices = false
                priceRefreshProgress = nil
            } label: {
                VStack(spacing: 4) {
                    ProgressView(value: Double(progress.current), total: Double(progress.total))
                        .frame(width: 100)
                    Text("\(progress.current)/\(progress.total)")
                        .font(.caption2)
                }
            }
        } else {
            Button {
                refreshTask = Task {
                    await refreshAllPrices()
                }
            } label: {
                Label("Refresh Prices", systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshing)
        }
    }
    
    var body: some View {
        NavigationStack {
            mainContentView
                .navigationTitle("Collection")
                .searchable(text: $searchText, prompt: "Search name, actor, UPC, series...")
                .searchSuggestions {
                    if searchText.isEmpty {
                        SearchSuggestionsView(searchText: $searchText, allPops: allPops)
                    }
                }
                .toolbar {
                    leadingToolbar
                    trailingToolbar
                }
            // Signed Pop prompt
            .sheet(isPresented: $showingSignedPrompt) {
                if let pop = pendingPopForSignedPrompt {
                    SignedPopPromptSheet(pop: pop, context: modelContext)
                        .onDisappear {
                            // After signed prompt, fetch price and show folder selection
                            if let pop = pendingPopForSignedPrompt {
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
                                        newlyScannedPop = pop
                                        pendingPopForSignedPrompt = nil
                                        
                                        // Update widget data (if widget extension is set up)
                                        // WidgetDataManager.shared.updateWidgetData(context: modelContext)
                                    }
                                }
                            }
                        }
                }
            }
            // Auto-prompt after scan (folder selection)
            .sheet(item: $newlyScannedPop) { pop in
                AddToFolderSheet(pop: pop, folders: folders, context: modelContext)
            }
            // Filter sheet
            .sheet(isPresented: $showingFilters) {
                FilterSheet(
                    filterSeries: $filterSeries,
                    minValue: $minValue,
                    maxValue: $maxValue,
                    showSignedOnly: $showSignedOnly,
                    showVaultedOnly: $showVaultedOnly
                )
            }
            // Online search sheet
            .sheet(isPresented: $showingOnlineSearch) {
                OnlineSearchSheet(
                    searchQuery: $onlineSearchQuery,
                    searchResults: $onlineSearchResults,
                    isSearching: $isSearching,
                    folders: folders
                )
            }
            // Bin context menu
            .popover(item: $showingBinMenu) { folder in
                BinContextMenu(folder: folder, context: modelContext)
            }
            // Rename folder
            .alert("Rename Bin", isPresented: .constant(editingFolder != nil)) {
                TextField("New name", text: $editingFolderName)
                Button("Save") {
                    if let folder = editingFolder {
                        folder.name = editingFolderName
                        try? modelContext.save()
                    }
                    editingFolder = nil
                }
                Button("Cancel", role: .cancel) {
                    editingFolder = nil
                }
            } message: {
                Text("Enter a new name for this bin")
            }
            // New folder alert
            .alert("Name Your New Bin", isPresented: $showingNewFolder) {
                TextField("e.g. Living Room Shelf", text: $newFolderName)
                Button("Create") {
                    let trimmed = newFolderName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        let folder = PopFolder(name: trimmed)
                        folder.order = folders.count
                        modelContext.insert(folder)
                        try? modelContext.save()
                        newFolderName = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    newFolderName = ""
                }
            }
        }
    }
    
    // MARK: - Drag Helpers
    
    private func movePops(in folder: PopFolder, indices: IndexSet, to newOffset: Int) {
        var pops = folder.pops.sorted { $0.orderInFolder < $1.orderInFolder }
        pops.move(fromOffsets: indices, toOffset: newOffset)
        for (index, pop) in pops.enumerated() {
            pop.orderInFolder = index
        }
        try? modelContext.save()
    }
    
    private func moveUnfiledPops(indices: IndexSet, to newOffset: Int) {
        // No order needed for unfiled - they're sorted by date
    }
    
    private func moveFolders(indices: IndexSet, to newOffset: Int) {
        var mutableFolders = Array(folders)
        mutableFolders.move(fromOffsets: indices, toOffset: newOffset)
        for (index, folder) in mutableFolders.enumerated() {
            folder.order = index
        }
        try? modelContext.save()
    }
    
    private func deleteFolders(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(folders[index])
        }
        try? modelContext.save()
    }
    
    private func deletePops(at offsets: IndexSet, from folder: PopFolder?) {
        let popsToDelete: [PopItem]
        
        if let folder = folder {
            let filteredPops = filteredPopsForFolder(folder)
            popsToDelete = offsets.map { filteredPops[$0] }
        } else {
            popsToDelete = offsets.map { filteredUnfiledPops[$0] }
        }
        
        for pop in popsToDelete {
            modelContext.delete(pop)
        }
        
        try? modelContext.save()
        
        Toast.show(
            message: popsToDelete.count == 1 
                ? "Deleted \(popsToDelete.first?.name ?? "Pop")" 
                : "Deleted \(popsToDelete.count) Pops",
            systemImage: "trash.fill"
        )
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    // Scan functionality removed - now handled by ScanTabView
    
    // MARK: - Refresh Prices
    
    private func refreshPrices() async {
        await refreshAllPrices()
    }
    
    private func refreshAllPrices() async {
        // Refresh all pops (unfiled + in folders)
        let allPopsToRefresh = unfiledPops + folders.flatMap { $0.pops }
        let total = allPopsToRefresh.count
        
        await MainActor.run {
            isRefreshingPrices = true
            priceRefreshProgress = (0, total)
        }
        
        for (index, pop) in allPopsToRefresh.enumerated() {
            // Check if cancelled
            if Task.isCancelled {
                await MainActor.run {
                    isRefreshingPrices = false
                    priceRefreshProgress = nil
                }
                return
            }
            
            if let priceResult = await priceFetcher.fetchAveragePrice(for: pop.name, upc: pop.upc) {
                await MainActor.run {
                    pop.value = priceResult.averagePrice
                    pop.lastUpdated = priceResult.lastUpdated
                    pop.source = priceResult.source
                    pop.trend = priceResult.trend
                    priceRefreshProgress = (index + 1, total)
                }
            }
            
            // Small delay to avoid rate limits
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Check for price alerts after refreshing
        await PriceChecker.shared.checkPricesForAlerts(context: modelContext)
        
        await MainActor.run {
            isRefreshingPrices = false
            priceRefreshProgress = nil
            
            // Update widget after price refresh (if widget extension is set up)
            // WidgetDataManager.shared.updateWidgetData(context: modelContext)
            
            Toast.show(message: "Prices updated!", systemImage: "checkmark.circle.fill")
        }
    }
    
    // MARK: - Share Folder
    
    private func shareFolder(_ folder: PopFolder) {
        let total = folder.pops.reduce(0) { $0 + $1.displayValue }
        let totalCount = folder.pops.reduce(0) { $0 + $1.quantity }
        let shareText = "My \"\(folder.name)\" bin — \(totalCount) Pops — Total value: $\(String(format: "%.2f", total))"
        
        // Create share image
        let shareView = FolderShareView(folder: folder)
        let renderer = ImageRenderer(content: shareView)
        renderer.scale = 3
        
        var items: [Any] = [shareText]
        if let image = renderer.uiImage {
            items.append(image)
        }
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Auto-prompt Sheet After Scan

struct AddToFolderSheet: View {
    let pop: PopItem
    let folders: [PopFolder]
    let context: ModelContext
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Button {
                    pop.folder = nil
                    try? context.save()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "folder.badge.questionmark")
                        Text("No Bin")
                        Spacer()
                        if pop.folder == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                ForEach(folders) { folder in
                    Button {
                        pop.folder = folder
                        try? context.save()
                        dismiss()
                    } label: {
                        HStack {
                            AsyncImage(url: URL(string: folder.thumbnailURL)) { phase in
                                switch phase {
                                case .empty:
                                    Color.gray
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                case .failure:
                                    Color.gray
                                @unknown default:
                                    Color.gray
                                }
                            }
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                            
                            Text(folder.name)
                            
                            Spacer()
                            
                            if pop.folder?.id == folder.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Bin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Pop Row with Price Alert & Share

struct PopRowView: View {
    @Bindable var pop: PopItem
    var allFolders: [PopFolder]
    var isRefreshing: Bool = false
    
    @Environment(\.modelContext) private var context
    @State private var showingAlertSetup = false
    @State private var showingFolderPicker = false
    @State private var showingQuantityEditor = false
    @State private var showingQuickActions = false
    @State private var priceText = ""
    
    private var backgroundView: some View {
        Group {
            if isRefreshing {
                Color.gray.opacity(0.1)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isRefreshing)
            } else {
                Color.clear
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: pop.imageURL)) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            ProgressView()
                        }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(pop.name)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if pop.quantity > 1 {
                        Text("×\(pop.quantity)")
                            .font(.headline)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                
                if pop.value > 0 {
                    Text("$\(pop.displayValue, specifier: "%.2f") total")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(pop.isSigned ? .purple : .green)
                }
                
                // Signed badge
                if pop.isSigned {
                    HStack(spacing: 4) {
                        Image(systemName: "signature")
                            .foregroundColor(.purple)
                            .font(.caption)
                        Text(pop.signedBy.isEmpty ? "Signed by Actor" : "Signed by \(pop.signedBy)")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.purple)
                            .lineLimit(2)
                        if pop.hasCOA {
                            Text("COA")
                                .font(.caption2)
                                .bold()
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.3))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(8)
                }
                
                if !pop.source.isEmpty {
                    Text(pop.source)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if pop.trend != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: pop.trend > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text("\(abs(pop.trend), specifier: "%.1f")%")
                            .font(.caption)
                    }
                    .foregroundColor(pop.trend > 0 ? .blue : .orange)
                }
                
                if let folderName = pop.folder?.name {
                    Text("Bin: \(folderName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Quick Actions Button (long press)
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showingQuickActions = true
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            
            // Price Alert Button
            Button {
                showingAlertSetup = true
            } label: {
                Image(systemName: pop.isAlertEnabled ? "bell.fill" : "bell")
                    .foregroundColor(pop.isAlertEnabled ? .purple : .primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingAlertSetup) {
                NavigationStack {
                    PriceAlertSetupView(pop: pop)
                        .navigationTitle("Price Alert")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showingAlertSetup = false
                                }
                            }
                        }
                }
                .presentationDetents([.medium])
            }
            
            // Wishlist Button
            Button {
                pop.isInWishlist.toggle()
                do {
                    try context.save()
                    Toast.show(
                        message: pop.isInWishlist ? "Added to wishlist" : "Removed from wishlist",
                        systemImage: pop.isInWishlist ? "heart.fill" : "heart.slash"
                    )
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } catch {
                    print("❌ Failed to save wishlist change: \(error)")
                }
            } label: {
                Image(systemName: pop.isInWishlist ? "heart.fill" : "heart")
                    .foregroundColor(pop.isInWishlist ? .red : .primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            
            // Folder Picker Button
            Button {
                showingFolderPicker = true
            } label: {
                Image(systemName: pop.folder == nil ? "folder.badge.plus" : "folder")
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingFolderPicker) {
                AddToFolderSheet(pop: pop, folders: allFolders, context: context)
            }
        }
        .background(backgroundView)
        .sheet(isPresented: $showingQuickActions) {
            QuickActionMenu(pop: pop, allFolders: allFolders)
        }
        .sheet(isPresented: $showingQuantityEditor) {
            QuantityEditorView(pop: pop, context: context)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Price Alert Setup

struct PriceAlertSetupView: View {
    @Bindable var pop: PopItem
    @State private var priceText = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Notify me when price drops to")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            TextField("$50", text: $priceText)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 120)
                .onAppear {
                    if let target = pop.targetPrice {
                        priceText = String(format: "%.2f", target)
                    }
                }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Save Alert") {
                    if let price = Double(priceText), price > 0 {
                        pop.targetPrice = price
                        pop.isAlertEnabled = true
                        pop.notifiedPrice = nil
                        do {
                            try context.save()
                            PriceChecker.shared.schedule()
                            Toast.show(
                                message: "Price alert set at $\(String(format: "%.2f", price))",
                                systemImage: "bell.fill"
                            )
                            dismiss()
                        } catch {
                            print("❌ Failed to save price alert: \(error)")
                            Toast.show(message: "Failed to save alert", systemImage: "exclamationmark.triangle")
                        }
                    }
                }
                .bold()
                .foregroundColor(.blue)
            }
        }
        .padding()
        .presentationDetents([.height(200)])
    }
}

// MARK: - Folder Share View

struct FolderShareView: View {
    let folder: PopFolder
    
    var totalValue: Double {
        folder.pops.reduce(0) { $0 + $1.displayValue }
    }
    
    var totalCount: Int {
        folder.pops.reduce(0) { $0 + $1.quantity }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(folder.name)
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)
            
            Text("\(totalCount) Pops • $\(String(format: "%.2f", totalValue))")
                .font(.title2)
                .foregroundColor(.white.opacity(0.9))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                ForEach(folder.pops.prefix(20), id: \.id) { pop in
                    AsyncImage(url: URL(string: pop.imageURL)) { phase in
                        switch phase {
                        case .empty:
                            Color.gray.opacity(0.3)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            Color.gray.opacity(0.3)
                        @unknown default:
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            Text("Shared from PopCollector")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.black, Color.gray.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

#Preview {
    CollectionView()
        .modelContainer(for: [PopItem.self, PopFolder.self], inMemory: true)
}
