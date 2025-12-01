//
//  PriceChecker.swift
//  PopCollector
//
//  Background price checker for alerts
//

import Foundation
import SwiftData
import BackgroundTasks
import UserNotifications

class PriceChecker {
    static let shared = PriceChecker()
    private let taskID = "com.popcollector.pricecheck"
    private let priceFetcher = PriceFetcher()
    
    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            self.handlePriceCheck(task: task as! BGAppRefreshTask)
        }
    }
    
    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        try? BGTaskScheduler.shared.submit(request)
    }
    
    // Check prices for all Pops with alerts enabled (called from app when active)
    func checkPricesForAlerts(context: ModelContext) async {
        let descriptor = FetchDescriptor<PopItem>(
            predicate: #Predicate<PopItem> { $0.isAlertEnabled && $0.targetPrice != nil }
        )
        
        guard let pops = try? context.fetch(descriptor) else { return }
        
        for pop in pops {
            if let priceResult = await priceFetcher.fetchAveragePrice(for: pop.name, upc: pop.upc) {
                let newPrice = priceResult.averagePrice
                let targetPrice = pop.targetPrice ?? 0
                
                // Check if price dropped below target and we haven't notified yet
                if newPrice <= targetPrice && (pop.notifiedPrice == nil || newPrice < (pop.notifiedPrice ?? 99999)) {
                    sendNotification(for: pop, newPrice: newPrice)
                    pop.notifiedPrice = newPrice
                }
                
                // Update current price
                pop.value = newPrice
                pop.lastUpdated = priceResult.lastUpdated
                pop.source = priceResult.source
                pop.trend = priceResult.trend
            }
        }
        
        try? context.save()
    }
    
    private func handlePriceCheck(task: BGAppRefreshTask) {
        schedule() // Reschedule for next time
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Note: Background tasks have limited ModelContext access
        // Main price checking happens when app is active via checkPricesForAlerts()
        // This schedules the next check
        
        task.setTaskCompleted(success: true)
    }
    
    private func sendNotification(for pop: PopItem, newPrice: Double) {
        let content = UNMutableNotificationContent()
        content.title = "💰 Price Drop Alert!"
        content.body = "\(pop.name) is now $\(String(format: "%.2f", newPrice)) — your target was $\(String(format: "%.2f", pop.targetPrice ?? 0))"
        content.sound = .default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            } else {
                print("✅ Price alert notification sent for \(pop.name)")
            }
        }
    }
}

