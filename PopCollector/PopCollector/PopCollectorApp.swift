//
//  PopCollectorApp.swift
//  PopCollector
//
//  Created for Funko Pop Collection Tracker
//

import SwiftUI
import SwiftData
import UserNotifications
import BackgroundTasks

@main
struct PopCollectorApp: App {
    init() {
        // Configure image caching for better performance
        let cache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,  // 50 MB memory cache
            diskCapacity: 200 * 1024 * 1024,    // 200 MB disk cache
            diskPath: "PopCollectorImageCache"
        )
        URLCache.shared = cache
        
        // Request notification permissions for price alerts and database updates
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            } else if granted {
                print("✅ Notification permissions granted")
            }
        }
        
        // Register background price checker
        PriceChecker.shared.register()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Schedule background price checks
                    PriceChecker.shared.schedule()
                    
                    // Check for database updates in background on app launch
                    Task {
                        await FunkoDatabaseService.shared.checkForDatabaseUpdates()
                        
                        // If update is available, load it automatically
                        let hasUpdate = await MainActor.run {
                            FunkoDatabaseService.shared.databaseUpdateAvailable
                        }
                        if hasUpdate {
                            print("🔄 Auto-updating database on launch...")
                            await FunkoDatabaseService.shared.loadCSVDatabase(forceUpdate: true)
                        }
                    }
                }
        }
        .modelContainer(for: [PopItem.self, PopFolder.self])
        // Background task registration is handled in PriceChecker.shared.register()
        // SwiftUI's backgroundTask modifier may have API compatibility issues
    }
}

