//
//  AIExclusivityRecognizer.swift
//  PopCollector
//
//  AI-powered exclusivity recognition using Vision framework and NLP
//

import Foundation
import Vision
import UIKit
import NaturalLanguage
import CoreImage

class AIExclusivityRecognizer {
    static let shared = AIExclusivityRecognizer()
    
    private init() {}
    
    // Known retailer and convention patterns for AI matching
    // Comprehensive list matching FunkoDatabaseService patterns
    private let retailerPatterns: [String: String] = [
        "hot topic": "Hot Topic Exclusive",
        "target": "Target Exclusive",
        "walmart": "Walmart Exclusive",
        "amazon": "Amazon Exclusive",
        "gamestop": "GameStop Exclusive",
        "boxlunch": "BoxLunch Exclusive",
        "funko shop": "Funko Shop Exclusive",
        "entertainment earth": "Entertainment Earth Exclusive",
        "fugitive toys": "Fugitive Toys Exclusive",
        "bam!": "BAM! Exclusive",
        "bam": "BAM! Exclusive",
        "books a million": "BAM! Exclusive",
        "chalice collectibles": "Chalice Collectibles Exclusive",
        "chalice": "Chalice Collectibles Exclusive",
        "toys r us": "Toys R Us Exclusive",
        "toysrus": "Toys R Us Exclusive",
        "toys 'r' us": "Toys R Us Exclusive",
        "toys'r'us": "Toys R Us Exclusive",
        "walgreens": "Walgreens Exclusive",
        "cvs": "CVS Exclusive",
        "7-eleven": "7-Eleven Exclusive",
        "7 eleven": "7-Eleven Exclusive",
        "thinkgeek": "ThinkGeek Exclusive",
        "specialty series": "Specialty Series Exclusive",
        "px previews": "PX Previews Exclusive",
        "previews exclusive": "PX Previews Exclusive",
        "previews": "PX Previews Exclusive",
        "px": "PX Previews Exclusive",
        "lootcrate": "Lootcrate Exclusive",
        "loot crate": "Lootcrate Exclusive",
        "loot": "Lootcrate Exclusive",
        "midtown comics": "Midtown Comics Exclusive",
        "toy tokyo": "Toy Tokyo Exclusive",
        "barnes and noble": "Barnes & Noble Exclusive",
        "barnes & noble": "Barnes & Noble Exclusive",
        "dc legion collectors": "DC Legion Collectors Exclusive",
        "fye": "FYE Exclusive",
        "f.y.e.": "FYE Exclusive",
        "fanatics": "Fanatics Exclusive",
        "best buy": "Best Buy Exclusive",
        "bestbuy": "Best Buy Exclusive",
        "gemini collectibles": "Gemini Collectibles Exclusive",
        "gemini": "Gemini Collectibles Exclusive",
        "popcultcha": "Popcultcha Exclusive",
        "pop in a box": "Pop in a Box Exclusive",
        "popinabox": "Pop in a Box Exclusive",
        "piab": "Pop in a Box Exclusive",
        "sam's club": "Sam's Club Exclusive",
        "sams club": "Sam's Club Exclusive",
        "baskin robbins": "Baskin Robbins Exclusive",
        "baskin-robbins": "Baskin Robbins Exclusive",
        "coca-cola store": "Coca-Cola Store Exclusive",
        "coca cola": "Coca-Cola Store Exclusive",
        "coca cola store": "Coca-Cola Store Exclusive",
        "five below": "Five Below Exclusive",
        "fivebelow": "Five Below Exclusive",
        "kohl's": "Kohl's Exclusive",
        "kohls": "Kohl's Exclusive",
        "only at kohl's": "Kohl's Exclusive",
        "meijer": "Meijer Exclusive",
        "spencer's": "Spencer's Exclusive",
        "spencers": "Spencer's Exclusive",
        "spirit halloween": "Spirit Halloween Exclusive",
        "urban outfitters": "Urban Outfitters Exclusive",
        "party city": "Party City Exclusive",
        "michaels": "Michaels Exclusive",
        "dick's sporting goods": "Dick's Sporting Goods Exclusive",
        "dicks sporting goods": "Dick's Sporting Goods Exclusive",
        "foot locker": "Foot Locker Exclusive",
        "footlocker": "Foot Locker Exclusive",
        "cinemark": "Cinemark Exclusive",
        "regal cinemas": "Regal Cinemas Exclusive",
        "regal theatres": "Regal Theatres Exclusive",
        "amc theatres": "AMC Theatres Exclusive",
        "amc": "AMC Theatres Exclusive",
        "disney parks": "Disney Parks Exclusive",
        "disney exclusive": "Disney Exclusive",
        "disney": "Disney Exclusive",
        "funko.com": "Funko Shop Exclusive",
        "funko (funko.com)": "Funko Shop Exclusive",
        "crunchyroll": "Crunchyroll Exclusive",
        "netflix shop": "Netflix Shop Exclusive",
        "netflix": "Netflix Shop Exclusive",
        "hbo shop": "HBO Shop Exclusive",
        "hbo": "HBO Exclusive",
        "xbox gear shop": "Xbox Gear Shop Exclusive",
        "xbox": "Xbox Gear Shop Exclusive",
        "playstation": "PlayStation Official Licensed Product",
        "ps4": "PlayStation Official Licensed Product",
        "ps5": "PlayStation Official Licensed Product",
        "pokémon center": "Pokémon Center Exclusive",
        "pokemon center": "Pokémon Center Exclusive",
        "big bad toy store": "Big Bad Toy Store Exclusive",
        "bbts": "Big Bad Toy Store Exclusive"
    ]
    
