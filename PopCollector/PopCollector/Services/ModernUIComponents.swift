//
//  ModernUIComponents.swift
//  PopCollector
//
//  Modern UI components with premium design
//  Uses current iOS APIs with glass-inspired effects
//

import SwiftUI

// MARK: - Modern Glass-Inspired Button Styles

struct ModernGlassButtonStyle: ButtonStyle {
    var isProminent: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isProminent ? Color.blue.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isProminent ? Color.blue.opacity(0.1) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .shadow(color: isProminent ? .blue.opacity(0.2) : .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

extension ButtonStyle where Self == ModernGlassButtonStyle {
    static var modernGlass: ModernGlassButtonStyle { ModernGlassButtonStyle() }
    static var modernGlassProminent: ModernGlassButtonStyle { ModernGlassButtonStyle(isProminent: true) }
}

// MARK: - Modern Card Style

struct ModernCardStyle: ViewModifier {
    var isPressed: Bool = false
    var backgroundColor: Color = .clear
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(backgroundColor.opacity(0.05))
            )
            .shadow(color: .black.opacity(isPressed ? 0.05 : 0.1), radius: isPressed ? 5 : 15, x: 0, y: isPressed ? 2 : 8)
            .scaleEffect(isPressed ? 0.98 : 1.0)
    }
}

extension View {
    func modernCard(isPressed: Bool = false, backgroundColor: Color = .clear) -> some View {
        modifier(ModernCardStyle(isPressed: isPressed, backgroundColor: backgroundColor))
    }
}

// MARK: - Modern Badge Style

struct ModernBadge: View {
    let title: String
    let icon: String
    let color: Color
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .foregroundStyle(color)
        .onTapGesture {
            if let onTap = onTap {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTap()
            }
        }
    }
}

// MARK: - Modern Empty State

struct ModernEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 28) {
            // Animated Icon
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .overlay(
                        Circle()
                            .stroke(.blue.opacity(0.2), lineWidth: 2)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 60, weight: .thin))
                    .foregroundStyle(.blue.gradient)
                    .symbolEffect(.pulse.byLayer)
            }
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            
            // Call to Action
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: 12) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 20, weight: .semibold))
                        Text(actionTitle)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 18)
                    .background(
                        Capsule()
                            .fill(.blue.gradient)
                            .shadow(color: .blue.opacity(0.4), radius: 20, x: 0, y: 10)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Modern Icon Button

struct ModernIconButton: View {
    let icon: String
    let color: Color
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isActive ? .white : color)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isActive ? color.gradient : .ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(color.opacity(isActive ? 0 : 0.3), lineWidth: 1)
                        )
                )
                .shadow(color: isActive ? color.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Modern Shimmer Effect (for loading states)

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Modern Progress View

struct ModernProgressView: View {
    let current: Int
    let total: Int
    let message: String
    
    var progress: Double {
        total > 0 ? Double(current) / Double(total) : 0
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress) {
                HStack {
                    Text(message)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("\(current)/\(total)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.blue)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .padding()
    }
}

// MARK: - Modern Filter Chip

struct ModernFilterChip: View {
    let title: String
    let icon: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
            
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    onRemove()
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .foregroundStyle(color)
    }
}

// MARK: - Modern Section Header

struct ModernSectionHeader: View {
    let title: String
    let count: Int?
    let icon: String
    
    init(title: String, count: Int? = nil, icon: String) {
        self.title = title
        self.count = count
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.blue.gradient)
            
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            if let count = count {
                Text("\(count)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Modern Loading Overlay

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
                .fill(.ultraThickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
    }
}

// MARK: - Previews

#Preview("Modern Buttons") {
    VStack(spacing: 20) {
        Button("Regular Button") {}
            .buttonStyle(.modernGlass)
        
        Button("Prominent Button") {}
            .buttonStyle(.modernGlassProminent)
        
        Button("Standard Button") {}
            .buttonStyle(.borderedProminent)
    }
    .padding()
}

#Preview("Modern Badge") {
    HStack {
        ModernBadge(title: "Signed", icon: "signature", color: .purple)
        ModernBadge(title: "Vaulted", icon: "lock.shield.fill", color: .orange)
        ModernBadge(title: "Chase", icon: "star.fill", color: .yellow)
    }
    .padding()
}

#Preview("Modern Empty State") {
    ModernEmptyState(
        icon: "books.vertical",
        title: "Your Collection Awaits",
        subtitle: "Start building your Funko Pop collection\nby scanning your first item",
        actionTitle: "Scan Your First Pop",
        action: {}
    )
}

#Preview("Modern Icon Button") {
    HStack(spacing: 16) {
        ModernIconButton(icon: "heart.fill", color: .red, isActive: true, action: {})
        ModernIconButton(icon: "bell", color: .purple, isActive: false, action: {})
        ModernIconButton(icon: "folder", color: .blue, isActive: false, action: {})
    }
    .padding()
}

#Preview("Modern Filter Chip") {
    ScrollView(.horizontal) {
        HStack(spacing: 12) {
            ModernFilterChip(title: "Signed", icon: "signature", color: .purple, onRemove: {})
            ModernFilterChip(title: "Vaulted", icon: "lock.shield.fill", color: .orange, onRemove: {})
            ModernFilterChip(title: "$50-$200", icon: "dollarsign.circle", color: .green, onRemove: {})
        }
        .padding()
    }
}

#Preview("Modern Section Header") {
    VStack {
        ModernSectionHeader(title: "My Collection", count: 42, icon: "books.vertical")
        ModernSectionHeader(title: "Wishlist", count: 15, icon: "heart.fill")
    }
}

#Preview("Modern Card") {
    VStack {
        Text("Card Content")
            .frame(maxWidth: .infinity)
            .padding()
            .modernCard()
    }
    .padding()
}

#Preview("Modern Loading Overlay") {
    ZStack {
        Color.blue.gradient.ignoresSafeArea()
        ModernLoadingOverlay(message: "Refreshing prices...")
    }
}

#Preview("Modern Progress") {
    ModernProgressView(current: 45, total: 100, message: "Updating prices...")
}
