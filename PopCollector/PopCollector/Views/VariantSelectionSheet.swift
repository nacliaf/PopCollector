//
//  VariantSelectionSheet.swift
//  PopCollector
//
//  Shows all variants found for a scanned UPC and lets user select one
//

import SwiftUI
import SwiftData

struct VariantSelectionSheet: View {
    let variants: [PopLookupResult]
    let upc: String
    @Binding var selectedVariant: PopLookupResult?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Found \(variants.count) variant\(variants.count == 1 ? "" : "s")")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                ForEach(variants) { variant in
                    Button {
                        selectedVariant = variant
                        dismiss()
                    } label: {
                        HStack(spacing: 16) {
                            AsyncImage(url: URL(string: variant.imageURL)) { phase in
                                switch phase {
                                case .empty:
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay {
                                            ProgressView()
                                        }
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                case .failure:
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay {
                                            Image(systemName: "photo")
                                                .foregroundColor(.gray)
                                        }
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(width: 80, height: 80)
                            .cornerRadius(12)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(variant.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if !variant.number.isEmpty {
                                    Text("\(variant.series) #\(variant.number)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else if !variant.series.isEmpty {
                                    Text(variant.series)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(variant.source)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Select Variant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

