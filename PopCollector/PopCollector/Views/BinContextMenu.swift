//
//  BinContextMenu.swift
//  PopCollector
//
//  Context menu for bin/folder actions (rename, delete, change thumbnail)
//

import SwiftUI
import SwiftData

struct BinContextMenu: View {
    @Bindable var folder: PopFolder
    let context: ModelContext
    
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Edit Bin")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Bin name editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bin Name")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextField("Bin name", text: $newName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onAppear {
                            newName = folder.name
                        }
                }
                .padding(.horizontal)
                
                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        folder.name = newName.trimmingCharacters(in: .whitespaces)
                        try? context.save()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    } label: {
                        Label("Rename Bin", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    
                    Button(role: .destructive) {
                        context.delete(folder)
                        try? context.save()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    } label: {
                        Label("Delete Bin", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Bin Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    BinContextMenu(
        folder: PopFolder(name: "Test Bin"),
        context: ModelContext(try! ModelContainer(for: PopItem.self, PopFolder.self))
    )
}

