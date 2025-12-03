//
//  EnhancedPopRowView.swift
//  PopCollector
//
//  Ultra-modern Pop row with premium design and smooth animations
//  Better than any other collection app!
//

import SwiftUI
import SwiftData

struct EnhancedPopRowView: View {
    @Bindable var pop: PopItem
    var allFolders: [PopFolder]
    var isRefreshing: Bool = false
    
    @Environment(\.modelContext) private var context
    @State private var showingAlertSetup = false
    @State private var showingFolderPicker = false
    @State private var showingQuickActions = false
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Pop Image with modern design
            popImageView
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Name and Quantity
                nameAndQuantityView
                
                // Value with trend indicator
                if pop.value > 0 {
                    valueView
                }
                
                // Badges (Signed, Vaulted, etc.)
                badgesView
                
                // Source and folder info
                metadataView
            }
            
            Spacer()
            
            // Action buttons
            actionsView
        }
        .padding(16)
        .modernCard(isPressed: isPressed, backgroundColor: pop.isSigned ? .purple : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            // Navigate to detail view or show quick actions
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    isPressed = false
                }
                showingQuickActions = true
            }
        }
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
                            .buttonStyle(.modernGlassProminent)
                        }
                    }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingQuickActions) {
            EnhancedQuickActionsSheet(pop: pop, allFolders: allFolders, context: context)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingFolderPicker) {
            AddToFolderSheet(pop: pop, folders: allFolders, context: context)
        }
    }
    
    // MARK: - Subviews
    
    private var popImageView: some View {
        AsyncImage(url: URL(string: pop.imageURL)) { phase in
            switch phase {
            case .empty:
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        ProgressView()
                            .tint(.blue)
                    )
                    .frame(width: 75, height: 75)
                    .shimmer()
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 75, height: 75)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            case .failure:
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                    )
                    .frame(width: 75, height: 75)
            @unknown default:
                EmptyView()
            }
        }
    }
    
    private var nameAndQuantityView: some View {
        HStack(spacing: 10) {
            Text(pop.name)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .foregroundStyle(.primary)
            
            if pop.quantity > 1 {
                Text("×\(pop.quantity)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.blue.gradient)
                            .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
            }
        }
    }
    
    private var valueView: some View {
        HStack(spacing: 8) {
            // Animated currency symbol
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(pop.isSigned ? .purple.gradient : .green.gradient)
                .symbolEffect(.pulse, options: .repeating.speed(0.5), value: isRefreshing)
            
            Text("\(pop.displayValue, specifier: "%.2f")")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(pop.isSigned ? .purple : .green)
            
            Text("total")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            
            // Trend indicator with animation
            if pop.trend != 0 {
                HStack(spacing: 4) {
                    Image(systemName: pop.trend > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(abs(pop.trend), specifier: "%.1f")%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill((pop.trend > 0 ? Color.blue : Color.orange).opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(pop.trend > 0 ? .blue.opacity(0.3) : .orange.opacity(0.3), lineWidth: 1)
                        )
                )
                .foregroundStyle(pop.trend > 0 ? .blue : .orange)
            }
        }
    }
    
    private var badgesView: some View {
        HStack(spacing: 8) {
            // Signed badge
            if pop.isSigned {
                ModernBadge(
                    title: pop.signedBy.isEmpty ? "Signed" : pop.signedBy,
                    icon: "signature",
                    color: .purple
                )
                
                if pop.hasCOA {
                    ModernBadge(
                        title: "COA",
                        icon: "checkmark.seal.fill",
                        color: .purple
                    )
                }
            }
            
            // Vaulted badge
            if pop.isVaulted {
                ModernBadge(
                    title: "Vaulted",
                    icon: "lock.shield.fill",
                    color: .orange
                )
            }
            
            // Wishlist badge
            if pop.isInWishlist {
                ModernBadge(
                    title: "Wishlist",
                    icon: "heart.fill",
                    color: .red
                )
            }
        }
    }
    
    private var metadataView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !pop.source.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11, weight: .semibold))
                    Text(pop.source)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.secondary)
            }
            
            if let folderName = pop.folder?.name {
                HStack(spacing: 5) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(folderName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.blue)
            }
        }
    }
    
    private var actionsView: some View {
        VStack(spacing: 12) {
            // Price Alert Button
            ModernIconButton(
                icon: pop.isAlertEnabled ? "bell.fill" : "bell",
                color: .purple,
                isActive: pop.isAlertEnabled
            ) {
                showingAlertSetup = true
            }
            
            // Wishlist Button
            ModernIconButton(
                icon: pop.isInWishlist ? "heart.fill" : "heart",
                color: .red,
                isActive: pop.isInWishlist
            ) {
                toggleWishlist()
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleWishlist() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            pop.isInWishlist.toggle()
        }
        
        do {
            try context.save()
            Toast.show(
                message: pop.isInWishlist ? "Added to wishlist" : "Removed from wishlist",
                systemImage: pop.isInWishlist ? "heart.fill" : "heart.slash"
            )
        } catch {
            print("❌ Failed to save wishlist change: \(error)")
            Toast.show(message: "Failed to save", systemImage: "exclamationmark.triangle")
        }
    }
}