    private let conventionPatterns: [String: String] = [
        "nycc": "NYCC Exclusive",
        "new york comic con": "NYCC Exclusive",
        "sdcc": "SDCC Exclusive",
        "san diego comic con": "San Diego Comic-Con (SDCC) Exclusive",
        "san diego comic-con": "San Diego Comic-Con (SDCC) Exclusive",
        "comic-con": "SDCC Exclusive",
        "eccc": "ECCC Exclusive",
        "emerald city comic con": "Emerald City Comic Con (ECCC) Exclusive",
        "c2e2": "C2E2 Exclusive",
        "fan expo": "Fan Expo Exclusive",
        "dallas comic con": "Dallas Comic Con Exclusive",
        "dallas comic-con": "Dallas Comic Con Exclusive",
        "dcc": "Dallas Comic Con Exclusive",
        "wondercon": "WonderCon Exclusive",
        "wonder con": "WonderCon Exclusive",
        "mefcc": "MEFCC Exclusive",
        "middle east film & comic con": "MEFCC Exclusive",
        "convention shared": "Convention Shared Exclusive",
        "shared exclusive": "Convention Shared Exclusive",
        "convention exclusive": "Convention Exclusive",
        "summer convention": "Summer Convention Exclusive",
        "spring convention": "Spring Convention Limited Edition",
        "fall convention": "Fall Convention Limited Edition",
        "winter convention": "Winter Convention Limited Edition"
    ]
    
    // Subscription box and special edition patterns
    private let subscriptionBoxPatterns: [String: String] = [
        "marvel collector corps": "Marvel Collector Corps Exclusive",
        "mcc": "Marvel Collector Corps Exclusive",
        "collector corps": "Marvel Collector Corps Exclusive",
        "marvel collector": "Marvel Collector Corps Exclusive",  // Partial match
        "collectorcorps": "Marvel Collector Corps Exclusive",  // No space variant
        "smuggler's bounty": "Smuggler's Bounty Exclusive (Star Wars)",
        "smugglers bounty": "Smuggler's Bounty Exclusive (Star Wars)",
        "smugglersbounty": "Smuggler's Bounty Exclusive (Star Wars)",  // No space variant
        "disney treasures": "Disney Treasures Exclusive",
        "horror block": "Horror Block Exclusive",
        "nerd block": "Nerd Block Exclusive",
        "my geek box": "My Geek Box Exclusive",
        "dc legion of collectors": "DC Legion of Collectors Exclusive",
        "dc legion collectors": "DC Legion Collectors Exclusive",
        "dc legion": "DC Legion Collectors Exclusive"  // Partial match
    ]
    
    // MARK: - Text Recognition from Images
    
