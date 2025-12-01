//
//  ErrorHandler.swift
//  PopCollector
//
//  Centralized error handling with user-friendly messages
//

import SwiftUI

enum AppError: LocalizedError {
    case networkError
    case lookupFailed
    case priceFetchFailed
    case saveFailed
    case exportFailed
    case invalidAPIKey
    case rateLimited
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "No internet connection. Please check your network and try again."
        case .lookupFailed:
            return "Couldn't find this Pop. Try scanning again or enter manually."
        case .priceFetchFailed:
            return "Couldn't fetch price right now. Prices will update automatically."
        case .saveFailed:
            return "Couldn't save your changes. Please try again."
        case .exportFailed:
            return "Export failed. Please try again."
        case .invalidAPIKey:
            return "Invalid API key. Please check your eBay API key in Settings."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .unknown(let error):
            return "Something went wrong: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Check your Wi-Fi or cellular connection."
        case .lookupFailed:
            return "You can add this Pop manually from the collection view."
        case .priceFetchFailed:
            return "Pull down to refresh prices when you have internet."
        case .saveFailed:
            return "Make sure you have enough storage space."
        case .exportFailed:
            return "Try exporting again or check available storage."
        case .invalidAPIKey:
            return "Go to Settings and update your eBay API key."
        case .rateLimited:
            return "Wait 30 seconds before trying again."
        case .unknown:
            return "If this persists, try restarting the app."
        }
    }
}

class ErrorHandler {
    static let shared = ErrorHandler()
    
    private init() {}
    
    func handle(_ error: Error, showToast: Bool = true) {
        let appError: AppError
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                appError = .networkError
            case .timedOut:
                appError = .networkError
            case .httpTooManyRedirects:
                appError = .rateLimited
            default:
                appError = .unknown(error)
            }
        } else if error is AppError {
            appError = error as! AppError
        } else {
            appError = .unknown(error)
        }
        
        print("❌ Error: \(appError.localizedDescription)")
        
        if showToast {
            Toast.show(
                message: appError.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }
    
    func showError(_ error: AppError, showToast: Bool = true) {
        if showToast {
            Toast.show(
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }
}

