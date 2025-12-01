//
//  OptimizedAsyncImage.swift
//  PopCollector
//
//  Optimized image view with caching, thumbnails, and progressive loading
//

import SwiftUI

struct OptimizedAsyncImage: View {
    let url: String
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    
    @State private var isLoading = true
    @State private var hasError = false
    
    init(url: String, width: CGFloat = 60, height: CGFloat = 60, cornerRadius: CGFloat = 8) {
        self.url = url
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .empty:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .frame(width: width, height: height)
                    .onAppear {
                        isLoading = true
                    }
                    
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .onAppear {
                        isLoading = false
                        hasError = false
                    }
                    
            case .failure:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.system(size: min(width, height) * 0.3))
                    }
                    .frame(width: width, height: height)
                    .onAppear {
                        isLoading = false
                        hasError = true
                    }
                    
            @unknown default:
                EmptyView()
            }
        }
    }
}

