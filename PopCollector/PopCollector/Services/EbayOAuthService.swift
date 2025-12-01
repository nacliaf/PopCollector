//
//  EbayOAuthService.swift
//  PopCollector
//
//  Handles eBay OAuth token generation and management
//

import Foundation

class EbayOAuthService {
    static let shared = EbayOAuthService()
    
    private let keychain = KeychainHelper.shared
    private var cachedToken: String?
    private var tokenExpiry: Date?
    
    private init() {}
    
    // Get valid OAuth token - generates if needed
    func getAccessToken() async -> String? {
        // Check if we have a valid cached token
        if let token = cachedToken,
           let expiry = tokenExpiry,
           expiry > Date() {
            return token
        }
        
        // Check keychain for cached token
        if let cachedTokenString = keychain.get(key: "ebay_oauth_token"),
           let expiryString = keychain.get(key: "ebay_token_expiry"),
           let expiryTimestamp = Double(expiryString),
           Date(timeIntervalSince1970: expiryTimestamp) > Date() {
            cachedToken = cachedTokenString
            tokenExpiry = Date(timeIntervalSince1970: expiryTimestamp)
            return cachedTokenString
        }
        
        // Generate new token
        return await generateNewToken()
    }
    
    // Check if credentials are for sandbox environment
    private func isSandbox() -> Bool {
        let clientId = keychain.get(key: "ebay_client_id") ?? ""
        let clientSecret = keychain.get(key: "ebay_client_secret") ?? ""
        // Sandbox credentials typically start with "SBX-" in Client ID or Client Secret
        return clientId.contains("SBX-") || clientSecret.contains("SBX-") || clientId.contains("-SBX-")
    }
    
    // Get the base API URL (sandbox or production)
    func getBaseAPIURL() -> String {
        return isSandbox() 
            ? "https://api.sandbox.ebay.com"
            : "https://api.ebay.com"
    }
    
    // Generate OAuth token using Client Credentials Grant
    private func generateNewToken() async -> String? {
        let clientId = keychain.get(key: "ebay_client_id") ?? ""
        let clientSecret = keychain.get(key: "ebay_client_secret") ?? ""
        
        guard !clientId.isEmpty, !clientSecret.isEmpty else {
            print("❌ eBay OAuth: Missing Client ID or Client Secret")
            return nil
        }
        
        // Encode credentials for Basic Auth
        let credentials = "\(clientId):\(clientSecret)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            return nil
        }
        let base64Credentials = credentialsData.base64EncodedString()
        
        // Determine if we should use sandbox or production
        let isSandboxEnv = isSandbox()
        let tokenURL = isSandboxEnv 
            ? "https://api.sandbox.ebay.com/identity/v1/oauth2/token"
            : "https://api.ebay.com/identity/v1/oauth2/token"
        
        print("🔑 eBay OAuth: Using \(isSandboxEnv ? "Sandbox" : "Production") environment")
        
        guard let url = URL(string: tokenURL) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // OAuth parameters - Request the scope for viewing public data (Browse API)
        // The scope URL is the same for both sandbox and production
        let scope = "https://api.ebay.com/oauth/api_scope"
        let bodyString = "grant_type=client_credentials&scope=\(scope)"
        request.httpBody = bodyString.data(using: .utf8)
        
        print("🔑 Requesting scope: \(scope) (for Browse API access)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ eBay OAuth: No HTTP response")
                return nil
            }
            
            print("📡 eBay OAuth HTTP Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode >= 400 {
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ eBay OAuth Error: \(errorData)")
                }
                return nil
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String,
                  let expiresIn = json["expires_in"] as? Int else {
                print("❌ eBay OAuth: Could not parse token response")
                return nil
            }
            
            // Cache token (expires in expiresIn seconds, but cache for 90% of that time)
            let expiryTime = Double(expiresIn) * 0.9
            let expiryDate = Date().addingTimeInterval(expiryTime)
            
            cachedToken = accessToken
            tokenExpiry = expiryDate
            
            // Save to keychain
            keychain.save(key: "ebay_oauth_token", value: accessToken)
            keychain.save(key: "ebay_token_expiry", value: String(expiryDate.timeIntervalSince1970))
            
            print("✅ eBay OAuth: Token generated successfully (expires in \(expiresIn) seconds)")
            return accessToken
            
        } catch {
            print("❌ eBay OAuth Error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Clear cached token (useful for testing or if credentials change)
    func clearToken() {
        cachedToken = nil
        tokenExpiry = nil
        keychain.delete(key: "ebay_oauth_token")
        keychain.delete(key: "ebay_token_expiry")
    }
}

