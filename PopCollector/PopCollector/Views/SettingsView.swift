//
//  SettingsView.swift
//  PopCollector
//
//  Settings tab for per-user eBay API key and export
//

import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Query private var allPops: [PopItem]
    @ObservedObject private var databaseService = FunkoDatabaseService.shared
    @State private var ebayClientId = ""
    @State private var ebayClientSecret = ""
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isGeneratingToken = false
    @State private var tokenStatus = ""
    
    private let keychain = KeychainHelper.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section("eBay API Credentials (Optional)") {
                    TextField("Client ID (App ID)", text: $ebayClientId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    SecureField("Client Secret (Cert ID)", text: $ebayClientSecret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    Button(action: saveCredentials) {
                        HStack {
                            if isGeneratingToken {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Generating Token...")
                            } else {
                                Text("Save & Generate Token")
                            }
                        }
                    }
                    .bold()
                    .disabled(isGeneratingToken || ebayClientId.isEmpty || ebayClientSecret.isEmpty)
                    
                    if !tokenStatus.isEmpty {
                        Label(tokenStatus, systemImage: tokenStatus.contains("Success") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(tokenStatus.contains("Success") ? .green : .orange)
                            .font(.caption)
                    }
                    
                    if showSuccess {
                        Label("Saved! eBay API will now work", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    
                    if showError {
                        Label(errorMessage.isEmpty ? "Please enter valid credentials" : errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                .onAppear {
                    loadSavedCredentials()
                }
                
                Section("Why add credentials?") {
                    Text("• Lightning-fast eBay search results\n• Accurate sold item prices\n• Your own 5,000 free API calls/day\n• No bot detection issues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("How to get credentials:") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Go to developer.ebay.com")
                        Text("2. Sign in and create an app")
                        Text("3. Copy your Client ID (App ID)")
                        Text("4. Copy your Client Secret (Cert ID)")
                        Text("5. Paste both above and save")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Link("Get eBay API credentials →", destination: URL(string: "https://developer.ebay.com/my/keys")!)
                        .foregroundColor(.blue)
                }
                
                Section("Database Updates") {
                    HStack {
                        if databaseService.isUpdatingDatabase {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Updating database...")
                                .foregroundColor(.secondary)
                        } else if databaseService.databaseUpdateAvailable {
                            Label("Update Available", systemImage: "arrow.down.circle.fill")
                                .foregroundColor(.blue)
                        } else {
                            Label("Up to Date", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        Spacer()
                    }
                    .font(.caption)
                    
                    if let lastCheck = databaseService.lastUpdateCheck {
                        Text("Last checked: \(lastCheck, style: .relative)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastModified = databaseService.databaseLastModified {
                        Text("Database last updated: \(lastModified, style: .date)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Button {
                        Task {
                            await databaseService.checkForDatabaseUpdates()
                        }
                    } label: {
                        Label("Check for Updates", systemImage: "arrow.clockwise")
                    }
                    .disabled(databaseService.isUpdatingDatabase)
                    
                    if databaseService.databaseUpdateAvailable {
                        Button {
                            Task {
                                await databaseService.loadCSVDatabase(forceUpdate: true)
                            }
                        } label: {
                            Label("Update Now", systemImage: "arrow.down.circle")
                        }
                        .disabled(databaseService.isUpdatingDatabase)
                    }
                    
                    Text("Database is cached locally for fast searches. Updates are checked automatically on app launch.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Backup & Restore") {
                    Button {
                        exportBackup()
                    } label: {
                        Label("Export Backup", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        importBackup()
                    } label: {
                        Label("Import Backup", systemImage: "square.and.arrow.down")
                    }
                    
                    Text("Backup includes all Pops, folders, and settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Export Collection") {
                    Button {
                        exportToCSV()
                    } label: {
                        Label("Export to CSV", systemImage: "doc.text")
                    }
                    
                    Text("Export your entire collection as a CSV file")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("About") {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                    
                    Link("Support", destination: URL(string: "mailto:support@popcollector.app")!)
                        .foregroundColor(.blue)
                    
                    Text("Version 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    private func exportBackup() {
        // Create backup JSON
        let backup: [String: Any] = [
            "version": "1.0",
            "date": ISO8601DateFormatter().string(from: Date()),
            "pops": allPops.map { pop in
                [
                    "id": pop.id.uuidString,
                    "name": pop.name,
                    "number": pop.number,
                    "series": pop.series,
                    "value": pop.value,
                    "imageURL": pop.imageURL,
                    "upc": pop.upc,
                    "quantity": pop.quantity,
                    "isSigned": pop.isSigned,
                    "signedBy": pop.signedBy,
                    "hasCOA": pop.hasCOA,
                    "isVaulted": pop.isVaulted,
                    "isInWishlist": pop.isInWishlist,
                    "folder": pop.folder?.name ?? "",
                    "dateAdded": ISO8601DateFormatter().string(from: pop.dateAdded)
                ]
            }
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: backup, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("PopCollector_Backup_\(Date().timeIntervalSince1970).json")
            
            do {
                try jsonString.write(to: url, atomically: true, encoding: .utf8)
                let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(activity, animated: true)
                }
            } catch {
                ErrorHandler.shared.showError(.exportFailed)
            }
        }
    }
    
    private func importBackup() {
        // This would open a document picker
        // For now, show a message
        Toast.show(message: "Use Files app to import backup", systemImage: "info.circle")
    }
    
    private func exportToCSV() {
        let header = "Name,Number,Series,Value,Quantity,Total Value,Bin,UPC,Date Added\n"
        let rows = allPops.map { pop in
            let totalValue = pop.value * Double(pop.quantity)
            return "\"\(pop.name)\",\"\(pop.number)\",\"\(pop.series)\",\(pop.value),\(pop.quantity),\(totalValue),\"\(pop.folder?.name ?? "None")\",\"\(pop.upc)\",\"\(pop.dateAdded)\""
        }
        
        let csv = header + rows.joined(separator: "\n")
        
        // Save to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("PopCollector_Export_\(Date().timeIntervalSince1970).csv")
        
        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // Share the file
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("Export error: \(error)")
        }
    }
    
    private func loadSavedCredentials() {
        ebayClientId = keychain.get(key: "ebay_client_id") ?? ""
        ebayClientSecret = keychain.get(key: "ebay_client_secret") ?? ""
        
        // Check if we have a valid token
        if let _ = keychain.get(key: "ebay_oauth_token"),
           let expiryString = keychain.get(key: "ebay_token_expiry"),
           let expiryTimestamp = Double(expiryString),
           Date(timeIntervalSince1970: expiryTimestamp) > Date() {
            let hoursUntilExpiry = Int((Date(timeIntervalSince1970: expiryTimestamp).timeIntervalSinceNow) / 3600)
            tokenStatus = "Token active (expires in \(hoursUntilExpiry) hours)"
        }
    }
    
    private func saveCredentials() {
        let trimmedId = ebayClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = ebayClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedId.isEmpty, !trimmedSecret.isEmpty else {
            showError = true
            errorMessage = "Please enter both Client ID and Client Secret"
            return
        }
        
        // Save credentials
        keychain.save(key: "ebay_client_id", value: trimmedId)
        keychain.save(key: "ebay_client_secret", value: trimmedSecret)
        
        // Clear old token to force regeneration
        EbayOAuthService.shared.clearToken()
        
        // Generate new token
        isGeneratingToken = true
        showError = false
        errorMessage = ""
        tokenStatus = ""
        
        Task {
            if let _ = await EbayOAuthService.shared.getAccessToken() {
                await MainActor.run {
                    showSuccess = true
                    isGeneratingToken = false
                    tokenStatus = "Success! Token generated and saved"
                    hideKeyboard()
                    
                    // Hide success message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showSuccess = false
                    }
                }
            } else {
                await MainActor.run {
                    isGeneratingToken = false
                    showError = true
                    errorMessage = "Failed to generate token. Check your credentials and try again."
                    tokenStatus = "Token generation failed"
                }
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
}

#Preview {
    SettingsView()
}
