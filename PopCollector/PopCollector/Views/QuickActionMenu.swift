//
//  QuickActionMenu.swift
//  PopCollector
//
//  Quick action menu for Pops (long-press context menu)
//

import SwiftUI
import SwiftData

struct QuickActionMenu: View {
    @Bindable var pop: PopItem
    let allFolders: [PopFolder]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingQuantityEditor = false
    @State private var showingAlertSetup = false
    @State private var showingFolderPicker = false
    @State private var showingDeleteConfirm = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                OptimizedAsyncImage(url: pop.imageURL, width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pop.name)
                        .font(.headline)
                        .lineLimit(2)
                    Text("$\(pop.displayValue, specifier: "%.2f")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            
            Divider()
            
            // Actions
            VStack(spacing: 0) {
                QuickActionButton(
                    icon: "slider.horizontal.3",
                    title: "Edit Quantity",
                    color: .blue
                ) {
                    showingQuantityEditor = true
                }
                
                QuickActionButton(
                    icon: pop.isAlertEnabled ? "bell.fill" : "bell",
                    title: "Price Alert",
                    color: .purple
                ) {
                    showingAlertSetup = true
                }
                
                QuickActionButton(
                    icon: "folder",
                    title: "Move to Bin",
                    color: .orange
                ) {
                    showingFolderPicker = true
                }
                
                QuickActionButton(
                    icon: "square.and.arrow.up",
                    title: "Share",
                    color: .green
                ) {
                    sharePop()
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                QuickActionButton(
                    icon: "trash",
                    title: "Delete",
                    color: .red
                ) {
                    showingDeleteConfirm = true
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .sheet(isPresented: $showingQuantityEditor) {
            QuantityEditorView(pop: pop, context: context)
        }
        .popover(isPresented: $showingAlertSetup) {
            PriceAlertSetupView(pop: pop)
        }
        .popover(isPresented: $showingFolderPicker) {
            FolderPickerView(pop: pop, folders: allFolders, context: context)
        }
        .alert("Delete Pop?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                context.delete(pop)
                try? context.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \"\(pop.name)\" from your collection.")
        }
    }
    
    private func sharePop() {
        let text = "\(pop.name) - $\(pop.displayValue, default: "%.2f")"
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activity, animated: true)
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding()
        }
    }
}

struct FolderPickerView: View {
    @Bindable var pop: PopItem
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
                        if pop.folder == nil {
                            Spacer()
                            Image(systemName: "checkmark")
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
                            OptimizedAsyncImage(url: folder.thumbnailURL, width: 40, height: 40)
                            Text(folder.name)
                            if pop.folder?.id == folder.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Move to Bin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

