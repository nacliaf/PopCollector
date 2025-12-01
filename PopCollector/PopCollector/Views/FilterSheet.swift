//
//  FilterSheet.swift
//  PopCollector
//
//  Advanced filter sheet with beautiful sliders
//

import SwiftUI

struct FilterSheet: View {
    @Binding var filterSeries: String
    @Binding var minValue: Double
    @Binding var maxValue: Double
    @Binding var showSignedOnly: Bool
    @Binding var showVaultedOnly: Bool
    
    @Environment(\.dismiss) var dismiss
    @State private var tempMinValue: Double
    @State private var tempMaxValue: Double
    
    init(
        filterSeries: Binding<String>,
        minValue: Binding<Double>,
        maxValue: Binding<Double>,
        showSignedOnly: Binding<Bool>,
        showVaultedOnly: Binding<Bool>
    ) {
        self._filterSeries = filterSeries
        self._minValue = minValue
        self._maxValue = maxValue
        self._showSignedOnly = showSignedOnly
        self._showVaultedOnly = showVaultedOnly
        self._tempMinValue = State(initialValue: minValue.wrappedValue)
        self._tempMaxValue = State(initialValue: maxValue.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Series") {
                    TextField("e.g. Marvel, Star Wars", text: $filterSeries)
                }
                
                Section("Value Range") {
                    VStack(spacing: 20) {
                        Text("$\(Int(tempMinValue)) – $\(Int(tempMaxValue))")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                            .contentTransition(.numericText())
                            .animation(.spring, value: tempMinValue)
                            .animation(.spring, value: tempMaxValue)
                        
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Minimum: $\(Int(tempMinValue))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Slider(value: $tempMinValue, in: 0...5000, step: 10)
                                    .tint(.green)
                                    .onChange(of: tempMinValue) { oldValue, newValue in
                                        if newValue > tempMaxValue {
                                            tempMaxValue = newValue
                                        }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Maximum: $\(Int(tempMaxValue))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Slider(value: $tempMaxValue, in: 0...10000, step: 50)
                                    .tint(.red)
                                    .onChange(of: tempMaxValue) { oldValue, newValue in
                                        if newValue < tempMinValue {
                                            tempMinValue = newValue
                                        }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Special") {
                    Toggle("Signed Only", isOn: $showSignedOnly)
                        .tint(.purple)
                    
                    Toggle("Vaulted Only", isOn: $showVaultedOnly)
                        .tint(.orange)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        filterSeries = ""
                        tempMinValue = 0
                        tempMaxValue = 10000
                        showSignedOnly = false
                        showVaultedOnly = false
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        minValue = tempMinValue
                        maxValue = tempMaxValue
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    FilterSheet(
        filterSeries: .constant(""),
        minValue: .constant(0),
        maxValue: .constant(10000),
        showSignedOnly: .constant(false),
        showVaultedOnly: .constant(false)
    )
}

