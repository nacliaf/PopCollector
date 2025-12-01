//
//  ContentView.swift
//  PopCollector
//
//  Main app view with tab navigation
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    
    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else {
                TabView {
                    HomeTabView()
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }
                    
                    CollectionView()
                        .tabItem {
                            Label("Collection", systemImage: "tray.full")
                        }
                    
                    ScanTabView()
                        .tabItem {
                            Label("Scan", systemImage: "barcode.viewfinder")
                        }
                    
                    WishlistView()
                        .tabItem {
                            Label("Wishlist", systemImage: "heart.fill")
                        }
                    
                    StatsTabView()
                        .tabItem {
                            Label("Stats", systemImage: "chart.bar.fill")
                        }
                    
                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                }
            }
        }
        .onAppear {
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [PopItem.self, PopFolder.self], inMemory: true)
}


