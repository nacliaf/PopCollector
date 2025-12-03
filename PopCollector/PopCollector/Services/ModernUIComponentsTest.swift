//
//  ModernUIComponentsTest.swift
//  PopCollector
//
//  Quick test to verify all modern UI components compile correctly
//

import SwiftUI

struct ModernUIComponentsTest: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Test Modern Buttons
                Button("Test Glass Button") {}
                    .buttonStyle(.modernGlass)
                
                Button("Test Prominent Button") {}
                    .buttonStyle(.modernGlassProminent)
                
                // Test Modern Badge
                ModernBadge(title: "Test", icon: "star.fill", color: .blue)
                
                // Test Modern Empty State
                ModernEmptyState(
                    icon: "checkmark.circle.fill",
                    title: "All Components Work!",
                    subtitle: "Modern UI is ready to use",
                    actionTitle: "Get Started",
                    action: {}
                )
                
                // Test Modern Icon Button
                ModernIconButton(
                    icon: "heart.fill",
                    color: .red,
                    isActive: true,
                    action: {}
                )
                
                // Test Modern Card
                Text("Card Content")
                    .padding()
                    .modernCard()
                
                // Test Modern Filter Chip
                ModernFilterChip(
                    title: "Test Filter",
                    icon: "star.fill",
                    color: .purple,
                    onRemove: {}
                )
                
                // Test Modern Progress
                ModernProgressView(
                    current: 50,
                    total: 100,
                    message: "Testing..."
                )
                
                // Test Shimmer
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: 100)
                    .shimmer()
            }
            .padding()
        }
    }
}

#Preview {
    ModernUIComponentsTest()
}
