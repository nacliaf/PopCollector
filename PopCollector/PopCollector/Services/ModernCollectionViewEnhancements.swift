//
//  ModernCollectionViewEnhancements.swift
//  PopCollector
//
//  Modern UI enhancements for CollectionView including:
//  - Liquid Glass toolbar
//  - Modern search with glass effect
//  - Animated filter chips
//  - Premium empty states
//  - Glass effect containers
//

import SwiftUI
import SwiftData

// MARK: - Modern Toolbar Content

struct ModernCollectionToolbar: View {
    @Binding var sortOption: SortOption
    @Binding var showingFilters: Bool
    @Binding var showingOnlineSearch: Bool
    @Binding var showingNewFolder: Bool
    @Binding var showingExport: Bool
    var hasActiveFilters: Bool
    var hasPops: Bool
    var onClearFilters: () -> Void
    var onRefreshPrices: () -> Void
    var isRefreshing: Bool
    
    var body: some View {
        // Leading Toolbar Items
        ToolbarItemGroup(placement: .topBarLeading) {
            HStack(spacing: 12) {
                EditButton()
                    .buttonStyle(.glass)
                
                Menu {
                    Picker("Sort By", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Label(option.rawValue, systemImage: sortIcon(for: option))
                                .tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.glass)
            }
        }
        
        // Trailing Toolbar Items with Glass Effect
        ToolbarItemGroup(placement: .topBarTrailing) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    // Online Search
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingOnlineSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.glass)
                    .glassEffectID("search", in: namespace)
                    
                    // Clear Filters (animated)
                    if hasActiveFilters {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                onClearFilters()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.glass)
                        .glassEffectID("clear", in: namespace)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Filters
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingFilters.toggle()
                    } label: {
                        Image(systemName: showingFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .symbolEffect(.bounce, value: showingFilters)
                    }
                    .buttonStyle(.glass)
                    .glassEffectID("filter", in: namespace)
                    
                    if hasPops {
                        // Export
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showingExport = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .buttonStyle(.glass)
                        .glassEffectID("export", in: namespace)
                        
                        // Refresh Prices
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onRefreshPrices()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .symbolEffect(.rotate, value: isRefreshing)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(isRefreshing)
                        .glassEffectID("refresh", in: namespace)
                    }
                    
                    // New Folder
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showingNewFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.glassProminent)
                    .glassEffectID("newfolder", in: namespace)
                }
            }
        }
    }
    
    @Namespace private var namespace
    
    private func sortIcon(for option: SortOption) -> String {
        switch option {
        case .valueDescending, .valueAscending:
            return "dollarsign.circle"
        case .nameAZ, .nameZA:
            return "textformat.abc"
        case .newest, .oldest:
            return "calendar"
        case .quantity:
            return "number"
        case .signed:
            return "signature"
        }
    }
}

// MARK: - Modern Empty State

struct ModernEmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Animated Icon
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: 150, height: 150)
                    .glassEffect(.regular, in: .circle)
                
                Image(systemName: "books.vertical")
                    .font(.system(size: 70, weight: .thin))
                    .foregroundStyle(.blue.gradient)
                    .symbolEffect(.pulse)
            }
            
            VStack(spacing: 12) {
                Text("Your Collection Awaits")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("Start building your Funko Pop collection\nby scanning your first item")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // Call to Action with Glass Effect
            NavigationLink(destination: ScanTabView()) {
                HStack(spacing: 12) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Scan Your First Pop")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(.blue.gradient)
                )
                .foregroundStyle(.white)
                .glassEffect(.regular.interactive().tint(.blue), in: .capsule)
                .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Modern Filter Chips (Active Filters Display)

struct ActiveFiltersView: View {
    var filterSeries: String
    var showSignedOnly: Bool
    var showVaultedOnly: Bool
    var minValue: Double
    var maxValue: Double
    var onRemoveSeries: () -> Void
    var onRemoveSigned: () -> Void
    var onRemoveVaulted: () -> Void
    var onRemoveValueRange: () -> Void
    
    var hasFilters: Bool {
        !filterSeries.isEmpty || showSignedOnly || showVaultedOnly || minValue > 0 || maxValue < 10000
    }
    
    var body: some View {
        if hasFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if !filterSeries.isEmpty {
                        FilterChip(
                            title: "Series: \(filterSeries)",
                            icon: "tv",
                            color: .blue,
                            onRemove: onRemoveSeries
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    if showSignedOnly {
                        FilterChip(
                            title: "Signed",
                            icon: "signature",
                            color: .purple,
                            onRemove: onRemoveSigned
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    if showVaultedOnly {
                        FilterChip(
                            title: "Vaulted",
                            icon: "lock.shield.fill",
                            color: .orange,
                            onRemove: onRemoveVaulted
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    if minValue > 0 || maxValue < 10000 {
                        FilterChip(
                            title: "$\(Int(minValue))-$\(Int(maxValue))",
                            icon: "dollarsign.circle",
                            color: .green,
                            onRemove: onRemoveValueRange
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
        }
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
            
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    onRemove()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .foregroundStyle(color)
        .glassEffect(.regular.tint(color), in: .capsule)
    }
}

// MARK: - Modern Folder Header with Glass Effect

struct ModernFolderHeaderView: View {
    let folder: PopFolder
    let onShare: () -> Void
    let onEdit: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail with glass effect
            AsyncImage(url: URL(string: folder.thumbnailURL)) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                        .glassEffect(in: .rect(cornerRadius: 12))
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                case .failure:
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                        .glassEffect(in: .rect(cornerRadius: 12))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 50, height: 50)
            
            Text(folder.name)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            Spacer()
            
            // Action buttons with glass effect
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onShare()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.glass)
                    .glassEffectID("share-\(folder.id)", in: namespace)
                    
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.glass)
                    .glassEffectID("edit-\(folder.id)", in: namespace)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onLongPressGesture {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            onLongPress()
        }
    }
    
    @Namespace private var namespace
}

// MARK: - Modern Section Header

struct ModernSectionHeader: View {
    let title: String
    let count: Int
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.blue.gradient)
            
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            Text("\(count)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
                .glassEffect(.regular, in: .capsule)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Modern Loading State

struct ModernLoadingOverlay: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text(message)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
    }
}

#Preview("Modern Empty State") {
    ModernEmptyStateView()
}

#Preview("Active Filters") {
    ActiveFiltersView(
        filterSeries: "Solo Leveling",
        showSignedOnly: true,
        showVaultedOnly: true,
        minValue: 50,
        maxValue: 200,
        onRemoveSeries: {},
        onRemoveSigned: {},
        onRemoveVaulted: {},
        onRemoveValueRange: {}
    )
    .padding()
}

#Preview("Filter Chip") {
    FilterChip(title: "Signed", icon: "signature", color: .purple, onRemove: {})
        .padding()
}
