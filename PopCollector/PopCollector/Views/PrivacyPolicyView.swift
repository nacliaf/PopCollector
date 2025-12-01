//
//  PrivacyPolicyView.swift
//  PopCollector
//
//  Privacy Policy for App Store compliance
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .bold()
                
                Text("Last Updated: \(Date().formatted(date: .long, time: .omitted))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                SectionView(title: "Data Collection") {
                    Text("PopCollector does not collect, store, or transmit any personal information. All data is stored locally on your device using Apple's SwiftData framework.")
                }
                
                SectionView(title: "iCloud Sync") {
                    Text("If you enable iCloud sync, your collection data is stored in your personal iCloud account. This data is encrypted and only accessible by you. We do not have access to your iCloud data.")
                }
                
                SectionView(title: "API Keys") {
                    Text("If you choose to add an eBay API key, it is stored securely in your device's Keychain. We do not have access to your API keys, and they are never transmitted to our servers.")
                }
                
                SectionView(title: "Third-Party Services") {
                    Text("PopCollector uses the following third-party services:\n\n• eBay API - For price data (optional, requires your API key)\n• Mercari - For price data (via web scraping)\n• UPCItemDB - For Pop identification (free public API)\n\nWe do not share any data with these services beyond what is necessary for functionality.")
                }
                
                SectionView(title: "Contact") {
                    Text("If you have questions about this privacy policy, please contact us at support@popcollector.app")
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            content
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}