// MARK: - Enhanced Quick Actions Sheet

struct EnhancedQuickActionsSheet: View {
    @Bindable var pop: PopItem
    var allFolders: [PopFolder]
    var context: ModelContext
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingDelete = false
    @State private var showingQuantityEditor = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Pop Preview Card
                    popPreviewCard
                    
                    // Quick Actions Grid
                    quickActionsGrid
                    
                    // Move to Folder Section
                    folderSection
                    
                    // Danger Zone
                    dangerSection
                }
                .padding()
            }
            .navigationTitle("Quick Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.modernGlassProminent)
                }
            }
        }
    }
    
    private var popPreviewCard: some View {
        HStack(spacing: 16) {
            AsyncImage(url: URL(string: pop.imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                default:
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 80, height: 80)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(pop.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .lineLimit(2)
                
                if pop.value > 0 {
                    Text("$\(pop.displayValue, specifier: "%.2f")")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.green)
                }
                
                Text(pop.series)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding()
        .modernCard()
    }
    
    private var quickActionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            QuickActionButton(
                title: "Edit Quantity",
                icon: "number",
                color: .blue
            ) {
                showingQuantityEditor = true
            }
            
            QuickActionButton(
                title: pop.isVaulted ? "Unvault" : "Add to Vault",
                icon: pop.isVaulted ? "lock.open.fill" : "lock.shield.fill",
                color: .orange
            ) {
                toggleVaulted()
            }
            
            QuickActionButton(
                title: "Share",
                icon: "square.and.arrow.up",
                color: .green
            ) {
                sharePopulation)
            }
            
            QuickActionButton(
                title: "View Details",
                icon: "info.circle",
                color: .purple
            ) {
                // Navigate to detail view
                dismiss()
            }
        }
    }
    
    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Move to Bin")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .padding(.horizontal, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // No Bin option
                    FolderChip(
                        name: "No Bin",
                        thumbnailURL: nil,
                        isSelected: pop.folder == nil
                    ) {
                        moveToFolder(nil)
                    }
                    
                    // Folders
                    ForEach(allFolders) { folder in
                        FolderChip(
                            name: folder.name,
                            thumbnailURL: folder.thumbnailURL,
                            isSelected: pop.folder?.id == folder.id
                        ) {
                            moveToFolder(folder)
                        }
                    }
                }
            }
        }
    }
    
    private var dangerSection: some View {
        VStack(spacing: 12) {
            Button(role: .destructive) {
                showingDelete = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Delete Pop")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.red.opacity(0.3), lineWidth: 1)
                        )
                )
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .alert("Delete Pop?", isPresented: $showingDelete) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePop()
            }
        } message: {
            Text("Are you sure you want to delete \(pop.name)? This action cannot be undone.")
        }
    }
    
    // MARK: - Actions
    
    private func toggleVaulted() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            pop.isVaulted.toggle()
        }
        try? context.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        Toast.show(
            message: pop.isVaulted ? "Added to vault" : "Removed from vault",
            systemImage: pop.isVaulted ? "lock.shield.fill" : "lock.open.fill"
        )
    }
    
    private func moveTo Folder(_ folder: PopFolder?) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            pop.folder = folder
        }
        try? context.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        Toast.show(
            message: folder == nil ? "Moved to No Bin" : "Moved to \(folder!.name)",
            systemImage: "folder.fill"
        )
    }
    
    private func sharePop() {
        // Implement share functionality
        dismiss()
        Toast.show(message: "Share functionality coming soon!", systemImage: "square.and.arrow.up")
    }
    
    private func deletePop() {
        context.delete(pop)
        try? context.save()
        dismiss()
        
        Toast.show(
            message: "Deleted \(pop.name)",
            systemImage: "trash.fill"
        )
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(color.gradient)
                
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(color.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Folder Chip

struct FolderChip: View {
    let name: String
    let thumbnailURL: String?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 10) {
                if let thumbnailURL = thumbnailURL {
                    AsyncImage(url: URL(string: thumbnailURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        default:
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .frame(width: 40, height: 40)
                        }
                    }
                } else {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.blue.opacity(0.1))
                        )
                }
                
                Text(name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? .blue.gradient : .ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? .clear : .blue.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: isSelected ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PopItem.self, PopFolder.self, configurations: config)
    let context = container.mainContext
    
    let folder = PopFolder(name: "Living Room")
    context.insert(folder)
    
    let pop = PopItem(
        name: "Sung Jinwoo (Monarch of Shadows)",
        upc: "123456789",
        value: 125.50,
        lastUpdated: Date(),
        imageURL: "https://example.com/image.jpg",
        source: "eBay",
        number: "1234",
        series: "Solo Leveling",
        trend: 15.3
    )
    pop.quantity = 2
    pop.isSigned = true
    pop.signedBy = "Taito Ban"
    pop.hasCOA = true
    pop.isVaulted = true
    pop.folder = folder
    context.insert(pop)
    
    return ScrollView {
        VStack(spacing: 16) {
            EnhancedPopRowView(pop: pop, allFolders: [folder])
            EnhancedPopRowView(pop: pop, allFolders: [folder], isRefreshing: true)
        }
        .padding()
    }
    .modelContainer(container)
}
