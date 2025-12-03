//
//  ModernFilterSheet.swift
//  PopCollector
//
//  Beautiful filter sheet with Liquid Glass design, interactive sliders, and animations
//

import SwiftUI

struct ModernFilterSheet: View {
    @Binding var filterSeries: String
    @Binding var minValue: Double
    @Binding var maxValue: Double
    @Binding var showSignedOnly: Bool
    @Binding var showVaultedOnly: Bool
    
    @Environment(\.dismiss) private var dismiss
    @State private var localSeries: String
    @State private var localMinValue: Double
    @State private var localMaxValue: Double
    @State private var localShowSigned: Bool
    @State private var localShowVaulted: Bool
    
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
        
        // Initialize local state
        self._localSeries = State(initialValue: filterSeries.wrappedValue)
        self._localMinValue = State(initialValue: minValue.wrappedValue)
        self._localMaxValue = State(initialValue: maxValue.wrappedValue)
        self._localShowSigned = State(initialValue: showSignedOnly.wrappedValue)
        self._localShowVaulted = State(initialValue: showVaultedOnly.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [.blue.opacity(0.05), .purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Series Filter
                        seriesFilterSection
                        
                        // Value Range Filter
                        valueRangeSection
                        
                        // Toggle Filters
                        toggleFiltersSection
                        
                        // Active Filters Summary
                        activeFiltersSummary
                    }
                    .padding()
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            localSeries = ""
                            localMinValue = 0
                            localMaxValue = 10000
                            localShowSigned = false
                            localShowVaulted = false
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    .buttonStyle(.glass)
                    .disabled(!hasActiveFilters)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        applyFilters()
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var seriesFilterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text("Series")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            } icon: {
                Image(systemName: "tv.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.blue.gradient)
            }
            
            TextField("e.g. Solo Leveling", text: $localSeries)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private var valueRangeSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label {
                Text("Value Range")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            } icon: {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.green.gradient)
            }
            
            // Min Value
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Minimum")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("$\(Int(localMinValue))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.green.opacity(0.1))
                        )
                        .glassEffect(.regular.tint(.green), in: .capsule)
                }
                
                Slider(value: $localMinValue, in: 0...1000, step: 5) {
                    Text("Minimum Value")
                } minimumValueLabel: {
                    Text("$0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } maximumValueLabel: {
                    Text("$1000")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tint(.green)
                .onChange(of: localMinValue) { oldValue, newValue in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if newValue > localMaxValue {
                        localMaxValue = newValue
                    }
                }
            }
            
            // Max Value
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Maximum")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(localMaxValue >= 10000 ? "No Limit" : "$\(Int(localMaxValue))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.green.opacity(0.1))
                        )
                        .glassEffect(.regular.tint(.green), in: .capsule)
                }
                
                Slider(value: $localMaxValue, in: localMinValue...10000, step: 5) {
                    Text("Maximum Value")
                } minimumValueLabel: {
                    Text("$\(Int(localMinValue))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } maximumValueLabel: {
                    Text("∞")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tint(.green)
                .onChange(of: localMaxValue) { oldValue, newValue in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private var toggleFiltersSection: some View {
        VStack(spacing: 16) {
            // Signed Only Toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    localShowSigned.toggle()
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(localShowSigned ? .purple.gradient : .gray.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: localShowSigned ? "signature" : "signature")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(localShowSigned ? .white : .secondary)
                            .symbolEffect(.bounce, value: localShowSigned)
                    }
                    .glassEffect(.regular.interactive().tint(localShowSigned ? .purple : .clear), in: .circle)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Signed Pops Only")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Text("Show only autographed items")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: localShowSigned ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(localShowSigned ? .purple : .secondary)
                        .symbolEffect(.bounce, value: localShowSigned)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(localShowSigned ? Color.purple.opacity(0.5) : Color.clear, lineWidth: 2)
                )
                .shadow(color: localShowSigned ? .purple.opacity(0.3) : .black.opacity(0.05), radius: localShowSigned ? 15 : 10, x: 0, y: localShowSigned ? 8 : 5)
            }
            .buttonStyle(.plain)
            
            // Vaulted Only Toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    localShowVaulted.toggle()
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(localShowVaulted ? .orange.gradient : .gray.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: localShowVaulted ? "lock.shield.fill" : "lock.shield")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(localShowVaulted ? .white : .secondary)
                            .symbolEffect(.bounce, value: localShowVaulted)
                    }
                    .glassEffect(.regular.interactive().tint(localShowVaulted ? .orange : .clear), in: .circle)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vaulted Pops Only")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Text("Show only vaulted items")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: localShowVaulted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(localShowVaulted ? .orange : .secondary)
                        .symbolEffect(.bounce, value: localShowVaulted)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(localShowVaulted ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 2)
                )
                .shadow(color: localShowVaulted ? .orange.opacity(0.3) : .black.opacity(0.05), radius: localShowVaulted ? 15 : 10, x: 0, y: localShowVaulted ? 8 : 5)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var activeFiltersSummary: some View {
        Group {
            if hasActiveFilters {
                VStack(alignment: .leading, spacing: 16) {
                    Label {
                        Text("Active Filters")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    } icon: {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.blue.gradient)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        if !localSeries.isEmpty {
                            summaryRow(icon: "tv", text: "Series: \(localSeries)", color: .blue)
                        }
                        
                        if localMinValue > 0 || localMaxValue < 10000 {
                            let maxText = localMaxValue >= 10000 ? "No Limit" : "$\(Int(localMaxValue))"
                            summaryRow(icon: "dollarsign.circle", text: "$\(Int(localMinValue)) - \(maxText)", color: .green)
                        }
                        
                        if localShowSigned {
                            summaryRow(icon: "signature", text: "Signed Pops", color: .purple)
                        }
                        
                        if localShowVaulted {
                            summaryRow(icon: "lock.shield.fill", text: "Vaulted Pops", color: .orange)
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: hasActiveFilters)
    }
    
    private func summaryRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Helpers
    
    private var hasActiveFilters: Bool {
        !localSeries.isEmpty || localShowSigned || localShowVaulted || localMinValue > 0 || localMaxValue < 10000
    }
    
    private func applyFilters() {
        filterSeries = localSeries
        minValue = localMinValue
        maxValue = localMaxValue
        showSignedOnly = localShowSigned
        showVaultedOnly = localShowVaulted
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

#Preview {
    ModernFilterSheet(
        filterSeries: .constant(""),
        minValue: .constant(0),
        maxValue: .constant(10000),
        showSignedOnly: .constant(false),
        showVaultedOnly: .constant(false)
    )
}