    /// Uses Vision framework to extract text from Pop box images and identify exclusivity stickers
    func recognizeExclusivityFromImage(_ image: UIImage) async -> [String] {
        // Preprocess image for better text recognition
        let processedImage = preprocessImageForTextRecognition(image)
        
        guard let cgImage = processedImage.cgImage else { 
            print("⚠️ AI: Could not get CGImage from UIImage")
            return [] 
        }
        
        var foundExclusivities: [String] = []
        var allRecognizedText: [String] = []
        
        // Create text recognition request
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("⚠️ AI Text Recognition error: \(error.localizedDescription)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("⚠️ AI: No text observations found")
                return
            }
            
            print("🔍 AI: Found \(observations.count) text observations")
            
            // Get multiple candidates for better recognition (up to 3 per observation)
            for observation in observations {
                let candidates = observation.topCandidates(3)
                for candidate in candidates {
                    let recognizedText = candidate.string.lowercased()
                    allRecognizedText.append(recognizedText)
                    
                    // Check for retailer patterns
                    for (pattern, exclusivity) in self.retailerPatterns {
                        if recognizedText.contains(pattern) && !foundExclusivities.contains(exclusivity) {
                            foundExclusivities.append(exclusivity)
                            print("✅ AI: Found retailer pattern '\(pattern)' -> '\(exclusivity)' in text: '\(recognizedText.prefix(50))'")
                        }
                    }
                    
                    // Check for convention patterns
                    for (pattern, exclusivity) in self.conventionPatterns {
                        if recognizedText.contains(pattern) && !foundExclusivities.contains(exclusivity) {
                            foundExclusivities.append(exclusivity)
                            print("✅ AI: Found convention pattern '\(pattern)' -> '\(exclusivity)' in text: '\(recognizedText.prefix(50))'")
                        }
                    }
                    
                    // Check for subscription box patterns
                    for (pattern, exclusivity) in self.subscriptionBoxPatterns {
                        if recognizedText.contains(pattern) && !foundExclusivities.contains(exclusivity) {
                            foundExclusivities.append(exclusivity)
                            print("✅ AI: Found subscription box pattern '\(pattern)' -> '\(exclusivity)' in text: '\(recognizedText.prefix(50))'")
                        }
                    }
                }
            }
            
            // Print all recognized text for debugging
            if !allRecognizedText.isEmpty {
                print("📝 AI: All recognized text snippets (\(allRecognizedText.count)):")
                for (index, text) in allRecognizedText.enumerated() {
                    if text.count > 0 {
                        print("   [\(index)]: '\(text.prefix(100))'")
                    }
                }
            } else {
                print("⚠️ AI: No text was recognized from the image")
            }
        }
        
