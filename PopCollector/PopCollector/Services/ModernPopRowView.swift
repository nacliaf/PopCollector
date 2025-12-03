//
//  ModernPopRowView.swift
//  PopCollector
//
//  Modern Pop row with Liquid Glass design, interactive elements, and premium animations
//

import SwiftUI
import SwiftData

struct ModernPopRowView: View {
    @Bindable var pop: PopItem
    var allFolders: [PopFolder]
    var isRefreshing: Bool = false
    
    @Environment(\.modelContext) private var context
    @State private var showingAlertSetup = false
    @State private var showingFolderPicker = false
    @State private var showingQuantityEditor = false
    @State private var showingQuickActions = false
    @State private var priceText = ""
    @State private var isPressed = false
    @Namespace private var namespace
    
    var body: some View {
        // Modern card-style row with Liquid Glass effect
        HStack(spacing: 16) {
            // Pop Image with modern shadow and glass effect
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
            
            // Action buttons with glass effect
            actionsView
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isPressed ? 0.1 : 0.05), radius: isPressed ? 5 : 15, x: 0, y: isPressed ? 2 : 8)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        isPressed = false
                    }
                }
        )
        .sheet(isPresented: $showingAlertSetup) {
            PriceAlertSheet(pop: pop)
        }
        .sheet(isPresented: $showingQuickActions) {
            QuickActionsSheet(pop: pop, allFolders: allFolders, context: context)
                .presentationDetents([.medium])
        }
    }
    
    // MARK: - Subviews
    
    private var popImageView: some View {
        AsyncImage(url: URL(string: pop.imageURL)) { phase in
            switch phase {
            case .empty:
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
                    .glassEffect(in: .rect(cornerRadius: 16))
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            case .failure:
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                    .glassEffect(in: .rect(cornerRadius: 16))
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: 70, height: 70)
    }
    
    private var nameAndQuantityView: some View {
        HStack(spacing: 8) {
            Text(pop.name)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .foregroundStyle(.primary)
            
            if pop.quantity > 1 {
                Text("×\(pop.quantity)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(.blue.gradient)
                    )
                    .foregroundStyle(.white)
                    .glassEffect(.regular.tint(.blue), in: .capsule)
            }
        }
    }
    
    private var valueView: some View {
        HStack(spacing: 6) {
            // Animated currency symbol
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(pop.isSigned ? .purple : .green)
                .symbolEffect(.pulse, options: .repeating, value: isRefreshing)
            
            Text("\(pop.displayValue, specifier: "%.2f") total")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(pop.isSigned ? .purple : .green)
            
            // Trend indicator with animation
            if pop.trend != 0 {
                HStack(spacing: 3) {
                    Image(systemName: pop.trend > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                    Text("\(abs(pop.trend), specifier: "%.1f")%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill((pop.trend > 0 ? Color.blue : Color.orange).opacity(0.15))
                )
                .foregroundStyle(pop.trend > 0 ? .blue : .orange)
                .glassEffect(.regular.tint(pop.trend > 0 ? .blue : .orange), in: .capsule)
            }
        }
    }
    
    private var badgesView: some View {
        HStack(spacing: 8) {
            // Signed badge with glass effect
            if pop.isSigned {
                HStack(spacing: 6) {
                    Image(systemName: "signature")
                        .font(.system(size: 12, weight: .semibold))
                    Text(pop.signedBy.isEmpty ? "Signed" : pop.signedBy)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    if pop.hasCOA {
                        Text("COA")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(.purple.gradient)
                            )
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.purple.opacity(0.1))
                )
                .foregroundStyle(.purple)
                .glassEffect(.regular.tint(.purple), in: .capsule)
            }
            
            // Vaulted badge
            if pop.isVaulted {
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Vaulted")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.orange.opacity(0.1))
                )
                .foregroundStyle(.orange)
                .glassEffect(.regular.tint(.orange), in: .capsule)
            }
        }
    }
    
    private var metadataView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !pop.source.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 10, weight: .semibold))
                    Text(pop.source)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.secondary)
            }
            
            if let folderName = pop.folder?.name {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(folderName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.secondary)
            }
        }
    }
    
    private var actionsView: some View {
        HStack(spacing: 12) {
            // Quick Actions Button with glass effect
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showingQuickActions = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            
            // Price Alert Button with glass effect
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showingAlertSetup = true
            } label: {
                Image(systemName: pop.isAlertEnabled ? "bell.fill" : "bell")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(pop.isAlertEnabled ? .white : .primary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(pop.isAlertEnabled ? .purple.gradient : .ultraThinMaterial)
                    )
                    .glassEffect(.regular.interactive().tint(pop.isAlertEnabled ? .purple : .clear), in: .circle)
                    .symbolEffect(.bounce, value: pop.isAlertEnabled)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Quick Actions Sheet

struct QuickActionsSheet: View {
    @Bindable var pop: PopItem
    var allFolders: [PopFolder]
    var context: ModelContext
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingDelete = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Edit Quantity
                    Button {
                        // Handle quantity edit
                        dismiss()
                    } label: {
                        Label("Edit Quantity", systemImage: "number")
                    }
                    
                    // Move to Folder
                    Menu {
                        ForEach(allFolders) { folder in
                            Button {
                                pop.folder = folder
                                try? context.save()
                                dismiss()
                            } label: {
                                Label(folder.name, systemImage: "folder.fill")
                            }
                        }
                    } label: {
                        Label("Move to Bin", systemImage: "folder")
                    }
                    
                    // Share
                    Button {
                        // Handle share
                        dismiss()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                
                Section {
                    // Toggle Vaulted
                    Button {
                        pop.isVaulted.toggle()
                        try? context.save()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dismiss()
                    } label: {
                        Label(
                            pop.isVaulted ? "Remove from Vault" : "Add to Vault",
                            systemImage: pop.isVaulted ? "lock.open.fill" : "lock.shield.fill"
                        )
                    }
                }
                
                Section {
                    // Delete
                    Button(role: .destructive) {
                        showingDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Quick Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.glass)
                }
            }
            .alert("Delete Pop?", isPresented: $showingDelete) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    context.delete(pop)
                    try? context.save()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete \(pop.name)?")
            }
        }
    }
}

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
    pop.folder = folder
    context.insert(pop)
    
    return ModernPopRowView(pop: pop, allFolders: [folder])
        .modelContainer(container)
        .padding()
}
