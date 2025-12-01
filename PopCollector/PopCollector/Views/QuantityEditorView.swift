//
//  QuantityEditorView.swift
//  PopCollector
//
//  Edit quantity of a Pop with beautiful slider
//

import SwiftUI
import SwiftData

struct QuantityEditorView: View {
    @Bindable var pop: PopItem
    let context: ModelContext
    
    @Environment(\.dismiss) private var dismiss
    @State private var quantity: Double
    
    init(pop: PopItem, context: ModelContext) {
        self.pop = pop
        self.context = context
        self._quantity = State(initialValue: Double(pop.quantity))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Pop Image
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
                .frame(width: 100, height: 100)
                .cornerRadius(12)
                
                // Pop Name
                Text(pop.name)
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Big Quantity Number
                Text("\(Int(quantity))")
                    .font(.system(size: 100, weight: .bold, design: .rounded))
                    .foregroundColor(quantity == 0 ? .red : .blue)
                    .contentTransition(.numericText())
                    .animation(.spring, value: quantity)
                
                // Slider
                VStack(spacing: 8) {
                    Slider(value: $quantity, in: 0...50, step: 1)
                        .padding(.horizontal, 40)
                    
                    HStack {
                        Text("0")
                            .foregroundColor(.red)
                            .font(.caption)
                        Spacer()
                        Text("50+")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    .padding(.horizontal, 50)
                }
                
                // Value Preview
                if pop.value > 0 {
                    Text("Total value: $\(pop.value * quantity, specifier: "%.2f")")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if quantity == 0 {
                        Button("Delete") {
                            context.delete(pop)
                            try? context.save()
                            dismiss()
                        }
                        .foregroundColor(.red)
                        .bold()
                    } else {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        pop.quantity = Int(quantity)
                        pop.lastUpdated = Date()
                        try? context.save()
                        dismiss()
                    }
                    .bold()
                }
            }
            .navigationTitle("Edit Quantity")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