        // Configure for accurate recognition
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // Perform the request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("⚠️ AI Text Recognition error: \(error.localizedDescription)")
        }
        
        return foundExclusivities
    }
    
    // MARK: - Image Preprocessing
    
    /// Preprocesses image to improve text recognition (scales up, enhances contrast)
    private func preprocessImageForTextRecognition(_ image: UIImage) -> UIImage {
        // Scale up image if it's too small (Vision works better on larger images)
        let targetSize: CGFloat = 2000  // Scale to at least 2000px on longest side
        let currentSize = max(image.size.width, image.size.height)
        
        var processedImage = image
        
        // Scale up if image is smaller than target
        if currentSize < targetSize {
            let scale = targetSize / currentSize
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            defer { UIGraphicsEndImageContext() }
            
            image.draw(in: CGRect(origin: .zero, size: newSize))
            if let scaled = UIGraphicsGetImageFromCurrentImageContext() {
                processedImage = scaled
                print("   🔍 AI: Scaled image from \(Int(currentSize))px to \(Int(targetSize))px")
            }
        }
        
        // Enhance contrast and brightness for better text recognition
        guard let ciImage = CIImage(image: processedImage),
              let filter = CIFilter(name: "CIColorControls") else {
            print("   ⚠️ AI: Could not create CIFilter for image enhancement")
            return processedImage
        }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(1.3, forKey: kCIInputContrastKey)  // Increase contrast more
        filter.setValue(0.15, forKey: kCIInputBrightnessKey)  // Slight brightness increase
        filter.setValue(1.0, forKey: kCIInputSaturationKey)
        
        let context = CIContext()
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            print("   ⚠️ AI: Could not create enhanced CGImage")
            return processedImage
        }
        
        print("   ✅ AI: Image preprocessed (contrast enhanced)")
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Enhanced Text Analysis
    
    /// Uses Natural Language Processing to better understand exclusivity from text
    func analyzeExclusivityFromText(_ text: String) -> [String] {
        var foundExclusivities: [String] = []
        let textLower = text.lowercased()
        
        // Use NLP to find entities and patterns
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        // Check for retailer/convention mentions with context
        for (pattern, exclusivity) in retailerPatterns {
            if textLower.contains(pattern) {
                // Use NLP to check if it's in a relevant context
                let range = textLower.range(of: pattern)
                if range != nil {
                    // Check surrounding context for exclusivity indicators
                    let contextWords = ["exclusive", "exclusively", "only at", "available at", "retailer"]
                    let patternRange = textLower.range(of: pattern)!
                    let startIndex = textLower.index(max(textLower.startIndex, patternRange.lowerBound), offsetBy: -50, limitedBy: textLower.startIndex) ?? textLower.startIndex
                    let endIndex = textLower.index(min(textLower.endIndex, patternRange.upperBound), offsetBy: 50, limitedBy: textLower.endIndex) ?? textLower.endIndex
                    let context = String(textLower[startIndex..<endIndex])
                    
                    if contextWords.contains(where: { context.contains($0) }) || 
                       context.contains("(\(pattern)") || 
                       context.contains("[\(pattern)") {
                        if !foundExclusivities.contains(exclusivity) {
                            foundExclusivities.append(exclusivity)
                        }
                    }
                }
            }
        }
        
        // Check for conventions
        for (pattern, exclusivity) in conventionPatterns {
            if textLower.contains(pattern) && !foundExclusivities.contains(exclusivity) {
                foundExclusivities.append(exclusivity)
            }
        }
        
        // Check for subscription boxes
        for (pattern, exclusivity) in subscriptionBoxPatterns {
            if textLower.contains(pattern) && !foundExclusivities.contains(exclusivity) {
                foundExclusivities.append(exclusivity)
            }
        }
        
        return foundExclusivities
    }
    
    // MARK: - Fuzzy Matching
    
    /// Uses fuzzy matching to find exclusivity even with typos or variations
    func fuzzyMatchExclusivity(_ text: String) -> [String] {
        var foundExclusivities: [String] = []
        let textLower = text.lowercased()
        
        // Calculate similarity scores for all patterns
        for (pattern, exclusivity) in retailerPatterns {
            let similarity = calculateSimilarity(textLower, pattern)
            // Threshold for fuzzy matching (0.7 = 70% similarity)
            if similarity > 0.7 && !foundExclusivities.contains(exclusivity) {
                foundExclusivities.append(exclusivity)
            }
        }
        
        for (pattern, exclusivity) in conventionPatterns {
            let similarity = calculateSimilarity(textLower, pattern)
            if similarity > 0.7 && !foundExclusivities.contains(exclusivity) {
                foundExclusivities.append(exclusivity)
            }
        }
        
        for (pattern, exclusivity) in subscriptionBoxPatterns {
            let similarity = calculateSimilarity(textLower, pattern)
            if similarity > 0.7 && !foundExclusivities.contains(exclusivity) {
                foundExclusivities.append(exclusivity)
            }
        }
        
        return foundExclusivities
    }
    
    // Simple Levenshtein distance-based similarity
    private func calculateSimilarity(_ s1: String, _ s2: String) -> Double {
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        guard maxLength > 0 else { return 0 }
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                if s1Array[i - 1] == s2Array[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]) + 1
                }
            }
        }
        
        return dp[m][n]
    }
    
    // MARK: - Learning from User Corrections
    
    /// Stores user corrections to improve future recognition
    func learnFromCorrection(popName: String, popNumber: String, correctedExclusivity: String) {
        // Store corrections in UserDefaults (could be upgraded to CoreData/SwiftData)
        let key = "exclusivity_\(popName.replacingOccurrences(of: " ", with: "_"))_\(popNumber)"
        UserDefaults.standard.set(correctedExclusivity, forKey: key)
        
        // Also store a pattern for fuzzy matching
        // Extract the retailer/convention name from the exclusivity string
        let exclusivityLower = correctedExclusivity.lowercased()
        for (pattern, _) in retailerPatterns {
            if exclusivityLower.contains(pattern) {
                // Store that this pattern was found for this Pop
                let patternKey = "pattern_\(pattern)_\(popNumber)"
                var existingPops = UserDefaults.standard.stringArray(forKey: patternKey) ?? []
                if !existingPops.contains(popName) {
                    existingPops.append(popName)
                    UserDefaults.standard.set(existingPops, forKey: patternKey)
                }
                break
            }
        }
        
        print("✅ AI: Learned exclusivity '\(correctedExclusivity)' for \(popName) #\(popNumber)")
    }
    
    /// Retrieves learned exclusivity for a Pop
    func getLearnedExclusivity(popName: String, popNumber: String) -> String? {
        let key = "exclusivity_\(popName.replacingOccurrences(of: " ", with: "_"))_\(popNumber)"
        return UserDefaults.standard.string(forKey: key)
    }
    
    // MARK: - Future AI Features (Placeholder)
    
    /*
     Future AI enhancements could include:
     
     1. **Image Recognition for Stickers**:
        - Use Vision framework to read text from Pop box images
        - Identify sticker logos and text automatically
        - Works even when CSV data is incomplete
     
     2. **Machine Learning Model**:
        - Train a Core ML model on thousands of Pop listings
        - Learn patterns in naming conventions
        - Improve accuracy over time
     
     3. **Natural Language Understanding**:
        - Better context understanding (e.g., "exclusive to" vs "sold at")
        - Handle abbreviations and variations
        - Understand regional differences
     
     4. **Crowdsourced Learning**:
        - Share corrections across users (anonymously)
        - Build a community knowledge base
        - Vote on accuracy of corrections
     
     5. **Predictive Matching**:
        - Suggest exclusivity based on similar Pops
        - Learn from series patterns
        - Identify new retailers/conventions automatically
     */
}

